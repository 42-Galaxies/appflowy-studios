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

check_firewall_rule() {
    local rule_name="$1"
    
    if gcloud compute firewall-rules describe "${rule_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

create_http_firewall_rule() {
    local rule_name="allow-http-${VM_NAME}"
    
    log_info "Checking HTTP firewall rule '${rule_name}'..."
    
    if check_firewall_rule "${rule_name}"; then
        log_success "HTTP firewall rule '${rule_name}' already exists"
        return 0
    fi
    
    log_info "Creating HTTP firewall rule '${rule_name}'..."
    
    if gcloud compute firewall-rules create "${rule_name}" \
        --allow="tcp:80" \
        --source-ranges="0.0.0.0/0" \
        --target-tags="http-server" \
        --description="Allow HTTP traffic to ${VM_NAME}" \
        --project="${PROJECT_ID}"; then
        log_success "HTTP firewall rule '${rule_name}' created successfully"
    else
        log_error "Failed to create HTTP firewall rule"
        return 1
    fi
}

create_https_firewall_rule() {
    local rule_name="allow-https-${VM_NAME}"
    
    log_info "Checking HTTPS firewall rule '${rule_name}'..."
    
    if check_firewall_rule "${rule_name}"; then
        log_success "HTTPS firewall rule '${rule_name}' already exists"
        return 0
    fi
    
    log_info "Creating HTTPS firewall rule '${rule_name}'..."
    
    if gcloud compute firewall-rules create "${rule_name}" \
        --allow="tcp:443" \
        --source-ranges="0.0.0.0/0" \
        --target-tags="https-server" \
        --description="Allow HTTPS traffic to ${VM_NAME}" \
        --project="${PROJECT_ID}"; then
        log_success "HTTPS firewall rule '${rule_name}' created successfully"
    else
        log_error "Failed to create HTTPS firewall rule"
        return 1
    fi
}

create_ssh_firewall_rule() {
    local rule_name="allow-ssh-${VM_NAME}"
    local ssh_source_ranges="${SSH_SOURCE_RANGES:-0.0.0.0/0}"
    
    log_info "Checking SSH firewall rule '${rule_name}'..."
    
    if check_firewall_rule "${rule_name}"; then
        log_success "SSH firewall rule '${rule_name}' already exists"
        
        # Update the rule if source ranges have changed
        local current_ranges=$(gcloud compute firewall-rules describe "${rule_name}" \
            --project="${PROJECT_ID}" \
            --format="value(sourceRanges.list())" | tr '\n' ',')
        
        if [[ "${current_ranges%,}" != "${ssh_source_ranges}" ]]; then
            log_info "Updating SSH source ranges..."
            if gcloud compute firewall-rules update "${rule_name}" \
                --source-ranges="${ssh_source_ranges}" \
                --project="${PROJECT_ID}"; then
                log_success "SSH firewall rule updated with new source ranges"
            else
                log_warning "Failed to update SSH source ranges"
            fi
        fi
        
        return 0
    fi
    
    log_info "Creating SSH firewall rule '${rule_name}'..."
    
    if [[ "${ssh_source_ranges}" == "0.0.0.0/0" ]]; then
        log_warning "SSH access will be allowed from all IPs (0.0.0.0/0)"
        log_warning "Consider restricting SSH_SOURCE_RANGES in config/env.sh for better security"
    else
        log_info "SSH access restricted to: ${ssh_source_ranges}"
    fi
    
    if gcloud compute firewall-rules create "${rule_name}" \
        --allow="tcp:22" \
        --source-ranges="${ssh_source_ranges}" \
        --target-tags="http-server,https-server" \
        --description="Allow SSH traffic to ${VM_NAME}" \
        --project="${PROJECT_ID}"; then
        log_success "SSH firewall rule '${rule_name}' created successfully"
    else
        log_error "Failed to create SSH firewall rule"
        return 1
    fi
}

create_appflowy_firewall_rule() {
    local rule_name="allow-appflowy-${VM_NAME}"
    local appflowy_port="${APPFLOWY_PORT:-8000}"
    
    log_info "Checking AppFlowy firewall rule '${rule_name}'..."
    
    if check_firewall_rule "${rule_name}"; then
        log_success "AppFlowy firewall rule '${rule_name}' already exists"
        return 0
    fi
    
    log_info "Creating AppFlowy firewall rule '${rule_name}' for port ${appflowy_port}..."
    
    if gcloud compute firewall-rules create "${rule_name}" \
        --allow="tcp:${appflowy_port}" \
        --source-ranges="0.0.0.0/0" \
        --target-tags="http-server,https-server" \
        --description="Allow AppFlowy traffic on port ${appflowy_port}" \
        --project="${PROJECT_ID}"; then
        log_success "AppFlowy firewall rule '${rule_name}' created successfully"
    else
        log_error "Failed to create AppFlowy firewall rule"
        return 1
    fi
}

verify_firewall_rules() {
    log_info "Verifying firewall rules..."
    
    local rules=(
        "allow-http-${VM_NAME}"
        "allow-https-${VM_NAME}"
        "allow-ssh-${VM_NAME}"
        "allow-appflowy-${VM_NAME}"
    )
    
    local all_rules_exist=true
    
    for rule in "${rules[@]}"; do
        if check_firewall_rule "${rule}"; then
            echo "  ✓ ${rule}"
        else
            echo "  ✗ ${rule}"
            all_rules_exist=false
        fi
    done
    
    if ${all_rules_exist}; then
        log_success "All firewall rules verified"
        return 0
    else
        log_error "Some firewall rules are missing"
        return 1
    fi
}

list_firewall_rules() {
    log_info "Current firewall rules for ${VM_NAME}:"
    
    gcloud compute firewall-rules list \
        --filter="name~${VM_NAME}" \
        --format="table(name,direction,sourceRanges.list():label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW,targetTags.list():label=TARGET_TAGS)" \
        --project="${PROJECT_ID}"
}

main() {
    log_info "Starting firewall configuration..."
    
    # Validate required environment variables
    if [[ -z "${VM_NAME}" ]]; then
        log_error "VM_NAME must be set in config/env.sh"
        exit 1
    fi
    
    # Create HTTP rule
    create_http_firewall_rule || exit 1
    
    # Create HTTPS rule
    create_https_firewall_rule || exit 1
    
    # Create SSH rule
    create_ssh_firewall_rule || exit 1
    
    # Create AppFlowy rule
    create_appflowy_firewall_rule || exit 1
    
    # Verify all rules
    echo ""
    verify_firewall_rules || exit 1
    
    # List all rules
    echo ""
    list_firewall_rules
    
    log_success "Firewall configuration completed successfully!"
    
    if [[ "${SSH_SOURCE_RANGES:-0.0.0.0/0}" == "0.0.0.0/0" ]]; then
        echo ""
        log_warning "SECURITY NOTICE: SSH is currently open to all IPs"
        log_warning "To restrict SSH access, set SSH_SOURCE_RANGES in config/env.sh"
        log_warning "Example: SSH_SOURCE_RANGES=\"YOUR_IP/32,OFFICE_IP/24\""
    fi
}

main "$@"