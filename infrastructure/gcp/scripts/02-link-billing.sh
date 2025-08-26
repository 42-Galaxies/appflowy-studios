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

list_billing_accounts() {
    log_info "Available billing accounts:"
    gcloud billing accounts list --format="table(name,displayName,open)" || {
        log_error "Failed to list billing accounts"
        return 1
    }
}

validate_billing_account() {
    local billing_account="${1}"
    
    log_info "Validating billing account '${billing_account}'..."
    
    if gcloud billing accounts describe "${billing_account}" &>/dev/null; then
        local is_open=$(gcloud billing accounts describe "${billing_account}" --format="value(open)")
        if [[ "${is_open}" == "True" ]]; then
            log_success "Billing account '${billing_account}' is valid and open"
            return 0
        else
            log_error "Billing account '${billing_account}' is not open"
            return 1
        fi
    else
        log_error "Billing account '${billing_account}' not found"
        return 1
    fi
}

link_billing_account() {
    local project_id="${PROJECT_ID}"
    local billing_account="${BILLING_ACCOUNT_ID}"
    
    log_info "Checking current billing account for project '${project_id}'..."
    
    local current_billing=$(gcloud billing projects describe "${project_id}" --format="value(billingAccountName)" 2>/dev/null || echo "")
    
    if [[ -n "${current_billing}" ]]; then
        if [[ "${current_billing}" == "billingAccounts/${billing_account}" ]]; then
            log_success "Project '${project_id}' is already linked to billing account '${billing_account}'"
            return 0
        else
            log_info "Project is currently linked to: ${current_billing}"
            log_info "Updating to new billing account..."
        fi
    else
        log_info "Project '${project_id}' has no billing account linked"
    fi
    
    log_info "Linking billing account '${billing_account}' to project '${project_id}'..."
    
    if gcloud billing projects link "${project_id}" --billing-account="${billing_account}"; then
        log_success "Successfully linked billing account '${billing_account}' to project '${project_id}'"
    else
        log_error "Failed to link billing account"
        return 1
    fi
}

verify_billing_link() {
    local project_id="${PROJECT_ID}"
    local expected_billing="${BILLING_ACCOUNT_ID}"
    
    log_info "Verifying billing account link..."
    
    local actual_billing=$(gcloud billing projects describe "${project_id}" --format="value(billingAccountName)" 2>/dev/null || echo "")
    
    if [[ "${actual_billing}" == "billingAccounts/${expected_billing}" ]]; then
        log_success "Billing account verified: ${expected_billing}"
        
        local billing_enabled=$(gcloud billing projects describe "${project_id}" --format="value(billingEnabled)" 2>/dev/null || echo "False")
        if [[ "${billing_enabled}" == "True" ]]; then
            log_success "Billing is enabled for project '${project_id}'"
            return 0
        else
            log_error "Billing is not enabled for project '${project_id}'"
            return 1
        fi
    else
        log_error "Billing account mismatch. Expected: ${expected_billing}, Actual: ${actual_billing}"
        return 1
    fi
}

main() {
    log_info "Starting billing account linking process..."
    
    if [[ -z "${PROJECT_ID}" ]]; then
        log_error "PROJECT_ID must be set in config/env.sh"
        exit 1
    fi
    
    if [[ -z "${BILLING_ACCOUNT_ID}" ]]; then
        log_error "BILLING_ACCOUNT_ID must be set in config/env.sh"
        echo ""
        log_info "To find your billing account ID, you can:"
        echo "  1. Run: gcloud billing accounts list"
        echo "  2. Visit: https://console.cloud.google.com/billing"
        echo "  3. Set BILLING_ACCOUNT_ID in config/env.sh"
        echo ""
        list_billing_accounts
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    validate_billing_account "${BILLING_ACCOUNT_ID}" || exit 1
    
    link_billing_account || exit 1
    
    verify_billing_link || exit 1
    
    log_success "Billing account linking completed successfully!"
    log_info "Project: ${PROJECT_ID}"
    log_info "Billing Account: ${BILLING_ACCOUNT_ID}"
}

main "$@"