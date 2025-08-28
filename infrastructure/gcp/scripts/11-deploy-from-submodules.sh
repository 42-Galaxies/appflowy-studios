#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

# Paths to submodules
PROJECT_ROOT="${SCRIPT_DIR}/../../.."
BACKEND_PATH="${PROJECT_ROOT}/src/appflowy-backend"
FRONTEND_PATH="${PROJECT_ROOT}/src/appflowy-frontend"

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

check_submodules() {
    log_info "Checking if submodules are initialized..."
    
    if [ ! -d "${BACKEND_PATH}/.git" ]; then
        log_error "Backend submodule not found at ${BACKEND_PATH}"
        log_info "Run setup-submodules.sh first"
        return 1
    fi
    
    if [ ! -d "${FRONTEND_PATH}/.git" ]; then
        log_error "Frontend submodule not found at ${FRONTEND_PATH}"
        log_info "Run setup-submodules.sh first"
        return 1
    fi
    
    log_success "Submodules found"
    return 0
}

build_backend_image() {
    log_info "Building backend Docker image from submodule..."
    
    cd "${BACKEND_PATH}"
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        log_warning "No Dockerfile found in backend, creating one..."
        cat > Dockerfile << 'EOF'
FROM rust:1.70 as builder

WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/appflowy_cloud /usr/local/bin/
EXPOSE 8000
CMD ["appflowy_cloud"]
EOF
    fi
    
    # Build the image
    local image_tag="appflowy-backend:custom"
    log_info "Building Docker image: ${image_tag}"
    
    if docker build -t "${image_tag}" .; then
        log_success "Backend image built successfully"
    else
        log_error "Failed to build backend image"
        return 1
    fi
    
    cd "${SCRIPT_DIR}"
    return 0
}

build_frontend_image() {
    log_info "Building frontend Docker image from submodule..."
    
    cd "${FRONTEND_PATH}"
    
    # Check for web build
    if [ -d "appflowy_flutter" ]; then
        cd appflowy_flutter
    elif [ -d "frontend" ]; then
        cd frontend
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        log_warning "No Dockerfile found in frontend, creating one..."
        cat > Dockerfile << 'EOF'
FROM node:18-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
    fi
    
    # Build the image
    local image_tag="appflowy-frontend:custom"
    log_info "Building Docker image: ${image_tag}"
    
    if docker build -t "${image_tag}" .; then
        log_success "Frontend image built successfully"
    else
        log_error "Failed to build frontend image"
        return 1
    fi
    
    cd "${SCRIPT_DIR}"
    return 0
}

push_images_to_vm() {
    log_info "Pushing images to VM..."
    
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    if [ -z "${vm_ip}" ]; then
        log_error "Could not get VM IP"
        return 1
    fi
    
    # Save images locally
    log_info "Saving Docker images..."
    docker save appflowy-backend:custom -o /tmp/appflowy-backend.tar
    docker save appflowy-frontend:custom -o /tmp/appflowy-frontend.tar
    
    # Copy to VM
    log_info "Copying images to VM..."
    gcloud compute scp /tmp/appflowy-backend.tar /tmp/appflowy-frontend.tar \
        "${VM_NAME}:/tmp/" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}"
    
    # Load images on VM
    log_info "Loading images on VM..."
    gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="docker load -i /tmp/appflowy-backend.tar && docker load -i /tmp/appflowy-frontend.tar"
    
    # Clean up
    rm /tmp/appflowy-backend.tar /tmp/appflowy-frontend.tar
    
    log_success "Images pushed to VM successfully"
    return 0
}

create_custom_docker_compose() {
    log_info "Creating custom docker-compose file..."
    
    local compose_file="${SCRIPT_DIR}/../docker/docker-compose-custom.yml"
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
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
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - appflowy-network
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    container_name: appflowy-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - appflowy-network

  appflowy-backend:
    image: appflowy-backend:custom
    container_name: appflowy-backend
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    environment:
      DATABASE_URL: postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy
      REDIS_URL: redis://redis:6379
      JWT_SECRET: ${GOTRUE_JWT_SECRET}
      APPFLOWY_ENVIRONMENT: production
    ports:
      - "8000:8000"
    networks:
      - appflowy-network

  appflowy-frontend:
    image: appflowy-frontend:custom
    container_name: appflowy-frontend
    restart: unless-stopped
    depends_on:
      - appflowy-backend
    environment:
      APPFLOWY_CLOUD_URL: http://appflowy-backend:8000
    ports:
      - "80:80"
    networks:
      - appflowy-network

  gotrue:
    image: supabase/gotrue:v2.151.0
    container_name: appflowy-gotrue
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://appflowy:${POSTGRES_PASSWORD}@postgres:5432/appflowy?search_path=auth
      GOTRUE_SITE_URL: http://${vm_ip}
      GOTRUE_JWT_SECRET: ${GOTRUE_JWT_SECRET}
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: ${GOOGLE_OAUTH_ENABLED:-false}
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOTRUE_EXTERNAL_GOOGLE_SECRET: ${GOOGLE_CLIENT_SECRET}
    ports:
      - "9999:9999"
    networks:
      - appflowy-network

networks:
  appflowy-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
EOF
    
    log_success "Custom docker-compose created"
    return 0
}

deploy_custom_stack() {
    log_info "Deploying custom stack to VM..."
    
    # Copy docker-compose to VM
    gcloud compute scp \
        "${SCRIPT_DIR}/../docker/docker-compose-custom.yml" \
        "${VM_NAME}:/opt/appflowy/config/" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}"
    
    # Deploy on VM
    local deploy_script='
cd /opt/appflowy/config

# Stop existing services
docker compose -f docker-compose-simplified.yml down 2>/dev/null || true

# Start custom stack
docker compose -f docker-compose-custom.yml up -d

# Wait for services
sleep 10

# Show status
docker compose -f docker-compose-custom.yml ps
'
    
    gcloud compute ssh "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --command="${deploy_script}"
    
    log_success "Custom stack deployed"
    return 0
}

main() {
    log_info "Starting deployment from submodules..."
    
    # Check submodules exist
    check_submodules || exit 1
    
    # Build images
    echo ""
    echo "Choose deployment option:"
    echo "1) Build locally and push to VM"
    echo "2) Build on VM (requires more VM resources)"
    echo "3) Use pre-built images from Docker Hub"
    read -p "Choice [1-3]: " choice
    
    case ${choice} in
        1)
            build_backend_image || exit 1
            build_frontend_image || exit 1
            push_images_to_vm || exit 1
            ;;
        2)
            log_info "Building on VM not yet implemented"
            exit 1
            ;;
        3)
            log_info "Using pre-built images"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Create and deploy custom docker-compose
    create_custom_docker_compose || exit 1
    deploy_custom_stack || exit 1
    
    # Show access info
    local vm_ip=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    echo ""
    echo "============================================"
    log_success "Custom AppFlowy stack deployed!"
    echo "============================================"
    echo ""
    echo "Access URLs:"
    echo "  Frontend: http://${vm_ip}"
    echo "  Backend API: http://${vm_ip}:8000"
    echo "  Auth Service: http://${vm_ip}:9999"
    echo ""
    echo "Your custom AppFlowy build is now running!"
}

main "$@"