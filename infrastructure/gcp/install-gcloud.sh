#!/bin/bash

# Google Cloud SDK Installation Script for Linux
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Google Cloud SDK Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${GREEN}Detected Linux system${NC}"
    
    # Check if running on Arch/CachyOS
    if command -v pacman &>/dev/null; then
        echo -e "${YELLOW}Detected Arch-based system (CachyOS/Arch/Manjaro)${NC}"
        echo ""
        echo "Installing via AUR is recommended. Options:"
        echo ""
        echo "1. Using yay (AUR helper):"
        echo -e "${GREEN}   yay -S google-cloud-cli${NC}"
        echo ""
        echo "2. Using paru (AUR helper):"
        echo -e "${GREEN}   paru -S google-cloud-cli${NC}"
        echo ""
        echo "3. Using pacman (official repo - if available):"
        echo -e "${GREEN}   sudo pacman -S google-cloud-cli${NC}"
        echo ""
        echo "Or continue with the official installation script below..."
        echo ""
        read -p "Do you want to use the official Google installer instead? (y/n): " use_official
        
        if [[ ! "$use_official" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Please install using one of the methods above, then run:"
            echo -e "${GREEN}   gcloud init${NC}"
            exit 0
        fi
    fi
    
    # Official Google Cloud SDK installation
    echo "Starting official Google Cloud SDK installation..."
    echo ""
    
    # Create temp directory
    INSTALL_DIR="${HOME}/google-cloud-sdk"
    
    if [[ -d "${INSTALL_DIR}" ]]; then
        echo -e "${YELLOW}Google Cloud SDK directory already exists at ${INSTALL_DIR}${NC}"
        read -p "Do you want to reinstall? (y/n): " reinstall
        if [[ "$reinstall" =~ ^[Yy]$ ]]; then
            echo "Removing existing installation..."
            rm -rf "${INSTALL_DIR}"
        else
            echo "Using existing installation..."
            echo ""
            echo "To configure, run:"
            echo -e "${GREEN}   gcloud init${NC}"
            exit 0
        fi
    fi
    
    # Download and install
    echo "Downloading Google Cloud SDK..."
    curl -o /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
    
    echo "Extracting..."
    tar -xf /tmp/google-cloud-sdk.tar.gz -C "${HOME}"
    
    echo "Running installation script..."
    "${INSTALL_DIR}/install.sh" --quiet
    
    # Clean up
    rm /tmp/google-cloud-sdk.tar.gz
    
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Restart your shell or run:"
    echo -e "${GREEN}   source ~/.bashrc${NC}"
    echo ""
    echo "2. Initialize gcloud:"
    echo -e "${GREEN}   gcloud init${NC}"
    echo ""
    echo "3. Authenticate:"
    echo -e "${GREEN}   gcloud auth login${NC}"
    echo -e "${GREEN}   gcloud auth application-default login${NC}"
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${GREEN}Detected macOS${NC}"
    echo ""
    
    if command -v brew &>/dev/null; then
        echo "Installing via Homebrew..."
        brew install --cask google-cloud-sdk
        echo ""
        echo -e "${GREEN}Installation complete!${NC}"
        echo ""
        echo "Initialize gcloud:"
        echo -e "${GREEN}   gcloud init${NC}"
    else
        echo "Homebrew not found. Installing via official installer..."
        curl https://sdk.cloud.google.com | bash
        exec -l $SHELL
        gcloud init
    fi
else
    echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
    echo "Please visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup complete! You can now run:${NC}"
echo -e "${GREEN}   cd infrastructure/gcp${NC}"
echo -e "${GREEN}   ./guide.sh${NC}"
echo -e "${BLUE}========================================${NC}"