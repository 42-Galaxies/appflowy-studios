#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
GITHUB_ORG="42-Galaxies"
BACKEND_REPO="AppFlowy-Cloud"
FRONTEND_REPO="AppFlowy"

echo "================================================"
echo "   AppFlowy Submodules Setup"
echo "================================================"
echo ""

# Step 1: Instructions for forking
echo "📋 Prerequisites - Fork these repositories on GitHub:"
echo ""
echo "1. Backend (AppFlowy-Cloud):"
echo "   Original: https://github.com/AppFlowy-IO/AppFlowy-Cloud"
echo "   Fork to: https://github.com/${GITHUB_ORG}/${BACKEND_REPO}"
echo ""
echo "2. Frontend (AppFlowy):"
echo "   Original: https://github.com/AppFlowy-IO/AppFlowy"
echo "   Fork to: https://github.com/${GITHUB_ORG}/${FRONTEND_REPO}"
echo ""
echo "Please ensure you have forked both repositories to the ${GITHUB_ORG} organization."
echo ""
read -p "Have you forked both repositories? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Please fork the repositories first, then run this script again."
    echo ""
    echo "To fork:"
    echo "1. Go to each repository URL above"
    echo "2. Click 'Fork' button"
    echo "3. Select '${GITHUB_ORG}' as the owner"
    exit 1
fi

# Step 2: Check if submodules already exist
log_info "Checking for existing submodules..."

if [ -d "src/appflowy-backend/.git" ] || [ -d "src/appflowy-frontend/.git" ]; then
    log_warning "Submodules already exist. Removing old ones..."
    git submodule deinit -f src/appflowy-backend 2>/dev/null || true
    git submodule deinit -f src/appflowy-frontend 2>/dev/null || true
    git rm -f src/appflowy-backend 2>/dev/null || true
    git rm -f src/appflowy-frontend 2>/dev/null || true
    rm -rf .git/modules/src/appflowy-backend 2>/dev/null || true
    rm -rf .git/modules/src/appflowy-frontend 2>/dev/null || true
    rm -rf src/appflowy-backend src/appflowy-frontend 2>/dev/null || true
fi

# Step 3: Add backend submodule
log_info "Adding AppFlowy-Cloud (backend) as submodule..."

if git submodule add "https://github.com/${GITHUB_ORG}/${BACKEND_REPO}.git" src/appflowy-backend; then
    log_success "Backend submodule added successfully"
else
    log_error "Failed to add backend submodule. Check if the fork exists."
    exit 1
fi

# Step 4: Add frontend submodule
log_info "Adding AppFlowy (frontend) as submodule..."

if git submodule add "https://github.com/${GITHUB_ORG}/${FRONTEND_REPO}.git" src/appflowy-frontend; then
    log_success "Frontend submodule added successfully"
else
    log_error "Failed to add frontend submodule. Check if the fork exists."
    exit 1
fi

# Step 5: Initialize and update submodules
log_info "Initializing submodules..."
git submodule update --init --recursive

# Step 6: Set up tracking for main/master branches
log_info "Setting up branch tracking..."

cd src/appflowy-backend
git checkout main 2>/dev/null || git checkout master
cd ../..

cd src/appflowy-frontend
git checkout main 2>/dev/null || git checkout master
cd ../..

# Step 7: Create .gitmodules if it doesn't exist properly
log_info "Verifying .gitmodules configuration..."

cat > .gitmodules << EOF
[submodule "src/appflowy-backend"]
	path = src/appflowy-backend
	url = https://github.com/${GITHUB_ORG}/${BACKEND_REPO}.git
	branch = main
[submodule "src/appflowy-frontend"]
	path = src/appflowy-frontend
	url = https://github.com/${GITHUB_ORG}/${FRONTEND_REPO}.git
	branch = main
EOF

# Step 8: Show status
log_success "Submodules setup complete!"
echo ""
echo "📁 Submodule Status:"
git submodule status
echo ""

echo "📝 Next Steps:"
echo "1. Commit the submodule changes:"
echo "   git add .gitmodules src/"
echo "   git commit -m 'feat: Add AppFlowy backend and frontend as submodules'"
echo "   git push"
echo ""
echo "2. To update submodules in the future:"
echo "   git submodule update --remote --merge"
echo ""
echo "3. To make changes to the forks:"
echo "   cd src/appflowy-backend  # or src/appflowy-frontend"
echo "   git checkout -b your-feature-branch"
echo "   # make changes"
echo "   git push origin your-feature-branch"
echo ""
echo "4. Update deployment scripts to build from submodules"
echo ""

log_success "Setup complete! The AppFlowy stack is now under your control."