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

create_project() {
    local project_id="${PROJECT_ID}"
    local project_name="${PROJECT_NAME}"
    local organization_id="${ORGANIZATION_ID:-}"
    local folder_id="${FOLDER_ID:-}"
    
    log_info "Checking if project '${project_id}' already exists..."
    
    if gcloud projects describe "${project_id}" &>/dev/null; then
        log_success "Project '${project_id}' already exists"
        return 0
    fi
    
    log_info "Creating new project '${project_id}'..."
    
    local create_cmd="gcloud projects create ${project_id} --name='${project_name}'"
    
    if [[ -n "${organization_id}" ]]; then
        create_cmd="${create_cmd} --organization=${organization_id}"
    elif [[ -n "${folder_id}" ]]; then
        create_cmd="${create_cmd} --folder=${folder_id}"
    fi
    
    if eval "${create_cmd}"; then
        log_success "Project '${project_id}' created successfully"
    else
        log_error "Failed to create project '${project_id}'"
        return 1
    fi
}

verify_project() {
    local project_id="${PROJECT_ID}"
    
    log_info "Verifying project '${project_id}' exists..."
    
    if gcloud projects describe "${project_id}" --format="value(projectId)" &>/dev/null; then
        local actual_id=$(gcloud projects describe "${project_id}" --format="value(projectId)")
        if [[ "${actual_id}" == "${project_id}" ]]; then
            log_success "Project '${project_id}' verified successfully"
            echo "PROJECT_ID=${project_id}"
            return 0
        fi
    fi
    
    log_error "Project '${project_id}' verification failed"
    return 1
}

set_current_project() {
    local project_id="${PROJECT_ID}"
    
    log_info "Setting '${project_id}' as the current project..."
    
    if gcloud config set project "${project_id}"; then
        log_success "Current project set to '${project_id}'"
    else
        log_error "Failed to set current project"
        return 1
    fi
}

grant_iam_permissions() {
    local project_id="${PROJECT_ID}"
    local user_email=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
    
    if [[ -z "${user_email}" ]]; then
        log_warning "Could not determine authenticated user email"
        return 0
    fi
    
    log_info "Granting IAM permissions to '${user_email}'..."
    
    # Grant owner role to the authenticated user
    if gcloud projects add-iam-policy-binding "${project_id}" \
        --member="user:${user_email}" \
        --role="roles/owner" \
        --condition=None &>/dev/null; then
        log_success "Granted Owner role to ${user_email}"
    else
        log_warning "Could not grant Owner role (may already exist)"
    fi
    
    # Also grant viewer role to ensure basic access
    if gcloud projects add-iam-policy-binding "${project_id}" \
        --member="user:${user_email}" \
        --role="roles/viewer" \
        --condition=None &>/dev/null; then
        log_success "Granted Viewer role to ${user_email}"
    else
        log_warning "Could not grant Viewer role (may already exist)"
    fi
    
    log_info "Waiting for IAM permissions to propagate..."
    sleep 3
    
    return 0
}

main() {
    log_info "Starting GCP project creation process..."
    
    if [[ -z "${PROJECT_ID}" ]] || [[ -z "${PROJECT_NAME}" ]]; then
        log_error "PROJECT_ID and PROJECT_NAME must be set in config/env.sh"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "No active gcloud authentication found. Please run 'gcloud auth login'"
        exit 1
    fi
    
    create_project || exit 1
    
    verify_project || exit 1
    
    set_current_project || exit 1
    
    grant_iam_permissions || exit 1
    
    log_success "Project setup completed successfully!"
    log_info "Project ID: ${PROJECT_ID}"
}

main "$@"