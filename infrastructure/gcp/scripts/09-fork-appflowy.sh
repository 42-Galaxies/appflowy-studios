#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/../config/env.sh"

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

# Configuration for forked AppFlowy repository
GITHUB_ORG="${GITHUB_ORG:-42-galaxies}"
FORK_REPO_NAME="${FORK_REPO_NAME:-appflowy-cloud}"
UPSTREAM_REPO="https://github.com/AppFlowy-IO/AppFlowy-Cloud"
FORK_REPO="https://github.com/${GITHUB_ORG}/${FORK_REPO_NAME}"
LOCAL_REPO_PATH="${LOCAL_REPO_PATH:-/opt/appflowy-fork}"
CUSTOM_IMAGE_TAG="${CUSTOM_IMAGE_TAG:-latest}"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-gcr.io/${PROJECT_ID}}"

check_prerequisites() {
    log_info "Checking prerequisites for fork management..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "git is not installed"
        return 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed locally (will use VM for building)"
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

setup_fork_repository() {
    log_info "Setting up forked AppFlowy-Cloud repository..."
    
    # Create local directory if not exists
    if [[ ! -d "${LOCAL_REPO_PATH}" ]]; then
        log_info "Creating local repository directory..."
        mkdir -p "${LOCAL_REPO_PATH}"
    fi
    
    # Clone or update the fork
    if [[ -d "${LOCAL_REPO_PATH}/.git" ]]; then
        log_info "Repository already exists, updating..."
        cd "${LOCAL_REPO_PATH}"
        
        # Add upstream if not exists
        if ! git remote | grep -q upstream; then
            git remote add upstream "${UPSTREAM_REPO}"
        fi
        
        # Fetch latest changes
        git fetch origin
        git fetch upstream
    else
        log_info "Cloning forked repository..."
        git clone "${FORK_REPO}" "${LOCAL_REPO_PATH}"
        cd "${LOCAL_REPO_PATH}"
        
        # Add upstream remote
        git remote add upstream "${UPSTREAM_REPO}"
        git fetch upstream
    fi
    
    log_success "Fork repository setup complete"
}

sync_with_upstream() {
    cd "${LOCAL_REPO_PATH}"
    
    log_info "Syncing fork with upstream repository..."
    
    # Make sure we're on main branch
    git checkout main || git checkout master
    
    # Fetch latest from upstream
    git fetch upstream
    
    # Merge upstream changes
    local current_branch=$(git branch --show-current)
    log_info "Merging upstream/${current_branch} into fork..."
    
    if git merge "upstream/${current_branch}" --no-edit; then
        log_success "Successfully merged upstream changes"
        
        # Push to origin
        if git push origin "${current_branch}"; then
            log_success "Pushed updates to fork"
        else
            log_warning "Failed to push to fork (may need authentication)"
        fi
    else
        log_error "Merge conflicts detected. Please resolve manually."
        return 1
    fi
}

apply_customizations() {
    cd "${LOCAL_REPO_PATH}"
    
    log_info "Applying 42 Galaxies customizations..."
    
    # Create customizations branch if not exists
    if ! git branch | grep -q "42-galaxies-custom"; then
        git checkout -b 42-galaxies-custom
    else
        git checkout 42-galaxies-custom
    fi
    
    # Example customizations (modify as needed)
    
    # 1. Update branding in configuration
    if [[ -f "appflowy.toml" ]] || [[ -f "config.toml" ]]; then
        log_info "Updating configuration with custom branding..."
        # Add custom configuration changes here
    fi
    
    # 2. Add custom authentication logic for 42galaxies.studio domain
    log_info "Adding domain-specific authentication..."
    cat > custom-auth-config.md << 'EOF'
# 42 Galaxies Custom Authentication Configuration

## Google Workspace Domain Restriction
- Allowed domain: 42galaxies.studio
- Auto-join workspace on first login
- Custom role mappings based on Google groups

## Custom Features
1. Automatic workspace assignment based on email domain
2. Custom telemetry endpoint
3. Enhanced audit logging
4. Custom theme/branding

## Environment Variables
- ALLOWED_DOMAINS=42galaxies.studio
- AUTO_JOIN_WORKSPACE=true
- CUSTOM_TELEMETRY_ENDPOINT=https://telemetry.42galaxies.studio
EOF
    
    # 3. Create Dockerfile for custom build
    log_info "Creating custom Dockerfile..."
    cat > Dockerfile.custom << 'EOF'
# Use official AppFlowy-Cloud as base
FROM appflowyinc/appflowy_cloud:latest as base

# Add custom configuration
COPY custom-auth-config.md /opt/appflowy/config/
COPY custom-branding/ /opt/appflowy/static/branding/

# Set environment variables for 42 Galaxies
ENV ALLOWED_DOMAINS="42galaxies.studio"
ENV AUTO_JOIN_WORKSPACE="true"
ENV DEFAULT_WORKSPACE_NAME="42 Galaxies Workspace"

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

LABEL org.opencontainers.image.source="https://github.com/42-galaxies/appflowy-cloud"
LABEL org.opencontainers.image.description="42 Galaxies Custom AppFlowy Cloud"
EOF
    
    log_success "Customizations applied"
}

build_custom_image() {
    cd "${LOCAL_REPO_PATH}"
    
    local image_name="${REGISTRY_PREFIX}/appflowy-cloud-custom"
    local full_tag="${image_name}:${CUSTOM_IMAGE_TAG}"
    
    log_info "Building custom Docker image: ${full_tag}"
    
    # Check if we should build locally or on VM
    if command -v docker &> /dev/null; then
        log_info "Building image locally..."
        
        if docker build -f Dockerfile.custom -t "${full_tag}" .; then
            log_success "Custom image built successfully"
            
            # Push to registry if configured
            if [[ -n "${REGISTRY_PREFIX}" ]]; then
                log_info "Pushing image to registry..."
                if docker push "${full_tag}"; then
                    log_success "Image pushed to registry"
                else
                    log_warning "Failed to push image (may need to configure registry access)"
                fi
            fi
        else
            log_error "Failed to build custom image"
            return 1
        fi
    else
        log_info "Docker not available locally, using VM for build..."
        build_on_vm "${full_tag}"
    fi
}

build_on_vm() {
    local image_tag="$1"
    local vm_name="${VM_NAME}"
    local zone="${VM_ZONE}"
    
    log_info "Building custom image on VM '${vm_name}'..."
    
    # Copy repository to VM
    log_info "Syncing repository to VM..."
    gcloud compute scp \
        --recurse \
        "${LOCAL_REPO_PATH}" \
        "${vm_name}:/tmp/appflowy-fork" \
        --zone="${zone}" \
        --project="${PROJECT_ID}"
    
    # Build on VM
    local build_script='
cd /tmp/appflowy-fork
docker build -f Dockerfile.custom -t '"${image_tag}"' .
'
    
    if gcloud compute ssh "${vm_name}" \
        --zone="${zone}" \
        --project="${PROJECT_ID}" \
        --command="${build_script}"; then
        log_success "Custom image built on VM"
    else
        log_error "Failed to build image on VM"
        return 1
    fi
}

update_docker_compose() {
    log_info "Updating docker-compose.yml to use custom image..."
    
    local compose_update_script="
cd /opt/appflowy/config
# Backup original
cp docker-compose.yml docker-compose.yml.backup

# Update image reference
sed -i 's|image: appflowyinc/appflowy_cloud:latest|image: ${REGISTRY_PREFIX}/appflowy-cloud-custom:${CUSTOM_IMAGE_TAG}|g' docker-compose.yml

# Add domain restriction to GoTrue
cat >> docker-compose.yml << 'EXTRA_ENV'
      # 42 Galaxies Custom Configuration
      GOTRUE_EXTERNAL_GOOGLE_ALLOWED_DOMAINS: 42galaxies.studio
      GOTRUE_SECURITY_RESTRICT_EMAIL_DOMAINS: 42galaxies.studio
EXTRA_ENV

echo 'Docker Compose updated to use custom image'
"
    
    if [[ -n "${VM_NAME}" ]]; then
        log_info "Updating docker-compose.yml on VM..."
        gcloud compute ssh "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --command="${compose_update_script}"
    fi
    
    log_success "Docker Compose configuration updated"
}

setup_github_workflow() {
    cd "${LOCAL_REPO_PATH}"
    
    log_info "Setting up GitHub workflow for automated builds..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/build-custom.yml << 'EOF'
name: Build Custom AppFlowy Cloud

on:
  push:
    branches: [ 42-galaxies-custom ]
  pull_request:
    branches: [ 42-galaxies-custom ]
  schedule:
    # Weekly sync with upstream
    - cron: '0 0 * * 0'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Sync with upstream
      run: |
        git remote add upstream https://github.com/AppFlowy-IO/AppFlowy-Cloud
        git fetch upstream
        git checkout -b temp-sync
        git merge upstream/main --no-edit || true
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to GCR
      uses: docker/login-action@v2
      with:
        registry: gcr.io
        username: _json_key
        password: ${{ secrets.GCR_JSON_KEY }}
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        file: ./Dockerfile.custom
        push: true
        tags: |
          gcr.io/${{ secrets.GCP_PROJECT }}/appflowy-cloud-custom:latest
          gcr.io/${{ secrets.GCP_PROJECT }}/appflowy-cloud-custom:${{ github.sha }}
    
    - name: Deploy to VM
      run: |
        echo "Trigger deployment to VM"
        # Add deployment logic here
EOF
    
    log_success "GitHub workflow created"
}

main() {
    log_info "Starting AppFlowy fork management..."
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Interactive menu
    echo ""
    echo "AppFlowy Fork Management Options:"
    echo "  1) Setup fork repository"
    echo "  2) Sync with upstream"
    echo "  3) Apply customizations"
    echo "  4) Build custom image"
    echo "  5) Update deployment to use custom image"
    echo "  6) Full setup (all steps)"
    echo "  0) Exit"
    echo ""
    
    read -p "Enter your choice [0-6]: " choice
    
    case ${choice} in
        1)
            setup_fork_repository
            ;;
        2)
            sync_with_upstream
            ;;
        3)
            apply_customizations
            ;;
        4)
            build_custom_image
            ;;
        5)
            update_docker_compose
            ;;
        6)
            setup_fork_repository
            sync_with_upstream
            apply_customizations
            build_custom_image
            update_docker_compose
            setup_github_workflow
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
    
    log_success "Fork management completed!"
}

main "$@"