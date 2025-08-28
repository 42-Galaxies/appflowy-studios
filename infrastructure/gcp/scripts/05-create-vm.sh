#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

check_vm_exists() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Checking if VM '${vm_name}' exists in zone '${zone}'..."
    
    if gcloud compute instances describe "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

reserve_static_ip() {
    local ip_name="${VM_NAME}-ip"
    local region="${VM_REGION:-us-central1}"
    
    log_info "Checking for static IP address '${ip_name}'..."
    
    if gcloud compute addresses describe "${ip_name}" \
        --region="${region}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_success "Static IP '${ip_name}' already exists"
    else
        log_info "Reserving static IP address '${ip_name}'..."
        if gcloud compute addresses create "${ip_name}" \
            --region="${region}" \
            --project="${PROJECT_ID}"; then
            log_success "Static IP '${ip_name}' reserved successfully"
        else
            log_error "Failed to reserve static IP"
            return 1
        fi
    fi
    
    # Get the reserved IP address
    STATIC_IP=$(gcloud compute addresses describe "${ip_name}" \
        --region="${region}" \
        --project="${PROJECT_ID}" \
        --format="value(address)")
    
    log_info "Static IP address: ${STATIC_IP}"
    return 0
}

create_startup_script() {
    local script_path="${SCRIPT_DIR}/../docker/startup-script.sh"
    
    if [[ ! -f "${script_path}" ]]; then
        mkdir -p "$(dirname "${script_path}")"
        
        cat > "${script_path}" << 'EOF'
#!/bin/bash

# Wait for network to be ready
sleep 10

# Update system packages
apt-get update

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

# Create docker group and add default user
usermod -aG docker ${USER:-$USER}

# Create AppFlowy directory
mkdir -p /opt/appflowy
chown -R ${USER:-$USER}:${USER:-$USER} /opt/appflowy

# Log completion
echo "Startup script completed at $(date)" >> /var/log/startup-complete.log
EOF
        chmod +x "${script_path}"
    fi
    
    # Return only the path, no logging here
    echo "${script_path}"
}

create_vm() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    local machine_type="${VM_MACHINE_TYPE}"
    local ip_name="${VM_NAME}-ip"
    local region="${VM_REGION:-us-central1}"
    
    log_info "Creating VM '${vm_name}' with machine type '${machine_type}'..."
    
    # Get startup script path (capture only the path, not log output)
    local startup_script=$(create_startup_script)
    log_info "Using startup script: ${startup_script}"
    
    # Create the VM with reserved static IP
    if gcloud compute instances create "${vm_name}" \
        --zone="${zone}" \
        --machine-type="${machine_type}" \
        --network-interface="address=${STATIC_IP},network-tier=PREMIUM" \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --create-disk="auto-delete=yes,boot=yes,device-name=${vm_name},image-project=ubuntu-os-cloud,image-family=ubuntu-2204-lts,mode=rw,size=20,type=pd-standard" \
        --metadata-from-file="startup-script=${startup_script}" \
        --tags="http-server,https-server" \
        --project="${PROJECT_ID}"; then
        log_success "VM '${vm_name}' created successfully"
    else
        log_error "Failed to create VM '${vm_name}'"
        return 1
    fi
}

wait_for_vm() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for VM '${vm_name}' to be ready..."
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if gcloud compute instances describe "${vm_name}" \
            --zone="${zone}" \
            --project="${PROJECT_ID}" \
            --format="value(status)" | grep -q "RUNNING"; then
            log_success "VM '${vm_name}' is running"
            
            # Wait a bit more for SSH to be ready
            log_info "Waiting for SSH to be ready..."
            sleep 20
            
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 10
    done
    
    echo ""
    log_error "Timeout waiting for VM to be ready"
    return 1
}

verify_vm() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Verifying VM '${vm_name}'..."
    
    # Check VM exists and is running
    local vm_status=$(gcloud compute instances describe "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "${vm_status}" == "RUNNING" ]]; then
        log_success "VM '${vm_name}' is running"
        
        # Get external IP
        local external_ip=$(gcloud compute instances describe "${vm_name}" \
            --zone="${zone}" \
            --project="${PROJECT_ID}" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
        
        log_info "External IP: ${external_ip}"
        echo "VM_EXTERNAL_IP=${external_ip}"
        
        return 0
    else
        log_error "VM '${vm_name}' status: ${vm_status}"
        return 1
    fi
}

main() {
    log_info "Starting VM creation process..."
    
    # Validate required environment variables
    if [[ -z "${VM_NAME}" ]] || [[ -z "${VM_ZONE}" ]] || [[ -z "${VM_MACHINE_TYPE}" ]]; then
        log_error "VM_NAME, VM_ZONE, and VM_MACHINE_TYPE must be set in config/env.sh"
        exit 1
    fi
    
    # Check if VM already exists
    if check_vm_exists; then
        log_warning "VM '${VM_NAME}' already exists"
        
        # Verify it's running
        if verify_vm; then
            log_success "Using existing VM '${VM_NAME}'"
            exit 0
        else
            log_error "Existing VM is not in a valid state"
            log_info "You may need to delete it first with:"
            echo "  gcloud compute instances delete ${VM_NAME} --zone=${VM_ZONE}"
            exit 1
        fi
    fi
    
    # Reserve static IP
    reserve_static_ip || exit 1
    
    # Create the VM
    create_vm || exit 1
    
    # Wait for VM to be ready
    wait_for_vm || exit 1
    
    # Verify VM
    verify_vm || exit 1
    
    log_success "VM creation completed successfully!"
    log_info "VM Name: ${VM_NAME}"
    log_info "Zone: ${VM_ZONE}"
    log_info "External IP: ${STATIC_IP}"
    
    log_info "You can SSH into the VM with:"
    echo "  gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
}

main "$@"