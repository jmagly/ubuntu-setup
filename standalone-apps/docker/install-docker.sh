#!/bin/bash

# install-docker.sh - Standalone Docker installation script
# Installs Docker Engine and Docker Compose on Ubuntu systems
# Supports Ubuntu 20.04, 22.04, and 24.04

set -euo pipefail

# Script version
VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. Docker will be configured for root user only."
        print_warning "For non-root access, run this script as a regular user with sudo privileges."
    fi
}

# Function to detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION="$VERSION_ID"
        print_status "Detected Ubuntu $UBUNTU_VERSION"
        
        case "$UBUNTU_VERSION" in
            "20.04"|"22.04"|"24.04")
                print_success "Ubuntu version $UBUNTU_VERSION is supported"
                ;;
            *)
                print_warning "Ubuntu version $UBUNTU_VERSION is not officially tested"
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
                ;;
        esac
    else
        print_error "Cannot detect Ubuntu version"
        exit 1
    fi
}

# Function to check if Docker is already installed
check_existing_docker() {
    if command -v docker &> /dev/null; then
        print_warning "Docker is already installed:"
        docker --version
        read -p "Reinstall/Update Docker? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing Docker installation"
            exit 0
        fi
    fi
}

# Function to remove old Docker installations
remove_old_docker() {
    print_status "Removing old Docker installations if present..."
    
    # Remove old versions
    for pkg in docker docker-engine docker.io containerd runc; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            print_status "Removing $pkg..."
            sudo apt-get remove -y $pkg || true
        fi
    done
}

# Function to install prerequisites
install_prerequisites() {
    print_status "Installing prerequisites..."
    
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

# Function to add Docker repository
add_docker_repository() {
    print_status "Adding Docker's official GPG key..."
    
    # Create keyrings directory
    sudo mkdir -p /etc/apt/keyrings
    
    # Add Docker's GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    print_status "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# Function to install Docker
install_docker() {
    print_status "Updating package index..."
    sudo apt-get update
    
    print_status "Installing Docker Engine and Docker Compose..."
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
}

# Function to configure Docker for non-root user
configure_docker_user() {
    if [ "$EUID" -ne 0 ]; then
        print_status "Configuring Docker for non-root user..."
        
        # Create docker group if it doesn't exist
        sudo groupadd docker 2>/dev/null || true
        
        # Add current user to docker group
        sudo usermod -aG docker $USER
        
        print_success "User $USER added to docker group"
        print_warning "You need to log out and back in for group changes to take effect"
        print_warning "Or run: newgrp docker"
    fi
}

# Function to configure Docker daemon
configure_docker_daemon() {
    print_status "Configuring Docker daemon..."
    
    # Create Docker config directory
    sudo mkdir -p /etc/docker
    
    # Create daemon.json with sensible defaults
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true
}
EOF
    
    # Restart Docker to apply configuration
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

# Function to enable Docker service
enable_docker_service() {
    print_status "Enabling Docker service..."
    
    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service
    
    print_success "Docker service enabled"
}

# Function to verify installation
verify_installation() {
    print_status "Verifying Docker installation..."
    
    # Check Docker version
    if docker --version &> /dev/null; then
        print_success "Docker Engine: $(docker --version)"
    else
        print_error "Docker Engine not found"
        return 1
    fi
    
    # Check Docker Compose version
    if docker compose version &> /dev/null; then
        print_success "Docker Compose: $(docker compose version)"
    else
        print_error "Docker Compose not found"
        return 1
    fi
    
    # Run hello-world container
    print_status "Running test container..."
    if sudo docker run --rm hello-world &> /dev/null; then
        print_success "Docker is working correctly"
    else
        print_error "Failed to run test container"
        return 1
    fi
}

# Function to display post-installation information
show_post_install_info() {
    echo
    echo "========================================================"
    echo "          Docker Installation Complete!"
    echo "========================================================"
    echo
    echo "Docker Engine: $(docker --version 2>/dev/null || echo "Not accessible")"
    echo "Docker Compose: $(docker compose version 2>/dev/null || echo "Not accessible")"
    echo
    
    if [ "$EUID" -ne 0 ]; then
        echo "To use Docker without sudo:"
        echo "1. Log out and log back in, OR"
        echo "2. Run: newgrp docker"
        echo
    fi
    
    echo "Useful Docker commands:"
    echo "  docker run hello-world      # Test Docker installation"
    echo "  docker ps                   # List running containers"
    echo "  docker images              # List downloaded images"
    echo "  docker system df           # Show Docker disk usage"
    echo "  docker system prune        # Clean up unused resources"
    echo
    echo "Docker documentation: https://docs.docker.com"
    echo "========================================================"
}

# Function to display usage
usage() {
    cat << EOF
Docker Standalone Installer v${VERSION}

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    -h, --help          Display this help message
    -v, --version       Display version information
    --skip-hello-world  Skip hello-world test container
    --no-user-config    Skip non-root user configuration

EXAMPLES:
    $(basename "$0")                  # Standard installation
    sudo $(basename "$0")             # Install as root
    $(basename "$0") --skip-hello-world  # Skip test container

This script installs:
  - Docker Engine (docker-ce)
  - Docker CLI (docker-ce-cli)
  - containerd
  - Docker Buildx
  - Docker Compose

Supported Ubuntu versions: 20.04, 22.04, 24.04

EOF
}

# Parse command line arguments
SKIP_HELLO_WORLD=false
NO_USER_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "Docker Installer v${VERSION}"
            exit 0
            ;;
        --skip-hello-world)
            SKIP_HELLO_WORLD=true
            shift
            ;;
        --no-user-config)
            NO_USER_CONFIG=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main installation process
main() {
    print_status "Starting Docker installation..."
    
    # Check if running as root
    check_root
    
    # Detect Ubuntu version
    detect_ubuntu_version
    
    # Check for existing Docker installation
    check_existing_docker
    
    # Remove old Docker versions
    remove_old_docker
    
    # Install prerequisites
    install_prerequisites
    
    # Add Docker repository
    add_docker_repository
    
    # Install Docker
    install_docker
    
    # Configure Docker daemon
    configure_docker_daemon
    
    # Configure for non-root user
    if [ "$NO_USER_CONFIG" = false ]; then
        configure_docker_user
    fi
    
    # Enable Docker service
    enable_docker_service
    
    # Verify installation
    if [ "$SKIP_HELLO_WORLD" = false ]; then
        verify_installation
    fi
    
    # Show post-installation information
    show_post_install_info
}

# Run main function
main