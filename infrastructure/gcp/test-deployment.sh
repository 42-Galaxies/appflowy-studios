#!/bin/bash

# Test script to validate AppFlowy deployment configuration
# This script tests the configuration without actually deploying

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================================="
echo "AppFlowy Deployment Configuration Test"
echo "==================================================="

# Test 1: Environment Configuration
echo "1. Testing environment configuration..."
if [[ -f "${SCRIPT_DIR}/config/env.sh" ]]; then
    source "${SCRIPT_DIR}/config/env.sh"
    echo "   ✓ env.sh exists and can be sourced"
    
    # Check required variables
    required_vars=(
        "PROJECT_ID"
        "VM_NAME"
        "VM_ZONE"
        "VM_MACHINE_TYPE"
        "POSTGRES_PASSWORD"
        "GOTRUE_JWT_SECRET"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -n "${!var}" ]]; then
            echo "   ✓ ${var} is set"
        else
            echo "   ✗ ${var} is not set"
        fi
    done
else
    echo "   ✗ config/env.sh not found"
fi

# Test 2: Script Syntax
echo ""
echo "2. Testing script syntax..."
scripts_to_check=(
    "scripts/05-create-vm.sh"
    "scripts/08-deploy-appflowy.sh"
)

for script in "${scripts_to_check[@]}"; do
    script_path="${SCRIPT_DIR}/${script}"
    if [[ -f "${script_path}" ]]; then
        if bash -n "${script_path}"; then
            echo "   ✓ ${script} syntax is valid"
        else
            echo "   ✗ ${script} has syntax errors"
        fi
    else
        echo "   ✗ ${script} not found"
    fi
done

# Test 3: Docker Configuration
echo ""
echo "3. Testing Docker configuration..."
docker_dir="${SCRIPT_DIR}/docker"

if [[ -f "${docker_dir}/docker-compose.yml" ]]; then
    echo "   ✓ docker-compose.yml exists"
    
    if command -v docker >/dev/null 2>&1; then
        cd "${docker_dir}"
        if docker compose config --quiet; then
            echo "   ✓ docker-compose.yml is valid"
        else
            echo "   ✗ docker-compose.yml has errors"
        fi
    else
        echo "   ⚠ Docker not installed, skipping validation"
    fi
else
    echo "   ✗ docker-compose.yml not found"
fi

# Test 4: Required Files
echo ""
echo "4. Testing required files..."
required_files=(
    "docker/nginx.conf"
    "docker/nginx-web.conf"
    "docker/init-db.sql"
    "docker/web/index.html"
)

for file in "${required_files[@]}"; do
    file_path="${SCRIPT_DIR}/${file}"
    if [[ -f "${file_path}" ]]; then
        echo "   ✓ ${file} exists"
    else
        echo "   ✗ ${file} not found"
    fi
done

# Test 5: Environment Variable Validation
echo ""
echo "5. Testing environment variable configurations..."

if [[ -f "${SCRIPT_DIR}/config/env.sh" ]]; then
    source "${SCRIPT_DIR}/config/env.sh"
    
    # Check password complexity
    if [[ ${#POSTGRES_PASSWORD} -ge 16 ]]; then
        echo "   ✓ POSTGRES_PASSWORD has adequate length"
    else
        echo "   ⚠ POSTGRES_PASSWORD should be at least 16 characters"
    fi
    
    if [[ ${#GOTRUE_JWT_SECRET} -ge 16 ]]; then
        echo "   ✓ GOTRUE_JWT_SECRET has adequate length"
    else
        echo "   ⚠ GOTRUE_JWT_SECRET should be at least 16 characters"
    fi
    
    # Check project ID format
    if [[ "${PROJECT_ID}" =~ ^[a-z]([a-z0-9-]*[a-z0-9])?$ ]] && [[ ${#PROJECT_ID} -ge 6 ]] && [[ ${#PROJECT_ID} -le 30 ]]; then
        echo "   ✓ PROJECT_ID format is valid"
    else
        echo "   ⚠ PROJECT_ID format may be invalid (should be 6-30 chars, lowercase, numbers, hyphens)"
    fi
fi

echo ""
echo "==================================================="
echo "Test Summary:"
echo "✓ = Pass"
echo "⚠ = Warning" 
echo "✗ = Fail"
echo "==================================================="
echo ""
echo "If all tests pass, you can proceed with deployment:"
echo "1. Run scripts/05-create-vm.sh to create the VM"
echo "2. Run scripts/08-deploy-appflowy.sh to deploy AppFlowy"
echo ""