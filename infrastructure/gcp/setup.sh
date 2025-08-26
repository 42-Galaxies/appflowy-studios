#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

print_banner() {
    echo ""
    echo "============================================"
    echo "   42 Galaxies Workspace GCP Setup Script"
    echo "============================================"
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        echo "Please install Google Cloud SDK:"
        echo "  https://cloud.google.com/sdk/docs/install"
        return 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "No active gcloud authentication found"
        echo "Please authenticate with: gcloud auth login"
        return 1
    fi
    
    if [[ ! -f "${CONFIG_DIR}/env.sh" ]]; then
        log_error "Configuration file not found: ${CONFIG_DIR}/env.sh"
        echo "Please copy env.sh.template to env.sh and configure it"
        return 1
    fi
    
    source "${CONFIG_DIR}/env.sh"
    
    if [[ -z "${PROJECT_ID}" ]] || [[ -z "${PROJECT_NAME}" ]]; then
        log_error "PROJECT_ID and PROJECT_NAME must be set in config/env.sh"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

run_script() {
    local script_name="${1}"
    local script_path="${SCRIPTS_DIR}/${script_name}"
    
    if [[ ! -f "${script_path}" ]]; then
        log_error "Script not found: ${script_path}"
        return 1
    fi
    
    if [[ ! -x "${script_path}" ]]; then
        chmod +x "${script_path}"
    fi
    
    log_info "Running: ${script_name}"
    echo "----------------------------------------"
    
    if "${script_path}"; then
        echo "----------------------------------------"
        log_success "Completed: ${script_name}"
        return 0
    else
        echo "----------------------------------------"
        log_error "Failed: ${script_name}"
        return 1
    fi
}

interactive_mode() {
    source "${CONFIG_DIR}/env.sh"
    
    echo ""
    echo "Select operations to perform:"
    echo "  1) Full setup (all steps)"
    echo "  2) Create GCP project only"
    echo "  3) Link billing account only"
    echo "  4) Enable APIs only"
    echo "  5) Setup billing alerts only"
    echo "  6) Verify configuration"
    echo "  0) Exit"
    echo ""
    
    read -p "Enter your choice [0-6]: " choice
    
    case ${choice} in
        1)
            run_full_setup
            ;;
        2)
            run_script "01-create-project.sh"
            ;;
        3)
            run_script "02-link-billing.sh"
            ;;
        4)
            run_script "03-enable-apis.sh"
            ;;
        5)
            run_script "04-setup-billing-alerts.sh"
            ;;
        6)
            verify_setup
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

run_full_setup() {
    log_info "Starting full GCP setup..."
    echo ""
    
    local scripts=(
        "01-create-project.sh"
        "02-link-billing.sh"
        "03-enable-apis.sh"
        "04-setup-billing-alerts.sh"
    )
    
    for script in "${scripts[@]}"; do
        if ! run_script "${script}"; then
            log_error "Setup failed at: ${script}"
            echo ""
            echo "You can fix the issue and run this script again."
            echo "The setup will continue from where it left off."
            exit 1
        fi
        echo ""
    done
    
    log_success "Full setup completed successfully!"
}

verify_setup() {
    source "${CONFIG_DIR}/env.sh"
    
    log_info "Verifying GCP setup..."
    echo ""
    
    echo "Project Configuration:"
    echo "  Project ID: ${PROJECT_ID}"
    echo "  Project Name: ${PROJECT_NAME}"
    
    if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        echo "  Status: ✓ Project exists"
    else
        echo "  Status: ✗ Project not found"
    fi
    
    echo ""
    echo "Billing Configuration:"
    local billing_info=$(gcloud billing projects describe "${PROJECT_ID}" --format="value(billingAccountName,billingEnabled)" 2>/dev/null || echo "")
    if [[ -n "${billing_info}" ]]; then
        echo "  Billing Account: ${billing_info}"
        echo "  Status: ✓ Billing configured"
    else
        echo "  Status: ✗ No billing account linked"
    fi
    
    echo ""
    echo "API Status:"
    local required_apis=(
        "compute.googleapis.com"
        "cloudbuild.googleapis.com"
        "secretmanager.googleapis.com"
        "artifactregistry.googleapis.com"
    )
    
    for api in "${required_apis[@]}"; do
        if gcloud services list --project="${PROJECT_ID}" --filter="name:${api}" --enabled --format="value(name)" 2>/dev/null | grep -q "${api}"; then
            echo "  ✓ ${api}"
        else
            echo "  ✗ ${api}"
        fi
    done
    
    echo ""
    echo "Budget Alerts:"
    local budget_count=$(gcloud billing budgets list --billing-account="${BILLING_ACCOUNT_ID}" --format="value(name)" 2>/dev/null | wc -l)
    if [[ ${budget_count} -gt 0 ]]; then
        echo "  Status: ✓ ${budget_count} budget(s) configured"
    else
        echo "  Status: ○ No budgets configured"
    fi
    
    echo ""
    log_success "Verification complete"
}

cleanup() {
    log_info "Performing cleanup..."
    rm -f /tmp/channel.json /tmp/budget.json /tmp/policy.json 2>/dev/null || true
}

trap cleanup EXIT

main() {
    print_banner
    
    check_prerequisites || exit 1
    
    if [[ $# -eq 0 ]]; then
        interactive_mode
    else
        case "${1}" in
            --full|-f)
                run_full_setup
                ;;
            --verify|-v)
                verify_setup
                ;;
            --help|-h)
                echo "Usage: ${0} [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --full, -f     Run full setup (all steps)"
                echo "  --verify, -v   Verify the current setup"
                echo "  --help, -h     Show this help message"
                echo ""
                echo "If no options provided, runs in interactive mode"
                exit 0
                ;;
            *)
                log_error "Unknown option: ${1}"
                echo "Run '${0} --help' for usage information"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    verify_setup
    echo ""
    log_success "Setup script completed!"
}

main "$@"