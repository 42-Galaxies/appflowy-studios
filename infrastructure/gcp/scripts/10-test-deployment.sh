#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/../config/env.sh"

# Colors for output
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

print_test_header() {
    echo ""
    echo "================================================"
    echo "   AppFlowy Deployment Test Suite"
    echo "================================================"
    echo ""
}

test_gcp_project() {
    log_info "Testing GCP Project Configuration..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Project exists
    if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Project '${PROJECT_ID}' exists"
        ((tests_passed++))
    else
        echo -e "  ${RED}✗${NC} Project '${PROJECT_ID}' not found"
        ((tests_failed++))
        status="FAIL"
    fi
    
    # Test 2: Billing is enabled
    if gcloud billing projects describe "${PROJECT_ID}" 2>/dev/null | grep -q "billingEnabled: true"; then
        echo -e "  ${GREEN}✓${NC} Billing is enabled"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} Billing might not be enabled"
        ((tests_failed++))
    fi
    
    # Test 3: Required APIs
    local required_apis=("compute.googleapis.com")
    for api in "${required_apis[@]}"; do
        if gcloud services list --project="${PROJECT_ID}" --enabled --filter="name:${api}" --format="value(name)" 2>/dev/null | grep -q "${api}"; then
            echo -e "  ${GREEN}✓${NC} API enabled: ${api}"
            ((tests_passed++))
        else
            echo -e "  ${RED}✗${NC} API not enabled: ${api}"
            ((tests_failed++))
            status="FAIL"
        fi
    done
    
    echo ""
    echo "GCP Project Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_vm_instance() {
    log_info "Testing VM Instance..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: VM exists
    if gcloud compute instances describe "${VM_NAME}" --zone="${VM_ZONE}" --project="${PROJECT_ID}" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} VM '${VM_NAME}' exists"
        ((tests_passed++))
        
        # Test 2: VM is running
        local vm_status=$(gcloud compute instances describe "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --format="value(status)" 2>/dev/null)
        
        if [[ "${vm_status}" == "RUNNING" ]]; then
            echo -e "  ${GREEN}✓${NC} VM is running"
            ((tests_passed++))
        else
            echo -e "  ${RED}✗${NC} VM is not running (status: ${vm_status})"
            ((tests_failed++))
            status="FAIL"
        fi
        
        # Test 3: External IP exists
        local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
        
        if [[ -n "${external_ip}" ]]; then
            echo -e "  ${GREEN}✓${NC} External IP: ${external_ip}"
            ((tests_passed++))
        else
            echo -e "  ${RED}✗${NC} No external IP assigned"
            ((tests_failed++))
            status="FAIL"
        fi
        
        # Test 4: SSH connectivity
        if gcloud compute ssh "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --command="echo 'SSH test successful'" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} SSH connectivity working"
            ((tests_passed++))
        else
            echo -e "  ${YELLOW}⚠${NC} SSH connectivity issues"
            ((tests_failed++))
        fi
        
    else
        echo -e "  ${RED}✗${NC} VM '${VM_NAME}' does not exist"
        ((tests_failed++))
        status="FAIL"
    fi
    
    echo ""
    echo "VM Instance Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_firewall_rules() {
    log_info "Testing Firewall Rules..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    local firewall_rules=(
        "allow-http-${VM_NAME}"
        "allow-https-${VM_NAME}"
        "allow-ssh-${VM_NAME}"
        "allow-appflowy-${VM_NAME}"
    )
    
    for rule in "${firewall_rules[@]}"; do
        if gcloud compute firewall-rules describe "${rule}" --project="${PROJECT_ID}" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Firewall rule exists: ${rule}"
            ((tests_passed++))
        else
            echo -e "  ${RED}✗${NC} Firewall rule missing: ${rule}"
            ((tests_failed++))
            status="FAIL"
        fi
    done
    
    echo ""
    echo "Firewall Rules Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_docker_installation() {
    log_info "Testing Docker Installation..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Docker installed
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="docker --version" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker is installed"
        ((tests_passed++))
    else
        echo -e "  ${RED}✗${NC} Docker is not installed"
        ((tests_failed++))
        status="FAIL"
    fi
    
    # Test 2: Docker Compose installed
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="docker compose version" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker Compose is installed"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} Docker Compose might not be installed"
        ((tests_failed++))
    fi
    
    # Test 3: Docker service running
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="sudo systemctl is-active docker" 2>/dev/null | grep -q "active"; then
        echo -e "  ${GREEN}✓${NC} Docker service is running"
        ((tests_passed++))
    else
        echo -e "  ${RED}✗${NC} Docker service is not running"
        ((tests_failed++))
        status="FAIL"
    fi
    
    echo ""
    echo "Docker Installation Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_appflowy_containers() {
    log_info "Testing AppFlowy Containers..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    # Get container status
    local containers_output=$(gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/config 2>/dev/null && docker compose ps --format json 2>/dev/null || echo '{}'" 2>/dev/null || echo "{}")
    
    local required_containers=(
        "appflowy-postgres"
        "appflowy-gotrue"
        "appflowy-redis"
        "appflowy-nginx"
    )
    
    for container in "${required_containers[@]}"; do
        local container_status=$(gcloud compute ssh "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --command="docker ps --filter name=${container} --format '{{.Status}}'" 2>/dev/null || echo "")
        
        if [[ "${container_status}" == *"Up"* ]]; then
            echo -e "  ${GREEN}✓${NC} Container running: ${container}"
            ((tests_passed++))
        else
            echo -e "  ${RED}✗${NC} Container not running: ${container}"
            ((tests_failed++))
            status="FAIL"
        fi
    done
    
    echo ""
    echo "AppFlowy Containers Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_service_endpoints() {
    log_info "Testing Service Endpoints..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    
    # Get VM external IP
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    if [[ -z "${external_ip}" ]]; then
        echo -e "  ${RED}✗${NC} Cannot get VM external IP"
        return 1
    fi
    
    echo "  Testing endpoints on IP: ${external_ip}"
    
    # Test 1: Nginx proxy
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} Nginx proxy responding (http://${external_ip})"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} Nginx proxy not responding"
        ((tests_failed++))
    fi
    
    # Test 2: AppFlowy API
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}:${APPFLOWY_PORT:-8000}/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} AppFlowy API responding (port ${APPFLOWY_PORT:-8000})"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} AppFlowy API not responding"
        ((tests_failed++))
    fi
    
    # Test 3: GoTrue Auth
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}:9999/health" 2>/dev/null | grep -q "200"; then
        echo -e "  ${GREEN}✓${NC} GoTrue Auth responding (port 9999)"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} GoTrue Auth not responding"
        ((tests_failed++))
    fi
    
    echo ""
    echo "Service Endpoints Tests: ${tests_passed} passed, ${tests_failed} failed - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

test_configuration() {
    log_info "Testing Configuration..."
    
    local status="PASS"
    local tests_passed=0
    local tests_failed=0
    local warnings=0
    
    # Test 1: Check if passwords are configured
    if [[ -n "${POSTGRES_PASSWORD}" ]]; then
        echo -e "  ${GREEN}✓${NC} PostgreSQL password is set"
        ((tests_passed++))
    else
        echo -e "  ${RED}✗${NC} PostgreSQL password not configured"
        ((tests_failed++))
        status="FAIL"
    fi
    
    if [[ -n "${GOTRUE_JWT_SECRET}" ]]; then
        echo -e "  ${GREEN}✓${NC} JWT secret is set"
        ((tests_passed++))
    else
        echo -e "  ${RED}✗${NC} JWT secret not configured"
        ((tests_failed++))
        status="FAIL"
    fi
    
    # Test 2: Google OAuth configuration (warning only)
    if [[ -n "${GOOGLE_CLIENT_ID}" ]] && [[ -n "${GOOGLE_CLIENT_SECRET}" ]]; then
        echo -e "  ${GREEN}✓${NC} Google OAuth is configured"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} Google OAuth not configured (optional)"
        ((warnings++))
    fi
    
    # Test 3: SSH security
    if [[ "${SSH_SOURCE_RANGES}" != "0.0.0.0/0" ]]; then
        echo -e "  ${GREEN}✓${NC} SSH access is restricted"
        ((tests_passed++))
    else
        echo -e "  ${YELLOW}⚠${NC} SSH open to all IPs (security risk)"
        ((warnings++))
    fi
    
    echo ""
    echo "Configuration Tests: ${tests_passed} passed, ${tests_failed} failed, ${warnings} warnings - ${status}"
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

generate_report() {
    local total_tests=$1
    local tests_passed=$2
    local tests_failed=$3
    
    echo ""
    echo "================================================"
    echo "   Test Summary Report"
    echo "================================================"
    echo ""
    echo "Total Tests Run: ${total_tests}"
    echo -e "${GREEN}Passed: ${tests_passed}${NC}"
    echo -e "${RED}Failed: ${tests_failed}${NC}"
    echo ""
    
    if [[ ${tests_failed} -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed successfully!${NC}"
        echo ""
        
        # Get VM external IP for access info
        local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
        
        if [[ -n "${external_ip}" ]]; then
            echo "Access your AppFlowy instance:"
            echo "  Main URL: http://${external_ip}"
            echo "  API: http://${external_ip}:${APPFLOWY_PORT:-8000}"
            echo "  Auth: http://${external_ip}:9999"
            echo ""
            echo "SSH to VM:"
            echo "  gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
        fi
    else
        echo -e "${RED}✗ Some tests failed. Please review and fix the issues.${NC}"
        echo ""
        echo "Common fixes:"
        echo "  1. Run missing setup scripts"
        echo "  2. Check config/env.sh for missing values"
        echo "  3. Ensure GCP project and billing are configured"
        echo "  4. Verify VM is running and accessible"
    fi
}

main() {
    print_test_header
    
    local total_tests=0
    local tests_passed=0
    local tests_failed=0
    
    # Run test suites
    local test_suites=(
        "test_gcp_project"
        "test_vm_instance"
        "test_firewall_rules"
        "test_docker_installation"
        "test_appflowy_containers"
        "test_service_endpoints"
        "test_configuration"
    )
    
    for suite in "${test_suites[@]}"; do
        if ${suite}; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
        ((total_tests++))
        echo ""
    done
    
    # Generate final report
    generate_report ${total_tests} ${tests_passed} ${tests_failed}
    
    # Exit with appropriate code
    exit ${tests_failed}
}

main "$@"