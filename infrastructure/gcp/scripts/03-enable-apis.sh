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

REQUIRED_APIS=(
    "compute.googleapis.com"
    "cloudbuild.googleapis.com"
    "secretmanager.googleapis.com"
    "artifactregistry.googleapis.com"
)

OPTIONAL_APIS=(
    "cloudresourcemanager.googleapis.com"
    "serviceusage.googleapis.com"
    "iam.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
    "storage-api.googleapis.com"
    "storage.googleapis.com"
)

enable_api() {
    local api="${1}"
    local project_id="${PROJECT_ID}"
    
    log_info "Checking if API '${api}' is already enabled..."
    
    if gcloud services list --project="${project_id}" --filter="name:${api}" --format="value(name)" 2>/dev/null | grep -q "${api}"; then
        log_success "API '${api}' is already enabled"
        return 0
    fi
    
    log_info "Enabling API '${api}'..."
    
    if gcloud services enable "${api}" --project="${project_id}"; then
        log_success "API '${api}' enabled successfully"
        
        sleep 2
        
        return 0
    else
        log_error "Failed to enable API '${api}'"
        return 1
    fi
}

verify_api() {
    local api="${1}"
    local project_id="${PROJECT_ID}"
    
    if gcloud services list --project="${project_id}" --filter="name:${api}" --enabled --format="value(name)" 2>/dev/null | grep -q "${api}"; then
        return 0
    else
        return 1
    fi
}

enable_apis_batch() {
    local apis=("$@")
    local project_id="${PROJECT_ID}"
    local apis_to_enable=()
    
    for api in "${apis[@]}"; do
        if ! verify_api "${api}"; then
            apis_to_enable+=("${api}")
        else
            log_success "API '${api}' is already enabled"
        fi
    done
    
    if [[ ${#apis_to_enable[@]} -eq 0 ]]; then
        log_success "All specified APIs are already enabled"
        return 0
    fi
    
    log_info "Enabling ${#apis_to_enable[@]} APIs in batch..."
    log_info "APIs to enable: ${apis_to_enable[*]}"
    
    if gcloud services enable "${apis_to_enable[@]}" --project="${project_id}"; then
        log_success "Batch API enablement completed"
        
        log_info "Waiting for APIs to propagate..."
        sleep 5
        
        return 0
    else
        log_error "Batch API enablement failed, trying individually..."
        
        for api in "${apis_to_enable[@]}"; do
            enable_api "${api}"
        done
    fi
}

verify_all_apis() {
    local all_good=true
    
    log_info "Verifying all required APIs are enabled..."
    
    for api in "${REQUIRED_APIS[@]}"; do
        if verify_api "${api}"; then
            log_success "✓ ${api}"
        else
            log_error "✗ ${api}"
            all_good=false
        fi
    done
    
    if [[ "${ENABLE_OPTIONAL_APIS:-false}" == "true" ]]; then
        log_info "Verifying optional APIs..."
        for api in "${OPTIONAL_APIS[@]}"; do
            if verify_api "${api}"; then
                log_success "✓ ${api} (optional)"
            else
                log_info "○ ${api} (optional, not enabled)"
            fi
        done
    fi
    
    if [[ "${all_good}" == "true" ]]; then
        log_success "All required APIs verified successfully"
        return 0
    else
        log_error "Some required APIs are not enabled"
        return 1
    fi
}

list_enabled_apis() {
    local project_id="${PROJECT_ID}"
    
    log_info "Currently enabled APIs for project '${project_id}':"
    gcloud services list --project="${project_id}" --enabled --format="table(config.name,config.title)" || {
        log_error "Failed to list enabled APIs"
        return 1
    }
}

main() {
    log_info "Starting API enablement process..."
    
    if [[ -z "${PROJECT_ID}" ]]; then
        log_error "PROJECT_ID must be set in config/env.sh"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    gcloud config set project "${PROJECT_ID}" &>/dev/null
    
    log_info "Enabling required APIs for project '${PROJECT_ID}'..."
    enable_apis_batch "${REQUIRED_APIS[@]}" || {
        log_error "Failed to enable required APIs"
        exit 1
    }
    
    if [[ "${ENABLE_OPTIONAL_APIS:-false}" == "true" ]]; then
        log_info "Enabling optional APIs..."
        enable_apis_batch "${OPTIONAL_APIS[@]}" || {
            log_error "Failed to enable optional APIs (continuing anyway)"
        }
    fi
    
    verify_all_apis || exit 1
    
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo ""
        list_enabled_apis
    fi
    
    log_success "API enablement completed successfully!"
    log_info "Project: ${PROJECT_ID}"
    log_info "Required APIs enabled: ${#REQUIRED_APIS[@]}"
}

main "$@"