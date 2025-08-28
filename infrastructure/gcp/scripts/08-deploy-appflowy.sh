#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/../config/env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
        log_info "These should be secure random values"
        return 1
    fi
    
    if [[ -z "${GOOGLE_CLIENT_ID}" ]] || [[ -z "${GOOGLE_CLIENT_SECRET}" ]]; then
        log_warning "Google OAuth credentials not configured"
        log_warning "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET should be set for authentication"
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

create_docker_compose_file() {
    log_info "Creating docker-compose.yml file..."
    
    local compose_file="${DOCKER_DIR}/docker-compose.yml"
    mkdir -p "${DOCKER_DIR}"
    
    cat > "${compose_file}" << 'EOF'
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appflowy"]
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
      GOTRUE_SITE_URL: ${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}
      GOTRUE_URI_ALLOW_LIST: ${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}
      GOTRUE_JWT_SECRET: ${GOTRUE_JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: ${GOOGLE_OAUTH_ENABLED:-false}
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOTRUE_EXTERNAL_GOOGLE_SECRET: ${GOOGLE_CLIENT_SECRET}
      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: ${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}/auth/callback
      GOTRUE_DISABLE_SIGNUP: ${DISABLE_SIGNUP:-false}
      GOTRUE_EXTERNAL_EMAIL_ENABLED: true
      GOTRUE_MAILER_AUTOCONFIRM: ${MAILER_AUTOCONFIRM:-true}
      GOTRUE_SMTP_ADMIN_EMAIL: ${SMTP_ADMIN_EMAIL}
      GOTRUE_SMTP_HOST: ${SMTP_HOST}
      GOTRUE_SMTP_PORT: ${SMTP_PORT:-587}
      GOTRUE_SMTP_USER: ${SMTP_USER}
      GOTRUE_SMTP_PASS: ${SMTP_PASS}
      GOTRUE_SMTP_SENDER_NAME: ${SMTP_SENDER_NAME:-AppFlowy}
      API_EXTERNAL_URL: ${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}
    ports:
      - "9999:9999"
    networks:
      - appflowy-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9999/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Simplified backend approach - serving static AppFlowy web app
  appflowy-web:
    image: nginx:alpine
    container_name: appflowy-web
    restart: unless-stopped
    depends_on:
      - gotrue
    environment:
      - APPFLOWY_GOTRUE_URL=http://gotrue:9999
      - APPFLOWY_WEB_URL=${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}
    ports:
      - "${APPFLOWY_PORT:-8000}:80"
    volumes:
      - ./web:/usr/share/nginx/html:ro
      - ./nginx-web.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - appflowy-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
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
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: appflowy-nginx
    restart: unless-stopped
    depends_on:
      - appflowy-web
      - gotrue
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_cache:/var/cache/nginx
    networks:
      - appflowy-network

networks:
  appflowy-network:
    driver: bridge

volumes:
  postgres_data:
  appflowy_data:
  redis_data:
  nginx_cache:
EOF
    
    log_success "docker-compose.yml created"
    return 0
}

create_env_file() {
    log_info "Creating environment configuration file..."
    
    local env_file="${DOCKER_DIR}/.env"
    local env_template="${DOCKER_DIR}/.env.template"
    
    # Create template for reference
    cat > "${env_template}" << 'EOF'
# PostgreSQL Configuration
POSTGRES_PASSWORD=your_secure_password_here

# GoTrue JWT Configuration
GOTRUE_JWT_SECRET=your_secure_jwt_secret_here

# Site Configuration
SITE_URL=http://your-domain.com
APPFLOWY_PORT=8000
APPFLOWY_WS_PORT=8001

# Google OAuth Configuration (optional)
GOOGLE_OAUTH_ENABLED=true
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Email Configuration (optional)
MAILER_AUTOCONFIRM=false
DISABLE_SIGNUP=false
SMTP_ADMIN_EMAIL=admin@your-domain.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_SENDER_NAME=AppFlowy Workspace

# S3 Storage Configuration (optional - for file storage)
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=appflowy-data
S3_REGION=us-central1
S3_ENDPOINT=

# SSH Access Configuration
SSH_SOURCE_RANGES=0.0.0.0/0
EOF
    
    # Create actual .env file with configured values
    cat > "${env_file}" << EOF
# PostgreSQL Configuration
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# GoTrue JWT Configuration
GOTRUE_JWT_SECRET=${GOTRUE_JWT_SECRET}

# Site Configuration
SITE_URL=${SITE_URL:-http://$(get_vm_external_ip)}
APPFLOWY_WEB_URL=${APPFLOWY_WEB_URL:-http://$(get_vm_external_ip)}
APPFLOWY_PORT=${APPFLOWY_PORT:-8000}
APPFLOWY_WS_PORT=${APPFLOWY_WS_PORT:-8001}

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

# S3 Storage Configuration
S3_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID}
S3_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY}
S3_BUCKET=${S3_BUCKET:-appflowy-data}
S3_REGION=${S3_REGION:-us-central1}
S3_ENDPOINT=${S3_ENDPOINT}
EOF
    
    log_success "Environment configuration created"
    return 0
}

create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    local nginx_conf="${DOCKER_DIR}/nginx.conf"
    
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

    upstream appflowy_web {
        server appflowy-web:80;
    }

    upstream gotrue_backend {
        server gotrue:9999;
    }

    server {
        listen 80;
        server_name _;
        
        client_max_body_size 50M;

        # Main AppFlowy web application
        location / {
            proxy_pass http://appflowy_web;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Authentication service
        location /auth/ {
            proxy_pass http://gotrue_backend/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # API endpoints (if needed for future backend services)
        location /api/ {
            proxy_pass http://gotrue_backend/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    log_success "Nginx configuration created"
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

create_web_nginx_config() {
    log_info "Creating web nginx configuration..."
    
    local web_nginx_conf="${DOCKER_DIR}/nginx-web.conf"
    
    cat > "${web_nginx_conf}" << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/json application/javascript;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    location / {
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Handle client-side routing
    location ~* ^.+\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public";
    }
}
EOF
    
    log_success "Web nginx configuration created"
    return 0
}

create_simple_web_app() {
    log_info "Creating simple AppFlowy web application..."
    
    local web_dir="${DOCKER_DIR}/web"
    mkdir -p "${web_dir}"
    
    # Create a simple index.html for AppFlowy
    cat > "${web_dir}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AppFlowy Workspace</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .container {
            background: white;
            padding: 3rem;
            border-radius: 10px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
            width: 90%;
        }
        
        .logo {
            width: 80px;
            height: 80px;
            background: #667eea;
            border-radius: 20px;
            margin: 0 auto 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 2rem;
            font-weight: bold;
        }
        
        h1 {
            color: #2d3748;
            margin-bottom: 1rem;
            font-size: 2.5rem;
        }
        
        p {
            color: #718096;
            margin-bottom: 2rem;
            font-size: 1.1rem;
        }
        
        .status {
            background: #f7fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 1rem;
            margin-bottom: 2rem;
        }
        
        .status-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.5rem 0;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .status-item:last-child {
            border-bottom: none;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #48bb78;
        }
        
        .btn {
            background: #667eea;
            color: white;
            padding: 0.75rem 2rem;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            font-size: 1rem;
            transition: background 0.3s;
        }
        
        .btn:hover {
            background: #5a67d8;
        }
        
        .footer {
            margin-top: 2rem;
            padding-top: 1rem;
            border-top: 1px solid #e2e8f0;
            color: #718096;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">AF</div>
        <h1>AppFlowy Workspace</h1>
        <p>Your collaborative workspace is ready and running!</p>
        
        <div class="status">
            <div class="status-item">
                <span>Web Server</span>
                <div class="status-indicator"></div>
            </div>
            <div class="status-item">
                <span>Authentication</span>
                <div class="status-indicator" id="auth-status"></div>
            </div>
            <div class="status-item">
                <span>Database</span>
                <div class="status-indicator" id="db-status"></div>
            </div>
        </div>
        
        <a href="/auth/signup" class="btn">Get Started</a>
        
        <div class="footer">
            <p>Powered by AppFlowy • PostgreSQL • GoTrue</p>
        </div>
    </div>
    
    <script>
        // Simple health checks
        async function checkHealth() {
            try {
                const authResponse = await fetch('/auth/health');
                const authStatus = document.getElementById('auth-status');
                if (authResponse.ok) {
                    authStatus.style.background = '#48bb78';
                } else {
                    authStatus.style.background = '#f56565';
                }
            } catch (e) {
                document.getElementById('auth-status').style.background = '#f56565';
            }
        }
        
        // Check health on load
        checkHealth();
        setInterval(checkHealth, 30000); // Check every 30 seconds
    </script>
</body>
</html>
EOF
    
    log_success "Simple web application created"
    return 0
}

get_vm_external_ip() {
    gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "localhost"
}

deploy_to_vm() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Deploying AppFlowy to VM '${vm_name}'..."
    
    # Copy docker files to VM
    log_info "Copying Docker configuration files to VM..."
    
    # Create remote directory
    gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="mkdir -p /opt/appflowy/config"
    
    # Copy files
    gcloud compute scp \
        "${DOCKER_DIR}/docker-compose.yml" \
        "${DOCKER_DIR}/.env" \
        "${DOCKER_DIR}/nginx.conf" \
        "${DOCKER_DIR}/nginx-web.conf" \
        "${DOCKER_DIR}/init-db.sql" \
        "${vm_name}:/opt/appflowy/config/" \
        --zone="${zone}" \
        --project="${PROJECT_ID}"
    
    # Copy web directory
    if [[ -d "${DOCKER_DIR}/web" ]]; then
        gcloud compute scp \
            --recurse \
            "${DOCKER_DIR}/web" \
            "${vm_name}:/opt/appflowy/config/" \
            --zone="${zone}" \
            --project="${PROJECT_ID}"
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to copy files to VM"
        return 1
    fi
    
    log_success "Files copied to VM"
    
    # Start Docker Compose
    log_info "Starting Docker Compose stack..."
    
    local deploy_script='
cd /opt/appflowy/config

# Pull latest images
echo "Pulling Docker images..."
docker compose pull

# Start services
echo "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 30

# Show service status
docker compose ps

# Show logs tail
echo ""
echo "Recent logs:"
docker compose logs --tail=20
'
    
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="${deploy_script}"; then
        log_success "AppFlowy stack deployed successfully"
    else
        log_error "Failed to deploy AppFlowy stack"
        return 1
    fi
    
    return 0
}

verify_deployment() {
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    local external_ip=$(get_vm_external_ip)
    
    log_info "Verifying AppFlowy deployment..."
    
    # Check container status
    log_info "Checking container status..."
    
    local container_status=$(gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="cd /opt/appflowy/config && docker compose ps --format json" 2>/dev/null)
    
    # Check health endpoints
    log_info "Checking health endpoints..."
    
    echo ""
    echo "Service Status:"
    
    # Check Nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}/health" | grep -q "200"; then
        echo "  ✓ Nginx proxy (http://${external_ip})"
    else
        echo "  ✗ Nginx proxy"
    fi
    
    # Check AppFlowy Web App
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}:${APPFLOWY_PORT:-8000}/health" | grep -q "200"; then
        echo "  ✓ AppFlowy Web App (http://${external_ip}:${APPFLOWY_PORT:-8000})"
    else
        echo "  ✗ AppFlowy Web App"
    fi
    
    # Check GoTrue
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_ip}:9999/health" | grep -q "200"; then
        echo "  ✓ GoTrue Auth (http://${external_ip}:9999)"
    else
        echo "  ✗ GoTrue Auth"
    fi
    
    echo ""
    log_success "Deployment verification complete"
    
    return 0
}

main() {
    log_info "Starting AppFlowy deployment process..."
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Create Docker configuration files
    create_docker_compose_file || exit 1
    create_env_file || exit 1
    create_nginx_config || exit 1
    create_web_nginx_config || exit 1
    create_init_db_script || exit 1
    create_simple_web_app || exit 1
    
    # Deploy to VM
    deploy_to_vm || exit 1
    
    # Verify deployment
    sleep 10
    verify_deployment
    
    # Display access information
    local external_ip=$(get_vm_external_ip)
    
    echo ""
    echo "============================================"
    log_success "AppFlowy deployment completed successfully!"
    echo "============================================"
    echo ""
    echo "Access Information:"
    echo "  Main URL: http://${external_ip}"
    echo "  AppFlowy Web App: http://${external_ip}:${APPFLOWY_PORT:-8000}"
    echo "  Auth Service: http://${external_ip}:9999"
    echo ""
    echo "VM Management:"
    echo "  SSH to VM: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}"
    echo "  View logs: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose logs -f'"
    echo "  Stop services: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose down'"
    echo "  Start services: gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE} --command='cd /opt/appflowy/config && docker compose up -d'"
    echo ""
    
    if [[ -z "${GOOGLE_CLIENT_ID}" ]] || [[ -z "${GOOGLE_CLIENT_SECRET}" ]]; then
        log_warning "Google OAuth is not configured. Users won't be able to sign in with Google Workspace."
        log_warning "To enable Google OAuth, set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in config/env.sh"
    fi
    
    if [[ -z "${SITE_URL}" ]]; then
        log_warning "SITE_URL is not configured. Using IP address: http://${external_ip}"
        log_warning "For production, configure a domain and set SITE_URL in config/env.sh"
    fi
}

main "$@"