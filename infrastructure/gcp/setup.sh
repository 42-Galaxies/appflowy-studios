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
        log_warning "Configuration file not found: ${CONFIG_DIR}/env.sh"
        echo ""
        echo "Would you like to:"
        echo "  1) Run auto-configuration (recommended)"
        echo "  2) Copy template and configure manually"
        echo ""
        read -p "Choose option [1-2]: " config_choice
        
        case ${config_choice} in
            1)
                log_info "Running auto-configuration..."
                if "${SCRIPTS_DIR}/00-auto-configure.sh"; then
                    log_success "Auto-configuration completed"
                    source "${CONFIG_DIR}/env.sh"
                else
                    log_error "Auto-configuration failed"
                    return 1
                fi
                ;;
            2)
                log_info "Creating env.sh from template..."
                cp "${CONFIG_DIR}/env.sh.template" "${CONFIG_DIR}/env.sh"
                echo "Please edit ${CONFIG_DIR}/env.sh with your configuration"
                return 1
                ;;
            *)
                log_error "Invalid choice"
                return 1
                ;;
        esac
    else
        source "${CONFIG_DIR}/env.sh"
    fi
    
    if [[ -z "${PROJECT_ID}" ]] || [[ -z "${PROJECT_NAME}" ]]; then
        log_warning "PROJECT_ID and PROJECT_NAME not configured"
        log_info "Running auto-configuration to detect settings..."
        
        if "${SCRIPTS_DIR}/00-auto-configure.sh"; then
            source "${CONFIG_DIR}/env.sh"
        else
            log_error "Failed to configure project settings"
            return 1
        fi
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
    echo ""
    echo "=== Quick Start ==="
    echo "  1) Auto-configure (detect settings from gcloud)"
    echo ""
    echo "=== Initial Setup ==="
    echo "  2) Full GCP setup (project, billing, APIs)"
    echo "  3) Create GCP project only"
    echo "  4) Link billing account only"
    echo "  5) Enable APIs only"
    echo "  6) Setup billing alerts only"
    echo ""
    echo "=== VM & AppFlowy Deployment ==="
    echo "  7) Create VM instance"
    echo "  8) Configure firewall rules"
    echo "  9) Install Docker on VM"
    echo " 10) Deploy AppFlowy stack"
    echo " 11) Full VM deployment (steps 7-10)"
    echo ""
    echo "=== Management ==="
    echo " 12) Verify all configuration"
    echo " 13) Stop AppFlowy services"
    echo " 14) Start AppFlowy services"
    echo " 15) View AppFlowy logs"
    echo " 16) Test deployment (comprehensive)"
    echo " 17) Fork management (customize AppFlowy)"
    echo ""
    echo "  0) Exit"
    echo ""
    
    read -p "Enter your choice [0-17]: " choice
    
    case ${choice} in
        1)
            run_script "00-auto-configure.sh"
            ;;
        2)
            run_full_setup
            ;;
        3)
            run_script "01-create-project.sh"
            ;;
        4)
            run_script "02-link-billing.sh"
            ;;
        5)
            run_script "03-enable-apis.sh"
            ;;
        6)
            run_script "04-setup-billing-alerts.sh"
            ;;
        7)
            run_script "05-create-vm.sh"
            ;;
        8)
            run_script "06-configure-firewall.sh"
            ;;
        9)
            run_script "07-install-docker.sh"
            ;;
        10)
            run_script "08-deploy-appflowy-simplified.sh"
            ;;
        11)
            run_vm_deployment
            ;;
        12)
            verify_setup
            ;;
        13)
            stop_appflowy
            ;;
        14)
            start_appflowy
            ;;
        15)
            view_appflowy_logs
            ;;
        16)
            run_script "10-test-deployment.sh"
            ;;
        17)
            run_script "09-fork-appflowy.sh"
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

run_vm_deployment() {
    log_info "Starting full VM and AppFlowy deployment..."
    echo ""
    
    # Check if configuration exists
    if [[ ! -f "${CONFIG_DIR}/env.sh" ]]; then
        log_warning "Configuration not found. Running auto-configure first..."
        if ! run_script "00-auto-configure.sh"; then
            log_error "Auto-configuration failed"
            return 1
        fi
        source "${CONFIG_DIR}/env.sh"
    fi
    
    # Check if passwords are set
    source "${CONFIG_DIR}/env.sh"
    if [[ -z "${POSTGRES_PASSWORD}" ]] || [[ -z "${GOTRUE_JWT_SECRET}" ]]; then
        log_warning "Passwords not configured. Running auto-configure..."
        if ! run_script "00-auto-configure.sh"; then
            log_error "Auto-configuration failed"
            return 1
        fi
        source "${CONFIG_DIR}/env.sh"
    fi
    
    local scripts=(
        "05-create-vm.sh"
        "06-configure-firewall.sh"
        "07-install-docker.sh"
        "08-deploy-appflowy-simplified.sh"
    )
    
    for script in "${scripts[@]}"; do
        if ! run_script "${script}"; then
            log_error "Deployment failed at: ${script}"
            echo ""
            echo "You can fix the issue and run this script again."
            echo "The deployment will continue from where it left off."
            exit 1
        fi
        echo ""
    done
    
    log_success "Full VM deployment completed successfully!"
    verify_appflowy_deployment
}

stop_appflowy() {
    source "${CONFIG_DIR}/env.sh"
    
    log_info "Stopping AppFlowy services..."
    
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/config && docker compose down"; then
        log_success "AppFlowy services stopped"
    else
        log_error "Failed to stop AppFlowy services"
    fi
}

start_appflowy() {
    source "${CONFIG_DIR}/env.sh"
    
    log_info "Starting AppFlowy services..."
    
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/config && docker compose up -d"; then
        log_success "AppFlowy services started"
        sleep 5
        verify_appflowy_deployment
    else
        log_error "Failed to start AppFlowy services"
    fi
}

view_appflowy_logs() {
    source "${CONFIG_DIR}/env.sh"
    
    log_info "Fetching AppFlowy logs (press Ctrl+C to exit)..."
    echo ""
    
    gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/config && docker compose logs -f --tail=50"
}

verify_appflowy_deployment() {
    source "${CONFIG_DIR}/env.sh"
    
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    if [[ -n "${vm_ip}" ]]; then
        echo ""
        echo "AppFlowy Deployment Status:"
        echo "  VM IP: ${vm_ip}"
        
        # Check services
        if curl -s -o /dev/null -w "%{http_code}" "http://${vm_ip}/health" 2>/dev/null | grep -q "200"; then
            echo "  ✓ Nginx proxy running"
        else
            echo "  ✗ Nginx proxy not responding"
        fi
        
        if curl -s -o /dev/null -w "%{http_code}" "http://${vm_ip}:${APPFLOWY_PORT:-8000}/health" 2>/dev/null | grep -q "200"; then
            echo "  ✓ AppFlowy Cloud running"
        else
            echo "  ✗ AppFlowy Cloud not responding"
        fi
        
        echo ""
        echo "Access URLs:"
        echo "  Main: http://${vm_ip}"
        echo "  API: http://${vm_ip}:${APPFLOWY_PORT:-8000}"
        echo ""
    fi
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
    
    # Check VM if configured
    if [[ -n "${VM_NAME}" ]]; then
        echo ""
        echo "VM Configuration:"
        echo "  VM Name: ${VM_NAME}"
        echo "  Zone: ${VM_ZONE}"
        echo "  Machine Type: ${VM_MACHINE_TYPE}"
        
        local vm_status=$(gcloud compute instances describe "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
        
        if [[ "${vm_status}" == "RUNNING" ]]; then
            echo "  Status: ✓ VM running"
            
            local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
                --zone="${VM_ZONE}" \
                --project="${PROJECT_ID}" \
                --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
            echo "  External IP: ${vm_ip}"
            
            # Check Docker installation
            if gcloud compute ssh "${VM_NAME}" \
                --zone="${VM_ZONE}" \
                --project="${PROJECT_ID}" \
                --command="docker --version" &>/dev/null; then
                echo "  Docker: ✓ Installed"
            else
                echo "  Docker: ✗ Not installed"
            fi
            
            # Check AppFlowy deployment
            verify_appflowy_deployment
        elif [[ "${vm_status}" == "NOT_FOUND" ]]; then
            echo "  Status: ✗ VM not created"
        else
            echo "  Status: ⚠ VM ${vm_status}"
        fi
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