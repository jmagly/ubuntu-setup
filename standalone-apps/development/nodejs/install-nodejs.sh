#!/bin/bash

# install-nodejs.sh - Install Node.js LTS and npm
# Standalone installer for Node.js development environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Node.js version (LTS)
NODE_VERSION="20"  # Will install Node.js 20.x LTS

print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running with proper permissions
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. Node.js will be installed system-wide."
    else
        print_status "Running as user $USER"
        print_status "You may be prompted for sudo password"
    fi
}

# Remove old Node.js installations
remove_old_nodejs() {
    print_status "Checking for existing Node.js installations..."
    
    if command -v node &> /dev/null; then
        local current_version=$(node --version)
        print_warning "Found existing Node.js $current_version"
        
        read -p "Remove existing installation? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Removing old Node.js..."
            sudo apt-get remove -y nodejs npm 2>/dev/null || true
            sudo apt-get autoremove -y
        fi
    fi
}

# Install Node.js via NodeSource repository
install_nodejs() {
    print_status "Installing Node.js $NODE_VERSION.x LTS..."
    
    # Install prerequisites
    print_status "Installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    
    # Add NodeSource GPG key
    print_status "Adding NodeSource repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    # Add NodeSource repository
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    
    # Update and install
    print_status "Installing Node.js and npm..."
    sudo apt-get update
    sudo apt-get install -y nodejs
    
    # Install build tools for native addons
    print_status "Installing build tools for native addons..."
    sudo apt-get install -y build-essential
}

# Install global npm packages
install_global_packages() {
    print_status "Installing useful global npm packages..."
    
    # Update npm to latest
    print_status "Updating npm to latest version..."
    sudo npm install -g npm@latest
    
    # Install commonly used global packages
    local packages=(
        "yarn"          # Alternative package manager
        "nodemon"       # Auto-restart for development
        "pm2"           # Process manager
        "npm-check"     # Check for outdated packages
    )
    
    for pkg in "${packages[@]}"; do
        print_status "Installing $pkg..."
        sudo npm install -g "$pkg" || print_warning "Failed to install $pkg"
    done
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        print_success "Node.js installed: $node_version"
    else
        print_error "Node.js not found"
        return 1
    fi
    
    if command -v npm &> /dev/null; then
        local npm_version=$(npm --version)
        print_success "npm installed: $npm_version"
    else
        print_error "npm not found"
        return 1
    fi
    
    # Show installation location
    print_status "Installation details:"
    echo "  Node.js binary: $(which node)"
    echo "  npm binary: $(which npm)"
    echo "  Global packages: $(npm root -g)"
}

# Main installation
main() {
    echo
    echo "========================================"
    echo "     Node.js LTS Installation"
    echo "========================================"
    echo
    
    check_permissions
    remove_old_nodejs
    install_nodejs
    install_global_packages
    verify_installation
    
    echo
    echo "========================================"
    echo "     Installation Complete!"
    echo "========================================"
    echo
    echo "Node.js ${NODE_VERSION}.x LTS has been installed"
    echo
    echo "To get started:"
    echo "  node --version    # Check Node.js version"
    echo "  npm --version     # Check npm version"
    echo "  npm init          # Start a new project"
    echo
    echo "Global packages installed:"
    echo "  yarn     - Alternative package manager"
    echo "  nodemon  - Auto-restart for development"
    echo "  pm2      - Production process manager"
    echo
}

# Run main function
main "$@"