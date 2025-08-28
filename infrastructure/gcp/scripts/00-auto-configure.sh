#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
ENV_FILE="${CONFIG_DIR}/env.sh"
ENV_TEMPLATE="${CONFIG_DIR}/env.sh.template"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
    echo "   GCP Auto-Configuration Script"
    echo "============================================"
    echo ""
    echo "This script will automatically detect and configure:"
    echo "  • Current GCP project"
    echo "  • Active billing account"
    echo "  • Your email address"
    echo "  • Default region/zone"
    echo "  • Generate secure passwords"
    echo ""
}

check_gcloud_auth() {
    log_info "Checking gcloud authentication..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        echo "Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    local active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n1)
    
    if [[ -z "${active_account}" ]]; then
        log_error "Not authenticated with gcloud"
        echo "Please run: gcloud auth login"
        exit 1
    fi
    
    log_success "Authenticated as: ${active_account}"
    echo ""
    return 0
}

detect_project() {
    log_info "Detecting GCP project..."
    
    # First check if a project is already set
    local current_project=$(gcloud config get-value project 2>/dev/null)
    
    if [[ -n "${current_project}" ]]; then
        log_success "Current project: ${current_project}"
        
        # Verify project exists and is accessible
        if gcloud projects describe "${current_project}" &>/dev/null; then
            PROJECT_ID="${current_project}"
            PROJECT_NAME=$(gcloud projects describe "${current_project}" --format="value(name)" 2>/dev/null || echo "${current_project}")
            return 0
        else
            log_warning "Current project '${current_project}' is not accessible"
        fi
    fi
    
    # List available projects
    log_info "Listing available projects..."
    local projects=$(gcloud projects list --format="value(projectId,name)" 2>/dev/null)
    
    if [[ -z "${projects}" ]]; then
        log_warning "No existing projects found"
        
        # Suggest creating a new project
        read -p "Enter a new project ID (lowercase, hyphens, 6-30 chars): " new_project_id
        read -p "Enter project display name: " new_project_name
        
        PROJECT_ID="${new_project_id}"
        PROJECT_NAME="${new_project_name}"
        CREATE_NEW_PROJECT="true"
    else
        echo ""
        echo "Available projects:"
        echo "${projects}" | nl
        echo ""
        
        # Let user select
        local num_projects=$(echo "${projects}" | wc -l)
        read -p "Select project number (1-${num_projects}): " selection
        
        local selected=$(echo "${projects}" | sed -n "${selection}p")
        PROJECT_ID=$(echo "${selected}" | awk '{print $1}')
        PROJECT_NAME=$(echo "${selected}" | cut -d' ' -f2-)
        
        # Set as current project
        gcloud config set project "${PROJECT_ID}" &>/dev/null
    fi
    
    log_success "Selected project: ${PROJECT_ID} (${PROJECT_NAME})"
    return 0
}

detect_billing() {
    log_info "Detecting billing account..."
    
    # List billing accounts
    local billing_accounts=$(gcloud billing accounts list --format="value(name,displayName)" 2>/dev/null)
    
    if [[ -z "${billing_accounts}" ]]; then
        log_warning "No billing accounts found"
        log_warning "You'll need to set up billing at: https://console.cloud.google.com/billing"
        BILLING_ACCOUNT_ID=""
    else
        local num_accounts=$(echo "${billing_accounts}" | wc -l)
        
        if [[ ${num_accounts} -eq 1 ]]; then
            # Only one account, use it
            BILLING_ACCOUNT_ID=$(echo "${billing_accounts}" | awk '{print $1}' | sed 's/billingAccounts\///')
            local billing_name=$(echo "${billing_accounts}" | cut -d' ' -f2-)
            log_success "Billing account: ${billing_name} (${BILLING_ACCOUNT_ID})"
        else
            # Multiple accounts, let user choose
            echo ""
            echo "Available billing accounts:"
            echo "${billing_accounts}" | nl
            echo ""
            
            read -p "Select billing account number (1-${num_accounts}): " selection
            
            local selected=$(echo "${billing_accounts}" | sed -n "${selection}p")
            BILLING_ACCOUNT_ID=$(echo "${selected}" | awk '{print $1}' | sed 's/billingAccounts\///')
            local billing_name=$(echo "${selected}" | cut -d' ' -f2-)
            log_success "Selected billing: ${billing_name} (${BILLING_ACCOUNT_ID})"
        fi
    fi
    
    return 0
}

detect_user_info() {
    log_info "Detecting user information..."
    
    # Get authenticated user email
    ALERT_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
    log_success "User email: ${ALERT_EMAIL}"
    
    # Get organization if exists
    ORGANIZATION_ID=$(gcloud organizations list --format="value(name)" 2>/dev/null | head -n1 | sed 's/organizations\///' || echo "")
    if [[ -n "${ORGANIZATION_ID}" ]]; then
        log_success "Organization ID: ${ORGANIZATION_ID}"
    fi
    
    return 0
}

detect_compute_defaults() {
    log_info "Detecting compute defaults..."
    
    # Try to get default region/zone from gcloud config
    local default_zone=$(gcloud config get-value compute/zone 2>/dev/null || echo "")
    local default_region=$(gcloud config get-value compute/region 2>/dev/null || echo "")
    
    if [[ -z "${default_zone}" ]]; then
        # Suggest based on common regions
        echo ""
        echo "Select a default zone for your VM:"
        echo "  1) us-central1-a (Iowa, USA)"
        echo "  2) us-east1-b (South Carolina, USA)"
        echo "  3) us-west1-a (Oregon, USA)"
        echo "  4) europe-west1-b (Belgium)"
        echo "  5) asia-east1-a (Taiwan)"
        echo "  6) Custom"
        echo ""
        
        read -p "Select zone (1-6): " zone_choice
        
        case ${zone_choice} in
            1) VM_ZONE="us-central1-a"; VM_REGION="us-central1" ;;
            2) VM_ZONE="us-east1-b"; VM_REGION="us-east1" ;;
            3) VM_ZONE="us-west1-a"; VM_REGION="us-west1" ;;
            4) VM_ZONE="europe-west1-b"; VM_REGION="europe-west1" ;;
            5) VM_ZONE="asia-east1-a"; VM_REGION="asia-east1" ;;
            6) 
                read -p "Enter zone (e.g., us-central1-a): " VM_ZONE
                VM_REGION=$(echo "${VM_ZONE}" | sed 's/-[a-z]$//')
                ;;
            *) VM_ZONE="us-central1-a"; VM_REGION="us-central1" ;;
        esac
        
        # Set as default
        gcloud config set compute/zone "${VM_ZONE}" &>/dev/null
        gcloud config set compute/region "${VM_REGION}" &>/dev/null
    else
        VM_ZONE="${default_zone}"
        VM_REGION="${default_region:-$(echo "${default_zone}" | sed 's/-[a-z]$//')}"
    fi
    
    log_success "Default zone: ${VM_ZONE}"
    log_success "Default region: ${VM_REGION}"
    
    return 0
}

detect_external_ip() {
    log_info "Detecting your external IP for SSH restrictions..."
    
    # Try multiple services to get external IP
    local my_ip=""
    
    for service in "ifconfig.me" "ipinfo.io/ip" "checkip.amazonaws.com"; do
        my_ip=$(curl -s --max-time 2 "https://${service}" 2>/dev/null || echo "")
        if [[ -n "${my_ip}" ]] && [[ "${my_ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done
    
    if [[ -n "${my_ip}" ]]; then
        log_success "Your external IP: ${my_ip}"
        SSH_SOURCE_RANGES="${my_ip}/32"
        
        read -p "Restrict SSH access to only your IP? (recommended) [Y/n]: " restrict_ssh
        if [[ "${restrict_ssh,,}" == "n" ]]; then
            SSH_SOURCE_RANGES="0.0.0.0/0"
            log_warning "SSH will be open to all IPs (not recommended)"
        else
            log_success "SSH restricted to: ${SSH_SOURCE_RANGES}"
        fi
    else
        log_warning "Could not detect external IP"
        SSH_SOURCE_RANGES="0.0.0.0/0"
    fi
    
    return 0
}

generate_passwords() {
    log_info "Generating secure passwords..."
    
    # Generate secure random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    GOTRUE_JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    log_success "Generated PostgreSQL password (32 chars)"
    log_success "Generated JWT secret (32 chars)"
    
    return 0
}

detect_vm_config() {
    log_info "Configuring VM specifications..."
    
    echo ""
    echo "Select VM machine type:"
    echo "  1) e2-micro (0.25-2 vCPU, 1GB RAM) - ~$6/month, free tier eligible"
    echo "  2) e2-small (0.5-2 vCPU, 2GB RAM) - ~$13/month"
    echo "  3) e2-medium (1-2 vCPU, 4GB RAM) - ~$27/month [RECOMMENDED]"
    echo "  4) e2-standard-2 (2 vCPU, 8GB RAM) - ~$67/month"
    echo ""
    
    read -p "Select machine type (1-4) [3]: " machine_choice
    machine_choice=${machine_choice:-3}
    
    case ${machine_choice} in
        1) VM_MACHINE_TYPE="e2-micro" ;;
        2) VM_MACHINE_TYPE="e2-small" ;;
        3) VM_MACHINE_TYPE="e2-medium" ;;
        4) VM_MACHINE_TYPE="e2-standard-2" ;;
        *) VM_MACHINE_TYPE="e2-medium" ;;
    esac
    
    log_success "Selected machine type: ${VM_MACHINE_TYPE}"
    
    # VM Name
    read -p "Enter VM name [appflowy-workspace]: " vm_name
    VM_NAME="${vm_name:-appflowy-workspace}"
    
    return 0
}

detect_domain_config() {
    log_info "Configuring domain settings..."
    
    echo ""
    read -p "Do you have a domain for AppFlowy? (e.g., workspace.42galaxies.studio) [y/N]: " has_domain
    
    if [[ "${has_domain,,}" == "y" ]]; then
        read -p "Enter your domain: " SITE_URL
        SITE_URL="https://${SITE_URL}"
        log_success "Site URL: ${SITE_URL}"
        
        echo ""
        echo "For Google OAuth setup:"
        echo "  1. Go to: https://console.cloud.google.com/apis/credentials"
        echo "  2. Create OAuth 2.0 Client ID (Web application)"
        echo "  3. Add authorized redirect URI: ${SITE_URL}/auth/callback"
        echo ""
        
        read -p "Do you have Google OAuth credentials? [y/N]: " has_oauth
        
        if [[ "${has_oauth,,}" == "y" ]]; then
            read -p "Enter Google Client ID: " GOOGLE_CLIENT_ID
            read -p "Enter Google Client Secret: " GOOGLE_CLIENT_SECRET
            GOOGLE_OAUTH_ENABLED="true"
            log_success "Google OAuth configured"
        else
            GOOGLE_CLIENT_ID=""
            GOOGLE_CLIENT_SECRET=""
            GOOGLE_OAUTH_ENABLED="false"
            log_warning "Google OAuth skipped (can be added later)"
        fi
    else
        SITE_URL=""
        GOOGLE_CLIENT_ID=""
        GOOGLE_CLIENT_SECRET=""
        GOOGLE_OAUTH_ENABLED="false"
        log_info "No domain configured (will use IP address)"
    fi
    
    return 0
}

write_env_file() {
    log_info "Writing configuration to env.sh..."
    
    # Backup existing file if it exists
    if [[ -f "${ENV_FILE}" ]]; then
        cp "${ENV_FILE}" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing env.sh"
    fi
    
    cat > "${ENV_FILE}" << EOF
#!/bin/bash
# Auto-generated configuration - $(date)
# Generated by: $(whoami)@$(hostname)

# ==============================================================================
# PROJECT CONFIGURATION (Auto-detected)
# ==============================================================================

PROJECT_ID="${PROJECT_ID}"
PROJECT_NAME="${PROJECT_NAME}"

# ==============================================================================
# ORGANIZATION CONFIGURATION (Auto-detected)
# ==============================================================================

ORGANIZATION_ID="${ORGANIZATION_ID}"
FOLDER_ID=""

# ==============================================================================
# BILLING CONFIGURATION (Auto-detected)
# ==============================================================================

BILLING_ACCOUNT_ID="${BILLING_ACCOUNT_ID}"

# ==============================================================================
# BUDGET & ALERTS CONFIGURATION
# ==============================================================================

ALERT_EMAIL="${ALERT_EMAIL}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-10}"
BUDGET_NAME="${BUDGET_NAME:-galaxies-workspace-budget}"
THRESHOLD_PERCENT="50"

# ==============================================================================
# API CONFIGURATION
# ==============================================================================

ENABLE_OPTIONAL_APIS="true"

# ==============================================================================
# MONITORING CONFIGURATION
# ==============================================================================

ENABLE_MONITORING_ALERTS="true"

# ==============================================================================
# SCRIPT BEHAVIOR
# ==============================================================================

VERBOSE="true"

# ==============================================================================
# REGION CONFIGURATION (Auto-detected)
# ==============================================================================

DEFAULT_REGION="${VM_REGION}"
DEFAULT_ZONE="${VM_ZONE}"

# ==============================================================================
# VM CONFIGURATION
# ==============================================================================

VM_NAME="${VM_NAME}"
VM_ZONE="${VM_ZONE}"
VM_REGION="${VM_REGION}"
VM_MACHINE_TYPE="${VM_MACHINE_TYPE}"

# ==============================================================================
# APPFLOWY CONFIGURATION (Auto-generated passwords)
# ==============================================================================

POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
GOTRUE_JWT_SECRET="${GOTRUE_JWT_SECRET}"
APPFLOWY_PORT="8000"
APPFLOWY_WS_PORT="8001"
SITE_URL="${SITE_URL}"

# ==============================================================================
# GOOGLE OAUTH CONFIGURATION
# ==============================================================================

GOOGLE_OAUTH_ENABLED="${GOOGLE_OAUTH_ENABLED}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}"

# ==============================================================================
# EMAIL CONFIGURATION
# ==============================================================================

MAILER_AUTOCONFIRM="true"
DISABLE_SIGNUP="false"
SMTP_ADMIN_EMAIL="${ALERT_EMAIL}"
SMTP_HOST=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""
SMTP_SENDER_NAME="AppFlowy Workspace"

# ==============================================================================
# STORAGE CONFIGURATION
# ==============================================================================

S3_ACCESS_KEY_ID=""
S3_SECRET_ACCESS_KEY=""
S3_BUCKET="appflowy-data"
S3_REGION="${VM_REGION}"
S3_ENDPOINT=""

# ==============================================================================
# SECURITY CONFIGURATION
# ==============================================================================

SSH_SOURCE_RANGES="${SSH_SOURCE_RANGES}"

# ==============================================================================
# NETWORKING CONFIGURATION
# ==============================================================================

VPC_NETWORK_NAME="galaxies-vpc"
SUBNET_CIDR="10.0.0.0/24"

# ==============================================================================
# BACKUP CONFIGURATION
# ==============================================================================

ENABLE_BACKUPS="true"
BACKUP_RETENTION_DAYS="30"

# ==============================================================================
# Fork Management (Optional)
# ==============================================================================

GITHUB_ORG="42-galaxies"
FORK_REPO_NAME="appflowy-cloud"
CUSTOM_IMAGE_TAG="latest"
REGISTRY_PREFIX="gcr.io/${PROJECT_ID}"
EOF
    
    chmod 600 "${ENV_FILE}"
    log_success "Configuration written to: ${ENV_FILE}"
    
    return 0
}

show_summary() {
    echo ""
    echo "============================================"
    echo "   Configuration Summary"
    echo "============================================"
    echo ""
    echo "GCP Project:"
    echo "  ID: ${PROJECT_ID}"
    echo "  Name: ${PROJECT_NAME}"
    echo "  Billing: ${BILLING_ACCOUNT_ID:-Not configured}"
    echo ""
    echo "VM Configuration:"
    echo "  Name: ${VM_NAME}"
    echo "  Type: ${VM_MACHINE_TYPE}"
    echo "  Zone: ${VM_ZONE}"
    echo ""
    echo "Security:"
    echo "  PostgreSQL: [GENERATED - 32 chars]"
    echo "  JWT Secret: [GENERATED - 32 chars]"
    echo "  SSH Access: ${SSH_SOURCE_RANGES}"
    echo ""
    
    if [[ -n "${SITE_URL}" ]]; then
        echo "Domain:"
        echo "  URL: ${SITE_URL}"
        echo "  OAuth: ${GOOGLE_OAUTH_ENABLED}"
        echo ""
    fi
    
    echo "Configuration saved to:"
    echo "  ${ENV_FILE}"
    echo ""
    echo "Passwords have been securely generated and saved."
    echo "Keep this file safe and never commit it to git!"
    echo ""
    
    # Save a secure copy of passwords
    local password_file="${CONFIG_DIR}/.passwords.$(date +%Y%m%d_%H%M%S)"
    cat > "${password_file}" << EOF
# AppFlowy Passwords - Generated $(date)
# KEEP THIS FILE SECURE - DO NOT SHARE
#
# PostgreSQL Password:
${POSTGRES_PASSWORD}

# JWT Secret:
${GOTRUE_JWT_SECRET}

# Project: ${PROJECT_ID}
# VM: ${VM_NAME}
EOF
    chmod 600 "${password_file}"
    
    echo "Passwords also saved to: ${password_file}"
    echo ""
}

main() {
    print_banner
    
    # Check gcloud authentication
    check_gcloud_auth
    
    # Auto-detect everything
    detect_project
    detect_billing
    detect_user_info
    detect_compute_defaults
    detect_external_ip
    detect_vm_config
    generate_passwords
    detect_domain_config
    
    # Write configuration
    write_env_file
    
    # Show summary
    show_summary
    
    echo "✅ Auto-configuration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Review the configuration in: config/env.sh"
    echo "  2. Run: ./setup.sh --full  (to create GCP project)"
    echo "  3. Run: ./setup.sh and choose option 10 (to deploy AppFlowy)"
    echo ""
    
    read -p "Would you like to start the deployment now? [Y/n]: " start_now
    
    if [[ "${start_now,,}" != "n" ]]; then
        cd "${SCRIPT_DIR}/.."
        ./setup.sh
    fi
}

main "$@"