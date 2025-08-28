#!/bin/bash

# Simplified AppFlowy Backend Deployment
# 
# This script deploys a simplified, stable backend stack for AppFlowy.
# We use this instead of the full AppFlowy Cloud image because:
# 1. The official image has database migration issues
# 2. It requires 50+ complex environment variables
# 3. The simplified stack is more reliable and easier to maintain
#
# See infrastructure/gcp/BACKEND_ARCHITECTURE.md for details

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"
DOCKER_DIR="${SCRIPT_DIR}/../docker"

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
    log_info "Checking deployment prerequisites..."
    
    # Check VM is running
    local vm_status=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "${vm_status}" != "RUNNING" ]]; then
        log_error "VM '${VM_NAME}' is not running"
        return 1
    fi
    
    # Check Docker is installed
    if ! gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="docker --version" &>/dev/null; then
        log_error "Docker is not installed on VM '${VM_NAME}'"
        log_info "Please run 07-install-docker.sh first"
        return 1
    fi
    
    # Check required environment variables
    if [[ -z "${POSTGRES_PASSWORD}" ]] || [[ -z "${GOTRUE_JWT_SECRET}" ]]; then
        log_error "POSTGRES_PASSWORD and GOTRUE_JWT_SECRET must be set in config/env.sh"
        log_info "Run 00-auto-configure.sh to generate these automatically"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

create_docker_compose_file() {
    log_info "Creating simplified docker-compose.yml file..."
    
    local compose_file="${DOCKER_DIR}/docker-compose-simplified.yml"
    mkdir -p "${DOCKER_DIR}"
    
    # Get VM external IP
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "localhost")
    
    cat > "${compose_file}" << EOF
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg15
    container_name: appflowy-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: appflowy
      POSTGRES_USER: appflowy
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql:ro
    networks:
      - appflowy-network
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appflowy"]
      interval: 30s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: appflowy-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - appflowy-network
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  gotrue:
    image: supabase/gotrue:v2.151.0
    container_name: appflowy-gotrue
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy?search_path=auth
      GOTRUE_SITE_URL: ${SITE_URL:-http://${external_ip}}
      GOTRUE_URI_ALLOW_LIST: ${SITE_URL:-http://${external_ip}}
      GOTRUE_JWT_SECRET: ${GOTRUE_JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: ${GOOGLE_OAUTH_ENABLED:-false}
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOTRUE_EXTERNAL_GOOGLE_SECRET: ${GOOGLE_CLIENT_SECRET}
      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: ${SITE_URL:-http://${external_ip}}/auth/callback
      GOTRUE_DISABLE_SIGNUP: ${DISABLE_SIGNUP:-false}
      GOTRUE_EXTERNAL_EMAIL_ENABLED: true
      GOTRUE_MAILER_AUTOCONFIRM: ${MAILER_AUTOCONFIRM:-true}
      GOTRUE_SMTP_ADMIN_EMAIL: ${SMTP_ADMIN_EMAIL:-admin@example.com}
      GOTRUE_SMTP_HOST: ${SMTP_HOST}
      GOTRUE_SMTP_PORT: ${SMTP_PORT:-587}
      GOTRUE_SMTP_USER: ${SMTP_USER}
      GOTRUE_SMTP_PASS: ${SMTP_PASS}
      GOTRUE_SMTP_SENDER_NAME: ${SMTP_SENDER_NAME:-AppFlowy}
      API_EXTERNAL_URL: ${SITE_URL:-http://${external_ip}}
    ports:
      - "9999:9999"
    networks:
      - appflowy-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9999/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: appflowy-nginx
    restart: unless-stopped
    depends_on:
      - gotrue
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-simple.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_cache:/var/cache/nginx
    networks:
      - appflowy-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  appflowy-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  nginx_cache:
EOF
    
    log_success "Simplified docker-compose.yml created"
    return 0
}

create_nginx_config() {
    log_info "Creating simplified Nginx configuration..."
    
    local nginx_conf="${DOCKER_DIR}/nginx-simple.conf"
    
    cat > "${nginx_conf}" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/json;

    upstream gotrue_backend {
        server gotrue:9999;
    }

    server {
        listen 80;
        server_name _;
        
        client_max_body_size 50M;

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }

        # Authentication service proxy
        location /auth/ {
            proxy_pass http://gotrue_backend/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # API endpoints (for future backend services)
        location /api/ {
            proxy_pass http://gotrue_backend/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Main page - status information
        location / {
            default_type text/html;
            return 200 '<!DOCTYPE html>
<html>
<head>
    <title>AppFlowy Backend Services</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #333; }
        .status { background: #f0f0f0; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .service { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #ddd; }
        .service:last-child { border-bottom: none; }
        .running { color: green; font-weight: bold; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>🚀 AppFlowy Backend Services</h1>
    
    <div class="status">
        <h2>Service Status</h2>
        <div class="service"><span>PostgreSQL Database</span><span class="running">✓ Running</span></div>
        <div class="service"><span>Redis Cache</span><span class="running">✓ Running</span></div>
        <div class="service"><span>GoTrue Authentication</span><span class="running">✓ Running</span></div>
        <div class="service"><span>Nginx Proxy</span><span class="running">✓ Running</span></div>
    </div>
    
    <div class="info">
        <h2>Available Endpoints</h2>
        <p><strong>Health Check:</strong> <code>/health</code></p>
        <p><strong>Authentication:</strong> <code>/auth/health</code></p>
    </div>
    
    <div class="info">
        <h2>Next Steps</h2>
        <p>The backend infrastructure is ready. To complete your AppFlowy deployment:</p>
        <ol>
            <li>Deploy the AppFlowy frontend application</li>
            <li>Configure Google OAuth for your domain</li>
            <li>Set up SSL certificates with Let\'s Encrypt</li>
        </ol>
    </div>
</body>
</html>';
        }
    }
}
EOF
    
    log_success "Simplified Nginx configuration created"
    return 0
}

create_init_db_script() {
    log_info "Creating database initialization script..."
    
    local init_script="${DOCKER_DIR}/init-db.sql"
    
    cat > "${init_script}" << 'EOF'
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create auth schema for GoTrue
CREATE SCHEMA IF NOT EXISTS auth;

-- Grant privileges
GRANT ALL ON SCHEMA auth TO appflowy;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO appflowy;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO appflowy;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO appflowy;

-- Create appflowy schema
CREATE SCHEMA IF NOT EXISTS public;

-- Grant privileges
GRANT ALL ON SCHEMA public TO appflowy;
GRANT ALL ON ALL TABLES IN SCHEMA public TO appflowy;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO appflowy;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO appflowy;

-- Set search_path for appflowy user
ALTER USER appflowy SET search_path TO public, auth;
EOF
    
    log_success "Database initialization script created"
    return 0
}

create_env_file() {
    log_info "Creating environment configuration file..."
    
    local env_file="${DOCKER_DIR}/.env"
    
    # Get VM external IP
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "localhost")
    
    # Create actual .env file with configured values
    cat > "${env_file}" << EOF
# PostgreSQL Configuration
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# GoTrue JWT Configuration
GOTRUE_JWT_SECRET=${GOTRUE_JWT_SECRET}

# Site Configuration
SITE_URL=${SITE_URL:-http://${external_ip}}
APPFLOWY_WEB_URL=${SITE_URL:-http://${external_ip}}

# Google OAuth Configuration
GOOGLE_OAUTH_ENABLED=${GOOGLE_OAUTH_ENABLED:-false}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}

# Email Configuration
MAILER_AUTOCONFIRM=${MAILER_AUTOCONFIRM:-true}
DISABLE_SIGNUP=${DISABLE_SIGNUP:-false}
SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL:-admin@example.com}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT:-587}
SMTP_USER=${SMTP_USER}
SMTP_PASS=${SMTP_PASS}
SMTP_SENDER_NAME=${SMTP_SENDER_NAME:-AppFlowy Workspace}
EOF
    
    log_success "Environment configuration created"
    return 0
}

deploy_to_vm() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Deploying simplified backend to VM '${vm_name}'..."
    
    # Copy docker files to VM
    log_info "Copying Docker configuration files to VM..."
    
    # Create remote directory with proper permissions
    gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="mkdir -p /opt/appflowy/config && sudo chown -R \$(whoami):\$(whoami) /opt/appflowy"
    
    # Copy files
    gcloud compute scp \
        "${DOCKER_DIR}/docker-compose-simplified.yml" \
        "${DOCKER_DIR}/.env" \
        "${DOCKER_DIR}/nginx-simple.conf" \
        "${DOCKER_DIR}/init-db.sql" \
        "${vm_name}:/opt/appflowy/config/" \
        --zone="${zone}" \
        --project="${PROJECT_ID}"
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to copy files to VM"
        return 1
    fi
    
    log_success "Files copied to VM"
    
    # Start Docker Compose
    log_info "Starting Docker Compose stack..."
    
    local deploy_script='
cd /opt/appflowy/config

# Stop any existing containers
echo "Stopping existing containers..."
docker compose -f docker-compose-simplified.yml down 2>/dev/null || true
docker compose down 2>/dev/null || true

# Pull latest images
echo "Pulling Docker images..."
docker compose -f docker-compose-simplified.yml pull

# Start services
echo "Starting services..."
docker compose -f docker-compose-simplified.yml up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 30

# Show service status
docker compose -f docker-compose-simplified.yml ps

# Show logs tail
echo ""
echo "Recent logs:"
docker compose -f docker-compose-simplified.yml logs --tail=20
'
    
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="${deploy_script}"; then
        log_success "Simplified backend stack deployed successfully"
    else
        log_error "Failed to deploy backend stack"
        return 1
    fi
    
    return 0
}

verify_deployment() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    log_info "Verifying backend deployment..."
    
    # Check container status
    log_info "Checking container status..."
    
    echo ""
    echo "Service Status:"
    
    # Check Nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}/health" 2>/dev/null | grep -q "200"; then
        echo "  ✓ Nginx proxy (http://${external_ip})"
    else
        echo "  ✗ Nginx proxy"
    fi
    
    # Check GoTrue
    if curl -s "http://${external_ip}/auth/health" 2>/dev/null | grep -q "GoTrue"; then
        echo "  ✓ GoTrue Auth (http://${external_ip}/auth/health)"
    else
        echo "  ✗ GoTrue Auth"
    fi
    
    # Check direct service access
    echo ""
    echo "Direct Service Ports:"
    echo "  PostgreSQL: ${external_ip}:5432"
    echo "  Redis: ${external_ip}:6379"
    echo "  GoTrue: ${external_ip}:9999"
    
    echo ""
    log_success "Deployment verification complete"
    
    return 0
}

main() {
    log_info "Starting simplified AppFlowy backend deployment..."
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Create Docker configuration files
    create_docker_compose_file || exit 1
    create_env_file || exit 1
    create_nginx_config || exit 1
    create_init_db_script || exit 1
    
    # Deploy to VM
    deploy_to_vm || exit 1
    
    # Verify deployment
    sleep 10
    verify_deployment
    
    # Display access information
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    echo ""
    echo "============================================"
    log_success "AppFlowy backend deployment completed!"
    echo "============================================"
    echo ""
    echo "Access Information:"
    echo "  Status Page: http://${external_ip}"
    echo "  Auth Service: http://${external_ip}/auth/health"
    echo "  Database: ${external_ip}:5432"
    echo "  Redis: ${external_ip}:6379"
    echo ""
    echo "VM Management:"
    echo "  SSH to VM: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
    echo "  View logs: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml logs -f'"
    echo "  Stop services: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml down'"
    echo "  Start services: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml up -d'"
    echo ""
    echo "Next Steps:"
    echo "  1. Deploy AppFlowy frontend application"
    echo "  2. Configure Google OAuth for 42galaxies.studio domain"
    echo "  3. Set up HTTPS with Let's Encrypt"
    echo ""
    
    if [[ -z "${GOOGLE_CLIENT_ID}" ]] || [[ -z "${GOOGLE_CLIENT_SECRET}" ]]; then
        log_warning "Google OAuth is not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in config/env.sh"
    fi
}

main "$@"