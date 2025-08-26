#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"
PROGRESS_FILE="${SCRIPT_DIR}/.setup_progress"

# Color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Unicode characters for UI (using ASCII for compatibility)
CHECK="[OK]"
CROSS="[X]"
ARROW="==>"
STAR="*"
BULLET="-"
BOX_TL="+"
BOX_TR="+"
BOX_BL="+"
BOX_BR="+"
BOX_H="-"
BOX_V="|"
BOX_T="+"
BOX_B="+"
BOX_L="+"
BOX_R="+"
BOX_X="+"

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=8

# Load or initialize progress
load_progress() {
    if [[ -f "${PROGRESS_FILE}" ]]; then
        source "${PROGRESS_FILE}"
    else
        COMPLETED_STEPS=""
        echo "COMPLETED_STEPS=\"\"" > "${PROGRESS_FILE}"
    fi
}

save_progress() {
    local step="$1"
    if [[ ! "${COMPLETED_STEPS}" =~ ${step} ]]; then
        COMPLETED_STEPS="${COMPLETED_STEPS}${step},"
        echo "COMPLETED_STEPS=\"${COMPLETED_STEPS}\"" > "${PROGRESS_FILE}"
    fi
}

is_step_completed() {
    local step="$1"
    [[ "${COMPLETED_STEPS}" =~ ${step} ]]
}

# UI Helper Functions
print_banner() {
    clear
    echo ""
    echo -e "${CYAN}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${NC}"
    echo -e "${CYAN}${BOX_V}                                                          ${BOX_V}${NC}"
    echo -e "${CYAN}${BOX_V}${NC}  ${BOLD}${MAGENTA}${STAR} 42 GALAXIES WORKSPACE ${STAR}${NC}                             ${CYAN}${BOX_V}${NC}"
    echo -e "${CYAN}${BOX_V}${NC}  ${WHITE}GCP Infrastructure Setup Guide${NC}                        ${CYAN}${BOX_V}${NC}"
    echo -e "${CYAN}${BOX_V}                                                          ${BOX_V}${NC}"
    echo -e "${CYAN}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${NC}"
    echo ""
}

print_step_header() {
    local step_num="$1"
    local step_title="$2"
    local completed="${3:-false}"
    
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    
    if [[ "${completed}" == "true" ]]; then
        echo -e "${GREEN}${CHECK} Step ${step_num}/${TOTAL_STEPS}: ${step_title} [COMPLETED]${NC}"
    else
        echo -e "${YELLOW}${ARROW} Step ${step_num}/${TOTAL_STEPS}: ${step_title}${NC}"
    fi
    
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_progress_bar() {
    local current="$1"
    local total="$2"
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    echo -ne "\r  Progress: ["
    
    for ((i=0; i<width; i++)); do
        if ((i < filled)); then
            echo -ne "${GREEN}#${NC}"
        else
            echo -ne "${DIM}-${NC}"
        fi
    done
    
    echo -ne "] ${percentage}% (${current}/${total})"
}

print_info() {
    echo -e "  ${CYAN}${BULLET}${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}${CHECK}${NC} $1"
}

print_error() {
    echo -e "  ${RED}${CROSS}${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}!${NC} $1"
}

print_question() {
    echo -e "\n  ${MAGENTA}?${NC} $1"
}

print_box() {
    local title="$1"
    shift
    local lines=("$@")
    local max_width=50
    
    # Find the longest line
    for line in "${lines[@]}"; do
        if [[ ${#line} -gt ${max_width} ]]; then
            max_width=${#line}
        fi
    done
    
    # Top border
    echo -ne "  ${CYAN}${BOX_TL}"
    printf "%${max_width}s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    
    # Title if provided
    if [[ -n "${title}" ]]; then
        printf "  ${CYAN}${BOX_V}${NC} ${BOLD}%-$((max_width-2))s ${CYAN}${BOX_V}${NC}\n" "${title}"
        
        # Separator
        echo -ne "  ${CYAN}${BOX_L}"
        printf "%${max_width}s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_R}${NC}"
    fi
    
    # Content
    for line in "${lines[@]}"; do
        printf "  ${CYAN}${BOX_V}${NC} %-$((max_width-2))s ${CYAN}${BOX_V}${NC}\n" "${line}"
    done
    
    # Bottom border
    echo -ne "  ${CYAN}${BOX_BL}"
    printf "%${max_width}s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
}

wait_for_enter() {
    echo ""
    echo -e "  ${DIM}Press ${NC}${BOLD}ENTER${NC}${DIM} to continue...${NC}"
    read -r
}

confirm_action() {
    local prompt="$1"
    local response
    
    print_question "${prompt} (y/n)"
    echo -n "  > "
    read -r response
    
    [[ "${response}" =~ ^[Yy]$ ]]
}

# Step Functions
step_0_welcome() {
    print_banner
    
    echo -e "${BOLD}Welcome to the 42 Galaxies Workspace Setup Guide!${NC}"
    echo ""
    echo "This interactive guide will walk you through setting up your"
    echo "Google Cloud Platform infrastructure step by step."
    echo ""
    
    print_box "What We'll Set Up" \
        "- Create GCP Project: galaxies-workspace-42" \
        "- Link your billing account" \
        "- Enable essential APIs" \
        "- Configure billing alerts" \
        "- Verify everything works"
    
    echo ""
    print_box "Prerequisites" \
        "- Google Cloud SDK (gcloud CLI)" \
        "- Active Google Cloud account" \
        "- Billing account ID" \
        "- About 10 minutes"
    
    echo ""
    
    if [[ -f "${PROGRESS_FILE}" ]] && [[ -n "${COMPLETED_STEPS}" ]]; then
        print_warning "Previous progress detected. We'll continue from where you left off."
    fi
    
    wait_for_enter
}

step_1_check_prerequisites() {
    print_banner
    print_step_header 1 "Checking Prerequisites" $(is_step_completed "prereq" && echo "true" || echo "false")
    
    local all_good=true
    
    # Check gcloud
    print_info "Checking for Google Cloud SDK..."
    if command -v gcloud &> /dev/null; then
        local version=$(gcloud version --format="value(version)" 2>/dev/null | head -n1)
        print_success "gcloud CLI found (version: ${version})"
    else
        print_error "gcloud CLI not found"
        echo ""
        print_box "Installation Instructions" \
            "Run the following command:" \
            "" \
            "curl https://sdk.cloud.google.com | bash" \
            "" \
            "Or visit:" \
            "https://cloud.google.com/sdk/docs/install"
        all_good=false
    fi
    
    # Check authentication
    print_info "Checking authentication..."
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
        print_success "Authenticated as: ${account}"
    else
        print_error "Not authenticated with Google Cloud"
        echo ""
        print_box "To Authenticate" \
            "Run: gcloud auth login" \
            "Then: gcloud auth application-default login"
        all_good=false
    fi
    
    # Check for config file
    print_info "Checking configuration..."
    if [[ -f "${CONFIG_DIR}/env.sh" ]]; then
        print_success "Configuration file exists"
    else
        print_warning "Configuration file not found (we'll create it)"
    fi
    
    echo ""
    
    if [[ "${all_good}" == "true" ]]; then
        print_success "All prerequisites met!"
        save_progress "prereq"
        wait_for_enter
        return 0
    else
        print_error "Some prerequisites are missing."
        if confirm_action "Do you want to continue anyway?"; then
            save_progress "prereq"
            return 0
        else
            echo ""
            print_info "Please install the missing prerequisites and run again."
            exit 1
        fi
    fi
}

step_2_configure_environment() {
    print_banner
    print_step_header 2 "Configure Environment" $(is_step_completed "config" && echo "true" || echo "false")
    
    if [[ -f "${CONFIG_DIR}/env.sh" ]]; then
        print_success "Configuration file already exists"
        source "${CONFIG_DIR}/env.sh"
        
        print_box "Current Configuration" \
            "Project ID: ${PROJECT_ID:-not set}" \
            "Project Name: ${PROJECT_NAME:-not set}" \
            "Billing Account: ${BILLING_ACCOUNT_ID:-not set}" \
            "Alert Email: ${ALERT_EMAIL:-not set}" \
            "Budget: \$${BUDGET_AMOUNT:-100} USD"
        
        echo ""
        if confirm_action "Do you want to reconfigure?"; then
            create_config_interactive
        else
            save_progress "config"
        fi
    else
        print_info "Let's create your configuration file."
        create_config_interactive
    fi
    
    wait_for_enter
}

create_config_interactive() {
    echo ""
    print_box "Configuration Setup" \
        "We'll now set up your environment configuration." \
        "Default values are provided where applicable."
    
    echo ""
    
    # Project ID
    print_question "Enter Project ID (must be globally unique) [galaxies-workspace-42]:"
    echo -n "  > "
    read -r project_id
    project_id="${project_id:-galaxies-workspace-42}"
    
    # Project Name
    print_question "Enter Project Display Name [42 Galaxies Workspace]:"
    echo -n "  > "
    read -r project_name
    project_name="${project_name:-42 Galaxies Workspace}"
    
    # List billing accounts
    echo ""
    print_info "Fetching your billing accounts..."
    echo ""
    gcloud billing accounts list --format="table(name,displayName,open)" 2>/dev/null || true
    echo ""
    
    # Billing Account
    print_question "Enter Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX):"
    echo -n "  > "
    read -r billing_account
    
    # Alert Email
    print_question "Enter email for billing alerts:"
    echo -n "  > "
    read -r alert_email
    
    # Budget Amount
    print_question "Enter monthly budget in USD [100]:"
    echo -n "  > "
    read -r budget_amount
    budget_amount="${budget_amount:-100}"
    
    # Organization ID (optional)
    print_question "Enter Organization ID (optional, press ENTER to skip):"
    echo -n "  > "
    read -r org_id
    
    # Create config file
    cat > "${CONFIG_DIR}/env.sh" <<EOF
#!/bin/bash
# Generated by 42 Galaxies Workspace Setup Guide
# Created: $(date)

# Project Configuration
PROJECT_ID="${project_id}"
PROJECT_NAME="${project_name}"

# Organization Configuration
ORGANIZATION_ID="${org_id}"
FOLDER_ID=""

# Billing Configuration
BILLING_ACCOUNT_ID="${billing_account}"

# Alert Configuration
ALERT_EMAIL="${alert_email}"
BUDGET_AMOUNT="${budget_amount}"
BUDGET_NAME="galaxies-workspace-budget"
THRESHOLD_PERCENT="50"

# API Configuration
ENABLE_OPTIONAL_APIS="true"

# Monitoring Configuration
ENABLE_MONITORING_ALERTS="true"

# Script Behavior
VERBOSE="true"

# Region Configuration
DEFAULT_REGION="us-central1"
DEFAULT_ZONE="us-central1-a"

# Network Configuration
VPC_NETWORK_NAME="galaxies-vpc"
SUBNET_CIDR="10.0.0.0/24"
EOF
    
    chmod 600 "${CONFIG_DIR}/env.sh"
    
    echo ""
    print_success "Configuration saved to config/env.sh"
    save_progress "config"
}

step_3_create_project() {
    print_banner
    print_step_header 3 "Create GCP Project" $(is_step_completed "project" && echo "true" || echo "false")
    
    source "${CONFIG_DIR}/env.sh"
    
    print_info "Creating project: ${PROJECT_ID}"
    print_info "Display name: ${PROJECT_NAME}"
    echo ""
    
    if confirm_action "Create this project?"; then
        echo ""
        if "${SCRIPTS_DIR}/01-create-project.sh"; then
            save_progress "project"
            print_success "Project created successfully!"
        else
            print_error "Failed to create project"
            return 1
        fi
    else
        print_warning "Skipping project creation"
    fi
    
    wait_for_enter
}

step_4_link_billing() {
    print_banner
    print_step_header 4 "Link Billing Account" $(is_step_completed "billing" && echo "true" || echo "false")
    
    source "${CONFIG_DIR}/env.sh"
    
    print_info "Linking billing account: ${BILLING_ACCOUNT_ID}"
    print_info "To project: ${PROJECT_ID}"
    echo ""
    
    if confirm_action "Link billing account?"; then
        echo ""
        if "${SCRIPTS_DIR}/02-link-billing.sh"; then
            save_progress "billing"
            print_success "Billing account linked successfully!"
        else
            print_error "Failed to link billing account"
            return 1
        fi
    else
        print_warning "Skipping billing account linking"
    fi
    
    wait_for_enter
}

step_5_enable_apis() {
    print_banner
    print_step_header 5 "Enable APIs" $(is_step_completed "apis" && echo "true" || echo "false")
    
    source "${CONFIG_DIR}/env.sh"
    
    print_box "APIs to Enable" \
        "- Compute Engine (compute.googleapis.com)" \
        "- Cloud Build (cloudbuild.googleapis.com)" \
        "- Secret Manager (secretmanager.googleapis.com)" \
        "- Artifact Registry (artifactregistry.googleapis.com)" \
        "" \
        "Optional APIs (if enabled):" \
        "- Cloud Resource Manager" \
        "- IAM" \
        "- Cloud Monitoring" \
        "- Cloud Logging" \
        "- Cloud Storage"
    
    echo ""
    
    if confirm_action "Enable these APIs?"; then
        echo ""
        if "${SCRIPTS_DIR}/03-enable-apis.sh"; then
            save_progress "apis"
            print_success "APIs enabled successfully!"
        else
            print_error "Failed to enable APIs"
            return 1
        fi
    else
        print_warning "Skipping API enablement"
    fi
    
    wait_for_enter
}

step_6_setup_alerts() {
    print_banner
    print_step_header 6 "Setup Billing Alerts" $(is_step_completed "alerts" && echo "true" || echo "false")
    
    source "${CONFIG_DIR}/env.sh"
    
    # Calculate thresholds (with fallback if bc is not available)
    if command -v bc &>/dev/null; then
        local t50=$(echo "scale=2; ${BUDGET_AMOUNT} * 0.5" | bc)
        local t75=$(echo "scale=2; ${BUDGET_AMOUNT} * 0.75" | bc)
        local t90=$(echo "scale=2; ${BUDGET_AMOUNT} * 0.9" | bc)
        local t120=$(echo "scale=2; ${BUDGET_AMOUNT} * 1.2" | bc)
    else
        local t50=$((BUDGET_AMOUNT * 50 / 100))
        local t75=$((BUDGET_AMOUNT * 75 / 100))
        local t90=$((BUDGET_AMOUNT * 90 / 100))
        local t120=$((BUDGET_AMOUNT * 120 / 100))
    fi
    
    print_box "Alert Configuration" \
        "Budget Amount: \$${BUDGET_AMOUNT} USD/month" \
        "Alert Email: ${ALERT_EMAIL}" \
        "" \
        "Alerts will trigger at:" \
        "- 50% (\$${t50})" \
        "- 75% (\$${t75})" \
        "- 90% (\$${t90})" \
        "- 100% (\$${BUDGET_AMOUNT})" \
        "- 120% (\$${t120})"
    
    echo ""
    
    if confirm_action "Setup billing alerts?"; then
        echo ""
        if "${SCRIPTS_DIR}/04-setup-billing-alerts.sh"; then
            save_progress "alerts"
            print_success "Billing alerts configured successfully!"
        else
            print_error "Failed to setup billing alerts"
            return 1
        fi
    else
        print_warning "Skipping billing alerts setup"
    fi
    
    wait_for_enter
}

step_7_verify() {
    print_banner
    print_step_header 7 "Verify Setup" $(is_step_completed "verify" && echo "true" || echo "false")
    
    source "${CONFIG_DIR}/env.sh"
    
    print_info "Running verification checks..."
    echo ""
    
    local all_good=true
    
    # Check project
    print_info "Checking project..."
    if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        print_success "Project '${PROJECT_ID}' exists"
    else
        print_error "Project '${PROJECT_ID}' not found"
        all_good=false
    fi
    
    # Check billing
    print_info "Checking billing..."
    local billing_enabled=$(gcloud billing projects describe "${PROJECT_ID}" --format="value(billingEnabled)" 2>/dev/null || echo "False")
    if [[ "${billing_enabled}" == "True" ]]; then
        print_success "Billing is enabled"
    else
        print_error "Billing is not enabled"
        all_good=false
    fi
    
    # Check APIs
    print_info "Checking required APIs..."
    local required_apis=(
        "compute.googleapis.com"
        "cloudbuild.googleapis.com"
        "secretmanager.googleapis.com"
        "artifactregistry.googleapis.com"
    )
    
    for api in "${required_apis[@]}"; do
        if gcloud services list --project="${PROJECT_ID}" --filter="name:${api}" --enabled --format="value(name)" 2>/dev/null | grep -q "${api}"; then
            print_success "${api}"
        else
            print_error "${api} not enabled"
            all_good=false
        fi
    done
    
    # Check budgets
    print_info "Checking budget alerts..."
    local budget_count=$(gcloud billing budgets list --billing-account="${BILLING_ACCOUNT_ID}" --format="value(name)" 2>/dev/null | wc -l)
    if [[ ${budget_count} -gt 0 ]]; then
        print_success "${budget_count} budget(s) configured"
    else
        print_warning "No budgets configured"
    fi
    
    echo ""
    
    if [[ "${all_good}" == "true" ]]; then
        print_success "All checks passed! Your setup is complete."
        save_progress "verify"
    else
        print_warning "Some checks failed. You may need to run specific steps again."
    fi
    
    wait_for_enter
}

step_8_complete() {
    print_banner
    print_step_header 8 "Setup Complete!" "true"
    
    source "${CONFIG_DIR}/env.sh"
    
    echo -e "${GREEN}${STAR} Congratulations! Your 42 Galaxies Workspace is ready! ${STAR}${NC}"
    echo ""
    
    print_box "Summary" \
        "Project ID: ${PROJECT_ID}" \
        "Project Name: ${PROJECT_NAME}" \
        "Region: ${DEFAULT_REGION}" \
        "Budget: \$${BUDGET_AMOUNT} USD/month" \
        "Alerts: ${ALERT_EMAIL}"
    
    echo ""
    print_box "Next Steps" \
        "1. Set your project as default:" \
        "   gcloud config set project ${PROJECT_ID}" \
        "" \
        "2. View in Console:" \
        "   https://console.cloud.google.com/home/dashboard?project=${PROJECT_ID}" \
        "" \
        "3. Check billing dashboard:" \
        "   https://console.cloud.google.com/billing" \
        "" \
        "4. Deploy your first application!"
    
    echo ""
    print_box "Useful Commands" \
        "- View project info:" \
        "  gcloud projects describe ${PROJECT_ID}" \
        "" \
        "- List enabled APIs:" \
        "  gcloud services list --enabled" \
        "" \
        "- View current costs:" \
        "  gcloud billing accounts list" \
        "" \
        "- Run verification:" \
        "  ./setup.sh --verify"
    
    echo ""
    
    # Clean up progress file
    if confirm_action "Clear setup progress? (You can run the guide again anytime)"; then
        rm -f "${PROGRESS_FILE}"
        print_success "Progress cleared"
    fi
    
    echo ""
    print_success "Thank you for using the 42 Galaxies Workspace Setup Guide!"
    echo ""
}

# Main execution
main() {
    load_progress
    
    # Define steps
    local steps=(
        step_0_welcome
        step_1_check_prerequisites
        step_2_configure_environment
        step_3_create_project
        step_4_link_billing
        step_5_enable_apis
        step_6_setup_alerts
        step_7_verify
        step_8_complete
    )
    
    # Execute steps
    for step in "${steps[@]}"; do
        ${step}
    done
}

# Handle interruption
trap 'echo -e "\n\n${YELLOW}Setup interrupted. Your progress has been saved.${NC}\n"' INT

# Run the guide
main "$@"