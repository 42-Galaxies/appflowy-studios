#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/../config/env.sh"

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

check_vm_ready() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Checking if VM '${vm_name}' is ready..."
    
    # Check VM is running
    local vm_status=$(gcloud compute instances describe "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "${vm_status}" != "RUNNING" ]]; then
        log_error "VM '${vm_name}' is not running (status: ${vm_status})"
        return 1
    fi
    
    # Test SSH connectivity
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="echo 'SSH connection successful'" &>/dev/null; then
        log_success "VM '${vm_name}' is ready for SSH"
        return 0
    else
        log_error "Cannot establish SSH connection to VM '${vm_name}'"
        log_info "You may need to wait a bit more or check firewall rules"
        return 1
    fi
}

check_docker_installed() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Checking if Docker is already installed..."
    
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="docker --version" &>/dev/null; then
        local docker_version=$(gcloud compute ssh "${vm_name}" \
            --zone="${zone}" \
            --project="${PROJECT_ID}" \
            --command="docker --version" 2>/dev/null)
        log_success "Docker is already installed: ${docker_version}"
        return 0
    else
        return 1
    fi
}

wait_for_startup_script() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    local max_attempts=60
    local attempt=0
    
    log_info "Waiting for VM startup script to complete..."
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if gcloud compute ssh "${vm_name}" \
            --zone="${zone}" \
            --project="${PROJECT_ID}" \
            --command="test -f /var/log/startup-complete.log" &>/dev/null; then
            log_success "Startup script completed"
            
            # Show startup log
            local startup_log=$(gcloud compute ssh "${vm_name}" \
                --zone="${zone}" \
                --project="${PROJECT_ID}" \
                --command="cat /var/log/startup-complete.log" 2>/dev/null || echo "")
            
            if [[ -n "${startup_log}" ]]; then
                log_info "Startup completed: ${startup_log}"
            fi
            
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo ""
    log_warning "Startup script may still be running or failed"
    return 1
}

install_docker_manually() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Installing Docker manually on VM..."
    
    # Create installation script
    local install_script='
#!/bin/bash
set -e

# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version
'
    
    # Execute installation script
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="${install_script}"; then
        log_success "Docker installed successfully"
        return 0
    else
        log_error "Failed to install Docker"
        return 1
    fi
}

configure_docker() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Configuring Docker settings..."
    
    # Create Docker daemon configuration
    local docker_config='
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
'
    
    # Apply Docker configuration
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="echo '${docker_config}' | sudo tee /etc/docker/daemon.json > /dev/null && sudo systemctl restart docker"; then
        log_success "Docker configured successfully"
    else
        log_warning "Failed to configure Docker daemon (non-critical)"
    fi
    
    # Create AppFlowy directory structure
    log_info "Creating AppFlowy directory structure..."
    
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="sudo mkdir -p /opt/appflowy/{data,config,backups} && sudo chown -R \$USER:\$USER /opt/appflowy"; then
        log_success "AppFlowy directories created"
    else
        log_warning "Failed to create AppFlowy directories"
    fi
}

verify_docker_installation() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Verifying Docker installation..."
    
    # Check Docker version
    local docker_version=$(gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="docker --version" 2>/dev/null || echo "Not installed")
    
    # Check Docker Compose version
    local compose_version=$(gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="docker compose version" 2>/dev/null || echo "Not installed")
    
    # Check Docker service status
    local docker_status=$(gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="sudo systemctl is-active docker" 2>/dev/null || echo "inactive")
    
    echo ""
    echo "Docker Installation Status:"
    echo "  Docker: ${docker_version}"
    echo "  Compose: ${compose_version}"
    echo "  Service: ${docker_status}"
    
    if [[ "${docker_status}" == "active" ]]; then
        log_success "Docker is installed and running"
        
        # Test Docker functionality
        log_info "Testing Docker functionality..."
        if gcloud compute ssh "${vm_name}" \
            --zone="${zone}" \
            --project="${PROJECT_ID}" \
            --command="docker run --rm hello-world" &>/dev/null; then
            log_success "Docker test successful"
            return 0
        else
            log_warning "Docker test failed (may need to re-login for group permissions)"
            echo "Note: You may need to logout and login again for docker group permissions to take effect"
            return 0
        fi
    else
        log_error "Docker is not running properly"
        return 1
    fi
}

main() {
    log_info "Starting Docker installation process..."
    
    # Validate required environment variables
    if [[ -z "${VM_NAME}" ]] || [[ -z "${VM_ZONE}" ]]; then
        log_error "VM_NAME and VM_ZONE must be set in config/env.sh"
        exit 1
    fi
    
    # Check VM is ready
    check_vm_ready || exit 1
    
    # Check if Docker is already installed
    if check_docker_installed; then
        log_info "Docker is already installed, skipping installation"
    else
        # Wait for startup script if it might be installing Docker
        wait_for_startup_script
        
        # Check again after startup script
        if check_docker_installed; then
            log_success "Docker was installed by startup script"
        else
            # Install Docker manually
            log_info "Docker not found, installing manually..."
            install_docker_manually || exit 1
        fi
    fi
    
    # Configure Docker
    configure_docker
    
    # Verify installation
    verify_docker_installation || exit 1
    
    log_success "Docker installation and configuration completed!"
    
    echo ""
    log_info "Docker is ready for AppFlowy deployment"
    log_info "Next step: Run 08-deploy-appflowy.sh to deploy the application"
}

main "$@"