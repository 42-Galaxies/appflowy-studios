#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

# Paths
PROJECT_ROOT="/run/media/jb/Main-Data/projects/tools/appflowy-studios"
BACKEND_PATH="${PROJECT_ROOT}/src/appflowy-backend"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Set project explicitly
    gcloud config set project "${PROJECT_ID}" 2>/dev/null
    
    # Check VM is running
    local vm_status=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "${vm_status}" != "RUNNING" ]]; then
        log_error "VM '${VM_NAME}' is not running"
        return 1
    fi
    
    # Check submodule exists (for submodules, .git is a file not a directory)
    if [ ! -e "${BACKEND_PATH}/.git" ]; then
        log_error "Backend submodule not found at ${BACKEND_PATH}"
        log_info "Run: git submodule update --init --recursive"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

prepare_deployment_files() {
    log_info "Preparing deployment files from fork..."
    
    cd "${BACKEND_PATH}"
    
    # Get VM external IP
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    # Create custom env file based on deploy.env
    log_info "Creating deployment configuration..."
    
    # First copy the original deploy.env as base
    cp deploy.env deploy.env.custom
    
    # Then append our custom values
    cat >> deploy.env.custom << EOF

# Custom configuration for our deployment
# Required base URLs (these were missing and causing failures)
SCHEME=http
FQDN=${vm_ip}
APPFLOWY_BASE_URL=http://${vm_ip}
APPFLOWY_WEBSOCKET_BASE_URL=ws://${vm_ip}:8001

# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=appflowy
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=appflowy
DATABASE_URL=postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379

# AppFlowy Cloud Config
APPFLOWY_CLOUD_VERSION=0.6.6
APPFLOWY_ENVIRONMENT=production
APPFLOWY_DATABASE_URL=postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy
APPFLOWY_ACCESS_CONTROL=true
APPFLOWY_DATABASE_MAX_CONNECTIONS=40
APPFLOWY_WEB_URL=http://${vm_ip}
APPFLOWY_SERVER_PORT=8000
APPFLOWY_WS_SERVER_PORT=8001

# GoTrue / Auth
GOTRUE_SITE_URL=http://${vm_ip}
GOTRUE_URI_ALLOW_LIST=http://${vm_ip}
GOTRUE_JWT_SECRET=${GOTRUE_JWT_SECRET}
GOTRUE_JWT_EXP=3600
GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated
GOTRUE_DB_DATABASE_URL=postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy?search_path=auth

# Google OAuth (if configured)
GOTRUE_EXTERNAL_GOOGLE_ENABLED=${GOOGLE_OAUTH_ENABLED:-false}
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOTRUE_EXTERNAL_GOOGLE_SECRET=${GOOGLE_CLIENT_SECRET}
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=http://${vm_ip}/auth/callback

# Email
GOTRUE_MAILER_AUTOCONFIRM=${MAILER_AUTOCONFIRM:-true}
GOTRUE_DISABLE_SIGNUP=${DISABLE_SIGNUP:-false}
GOTRUE_SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL:-admin@example.com}
GOTRUE_SMTP_HOST=${SMTP_HOST}
GOTRUE_SMTP_PORT=${SMTP_PORT:-587}
GOTRUE_SMTP_USER=${SMTP_USER}
GOTRUE_SMTP_PASS=${SMTP_PASS}

# Admin
APPFLOWY_ADMIN_EMAIL=admin@42galaxies.studio
APPFLOWY_ADMIN_PASSWORD=changeme123

# S3 Storage (optional)
APPFLOWY_S3_USE_MINIO=true
APPFLOWY_S3_MINIO_HOST=minio
APPFLOWY_S3_MINIO_PORT=9000
APPFLOWY_S3_ACCESS_KEY_ID=minioadmin
APPFLOWY_S3_SECRET_ACCESS_KEY=minioadmin
APPFLOWY_S3_BUCKET=appflowy
APPFLOWY_S3_REGION=us-east-1
EOF
    
    # Create a custom docker-compose that uses our configuration
    log_info "Creating custom docker-compose configuration..."
    
    # Copy the original docker-compose and modify it
    cp docker-compose.yml docker-compose.custom.yml
    
    # Update the env file reference in docker-compose.custom.yml
    sed -i 's/deploy.env/deploy.env.custom/g' docker-compose.custom.yml
    
    log_success "Deployment files prepared"
    return 0
}

copy_to_vm() {
    log_info "Copying AppFlowy Cloud fork to VM..."
    
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    # Create directory on VM with proper permissions
    gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="mkdir -p /opt/appflowy/appflowy-cloud && sudo chown -R \$(whoami):\$(whoami) /opt/appflowy"
    
    # Copy entire backend directory to VM
    log_info "Copying backend files to VM (this may take a few minutes)..."
    
    cd "${BACKEND_PATH}"
    
    # Create a tarball excluding .git to reduce size
    tar czf /tmp/appflowy-cloud.tar.gz \
        --exclude='.git' \
        --exclude='target' \
        --exclude='node_modules' \
        .
    
    # Copy tarball to VM
    gcloud compute scp /tmp/appflowy-cloud.tar.gz \
        "${vm_name}:/tmp/" \
        --zone="${zone}" \
        --project="${PROJECT_ID}"
    
    # Extract on VM
    gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/appflowy-cloud && tar xzf /tmp/appflowy-cloud.tar.gz && rm /tmp/appflowy-cloud.tar.gz"
    
    # Clean up local tarball
    rm /tmp/appflowy-cloud.tar.gz
    
    log_success "Files copied to VM"
    return 0
}

deploy_on_vm() {
    log_info "Deploying AppFlowy Cloud on VM..."
    
    local deploy_script='
cd /opt/appflowy/appflowy-cloud

# Stop existing services
echo "Stopping existing services..."
cd /opt/appflowy/config
docker compose -f docker-compose-simplified.yml down 2>/dev/null || true
docker compose down 2>/dev/null || true

# Go back to AppFlowy Cloud directory
cd /opt/appflowy/appflowy-cloud

# Pull images
echo "Pulling Docker images..."
docker compose -f docker-compose.custom.yml pull

# Start services
echo "Starting AppFlowy Cloud services..."
docker compose -f docker-compose.custom.yml up -d

# Wait for services
echo "Waiting for services to start..."
sleep 30

# Show status
echo "Service status:"
docker compose -f docker-compose.custom.yml ps

# Show logs
echo ""
echo "Recent logs:"
docker compose -f docker-compose.custom.yml logs --tail=20
'
    
    gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="${deploy_script}"
    
    log_success "AppFlowy Cloud deployed from fork"
    return 0
}

verify_deployment() {
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    log_info "Verifying deployment..."
    
    echo ""
    echo "Testing endpoints:"
    
    # Test health endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://${vm_ip}/health" 2>/dev/null | grep -q "200"; then
        echo "  ✓ Nginx proxy (http://${vm_ip})"
    else
        echo "  ✗ Nginx proxy not responding"
    fi
    
    # Test AppFlowy Cloud API
    if curl -s -o /dev/null -w "%{http_code}" "http://${vm_ip}:8000/api/health" 2>/dev/null | grep -q "200\|404"; then
        echo "  ✓ AppFlowy Cloud API (http://${vm_ip}:8000)"
    else
        echo "  ✗ AppFlowy Cloud API not responding"
    fi
    
    # Check containers on VM
    echo ""
    echo "Container status:"
    gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/appflowy-cloud && docker compose -f docker-compose.custom.yml ps --format 'table {{.Name}}\t{{.Status}}'"
    
    return 0
}

main() {
    log_info "Starting deployment of AppFlowy Cloud from fork..."
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Prepare deployment files
    prepare_deployment_files || exit 1
    
    # Copy to VM
    copy_to_vm || exit 1
    
    # Deploy on VM
    deploy_on_vm || exit 1
    
    # Verify
    sleep 10
    verify_deployment
    
    # Show access information
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    echo ""
    echo "============================================"
    log_success "AppFlowy Cloud deployed from fork!"
    echo "============================================"
    echo ""
    echo "🎯 Your fork is now running on the server!"
    echo ""
    echo "Access URLs:"
    echo "  Main: http://${vm_ip}"
    echo "  API: http://${vm_ip}:8000"
    echo "  WebSocket: http://${vm_ip}:8001"
    echo "  Admin: http://${vm_ip}:3000"
    echo ""
    echo "VM Management:"
    echo "  SSH: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
    echo "  Logs: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/appflowy-cloud && docker compose -f docker-compose.custom.yml logs -f'"
    echo ""
    echo "Fork Repository:"
    echo "  https://github.com/42-Galaxies/AppFlowy-Cloud"
    echo ""
    echo "To make changes:"
    echo "  1. Edit code in src/appflowy-backend/"
    echo "  2. Commit and push to fork"
    echo "  3. Run this script again to deploy"
    echo ""
}

main "$@"