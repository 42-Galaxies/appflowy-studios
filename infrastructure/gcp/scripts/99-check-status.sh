#!/bin/bash

# Quick status check script for AppFlowy Studios deployment
# This script provides a comprehensive status report of the deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   AppFlowy Studios - Status Check     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if VM exists and is running
echo -e "${YELLOW}1. VM Status:${NC}"
VM_STATUS=$(gcloud compute instances describe "${VM_NAME}" \
    --zone="${VM_ZONE}" \
    --project="${PROJECT_ID}" \
    --format="value(status)" 2>/dev/null || echo "NOT_FOUND")

if [[ "${VM_STATUS}" == "RUNNING" ]]; then
    echo -e "   ${GREEN}✓${NC} VM is running"
    
    # Get VM IP
    VM_IP=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    echo -e "   ${GREEN}✓${NC} External IP: ${VM_IP}"
else
    echo -e "   ${RED}✗${NC} VM status: ${VM_STATUS}"
    echo -e "   ${RED}Cannot proceed with further checks${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Service Health:${NC}"

# Check Nginx
if curl -s -o /dev/null -w "%{http_code}" "http://${VM_IP}/health" 2>/dev/null | grep -q "200"; then
    echo -e "   ${GREEN}✓${NC} Nginx proxy (http://${VM_IP})"
else
    echo -e "   ${RED}✗${NC} Nginx proxy not responding"
fi

# Check GoTrue
if curl -s "http://${VM_IP}/auth/health" 2>/dev/null | grep -q "GoTrue"; then
    echo -e "   ${GREEN}✓${NC} GoTrue authentication service"
else
    echo -e "   ${RED}✗${NC} GoTrue not responding"
fi

echo ""
echo -e "${YELLOW}3. Docker Containers:${NC}"

# Check containers on VM
CONTAINERS=$(gcloud compute ssh "${VM_NAME}" \
    --zone="${VM_ZONE}" \
    --project="${PROJECT_ID}" \
    --command="docker ps --format '{{.Names}}|{{.Status}}'" 2>/dev/null || echo "")

if [[ -n "${CONTAINERS}" ]]; then
    while IFS='|' read -r name status; do
        if [[ "${status}" == Up* ]]; then
            echo -e "   ${GREEN}✓${NC} ${name}: ${status}"
        else
            echo -e "   ${RED}✗${NC} ${name}: ${status}"
        fi
    done <<< "${CONTAINERS}"
else
    echo -e "   ${RED}✗${NC} Could not retrieve container status"
fi

echo ""
echo -e "${YELLOW}4. Repository Status:${NC}"

# Check if submodules are initialized
if [ -e "${SCRIPT_DIR}/../../../src/appflowy-backend/.git" ]; then
    echo -e "   ${GREEN}✓${NC} Backend fork (submodule initialized)"
else
    echo -e "   ${YELLOW}!${NC} Backend fork not initialized (run: git submodule update --init)"
fi

if [ -e "${SCRIPT_DIR}/../../../src/appflowy-frontend/.git" ]; then
    echo -e "   ${GREEN}✓${NC} Frontend fork (submodule initialized)"
else
    echo -e "   ${YELLOW}!${NC} Frontend fork not initialized (run: git submodule update --init)"
fi

echo ""
echo -e "${YELLOW}5. Deployment Type:${NC}"

# Check which deployment is active
SSH_CMD="cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml ps --format '{{.Name}}' 2>/dev/null | head -1"
SIMPLIFIED_CHECK=$(gcloud compute ssh "${VM_NAME}" \
    --zone="${VM_ZONE}" \
    --project="${PROJECT_ID}" \
    --command="${SSH_CMD}" 2>/dev/null || echo "")

if [[ -n "${SIMPLIFIED_CHECK}" ]]; then
    echo -e "   ${GREEN}✓${NC} Simplified backend (stable)"
    echo -e "   Services: PostgreSQL, Redis, GoTrue, Nginx"
else
    SSH_CMD="cd /opt/appflowy/appflowy-cloud && docker compose ps --format '{{.Name}}' 2>/dev/null | head -1"
    FULL_CHECK=$(gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="${SSH_CMD}" 2>/dev/null || echo "")
    
    if [[ -n "${FULL_CHECK}" ]]; then
        echo -e "   ${YELLOW}!${NC} Full AppFlowy Cloud deployment"
    else
        echo -e "   ${RED}✗${NC} No deployment detected"
    fi
fi

echo ""
echo -e "${YELLOW}6. Next Steps:${NC}"

# Check what needs to be done
NEXT_STEPS=()

# Check domain
if ! nslookup workspace.42galaxies.studio 2>/dev/null | grep -q "${VM_IP}"; then
    NEXT_STEPS+=("Configure DNS: workspace.42galaxies.studio → ${VM_IP}")
fi

# Check SSL
if ! curl -s -o /dev/null -w "%{http_code}" "https://${VM_IP}" 2>/dev/null | grep -q "200"; then
    NEXT_STEPS+=("Configure SSL/TLS with Let's Encrypt")
fi

# Check frontend
if ! curl -s "http://${VM_IP}" 2>/dev/null | grep -q "AppFlowy"; then
    NEXT_STEPS+=("Deploy AppFlowy frontend from fork")
fi

if [ ${#NEXT_STEPS[@]} -eq 0 ]; then
    echo -e "   ${GREEN}✓${NC} All basic components deployed!"
else
    for step in "${NEXT_STEPS[@]}"; do
        echo -e "   ${YELLOW}→${NC} ${step}"
    done
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Access URLs:${NC}"
echo -e "  Main:      http://${VM_IP}"
echo -e "  Health:    http://${VM_IP}/health"
echo -e "  Auth:      http://${VM_IP}/auth/health"
echo ""
echo -e "${BLUE}Management:${NC}"
echo -e "  SSH:       gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
echo -e "  Logs:      ./scripts/view-logs.sh"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo -e "  Tracking:  docs/PROJECT_TRACKING.md"
echo -e "  Roadmap:   docs/roadmap/roadmap.md"
echo -e "${BLUE}========================================${NC}"