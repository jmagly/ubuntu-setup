#!/bin/bash

# dependency-check.sh - Common dependency checking functions for Ubuntu Security Toolkit
# Source this file in your scripts to use these functions:
# source "$(dirname "$0")/../lib/dependency-check.sh"

# Colors for output (if not already defined)
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)" >&2
        return 1
    fi
    return 0
}

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local package="${2:-$cmd}"  # Optional package name if different from command
    
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Required command '$cmd' not found" >&2
        echo -e "${YELLOW}[INFO]${NC} Install it with: sudo apt-get install $package" >&2
        return 1
    fi
    return 0
}

# Function to check if a package is installed
check_package() {
    local package="$1"
    
    if ! dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        echo -e "${RED}[ERROR]${NC} Required package '$package' not installed" >&2
        echo -e "${YELLOW}[INFO]${NC} Install it with: sudo apt-get install $package" >&2
        return 1
    fi
    return 0
}

# Function to check multiple dependencies at once
check_dependencies() {
    local deps=("$@")
    local missing=()
    local failed=0
    
    for dep in "${deps[@]}"; do
        # Check if it's a command or package
        if [[ "$dep" == *"/"* ]]; then
            # Format: command/package
            local cmd="${dep%/*}"
            local pkg="${dep#*/}"
            if ! command -v "$cmd" &> /dev/null; then
                missing+=("$pkg")
                ((failed++))
            fi
        else
            # Just a command name
            if ! command -v "$dep" &> /dev/null; then
                missing+=("$dep")
                ((failed++))
            fi
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[ERROR]${NC} Missing dependencies: ${missing[*]}" >&2
        echo -e "${YELLOW}[INFO]${NC} Install with: sudo apt-get install ${missing[*]}" >&2
        return 1
    fi
    
    return 0
}

# Function to check and auto-install dependencies
check_and_install_deps() {
    local deps=("$@")
    local missing=()
    
    # Check what's missing
    for dep in "${deps[@]}"; do
        local pkg="$dep"
        local cmd="$dep"
        
        # Handle command/package format
        if [[ "$dep" == *"/"* ]]; then
            cmd="${dep%/*}"
            pkg="${dep#*/}"
        fi
        
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$pkg")
        fi
    done
    
    # Install if missing
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}[INFO]${NC} Installing missing dependencies: ${missing[*]}"
        
        # Update package lists
        apt-get update -qq || {
            echo -e "${RED}[ERROR]${NC} Failed to update package lists" >&2
            return 1
        }
        
        # Install packages
        for pkg in "${missing[@]}"; do
            echo -e "${BLUE}[INFO]${NC} Installing $pkg..."
            if apt-get install -y "$pkg" &> /dev/null; then
                echo -e "${GREEN}[SUCCESS]${NC} $pkg installed"
            else
                echo -e "${RED}[ERROR]${NC} Failed to install $pkg" >&2
                return 1
            fi
        done
    fi
    
    return 0
}

# Function to check if service is active
check_service() {
    local service="$1"
    
    if ! systemctl is-active "$service" &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} Service '$service' is not active" >&2
        echo -e "${YELLOW}[INFO]${NC} Start it with: sudo systemctl start $service" >&2
        return 1
    fi
    return 0
}

# Function to check if running in container
is_container() {
    if [ -f /.dockerenv ] || grep -qa container=lxc /proc/1/environ 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    local min_version="${1:-20.04}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        local current_version="$VERSION_ID"
        
        # Compare versions
        if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" = "$min_version" ]; then
            return 0
        else
            echo -e "${RED}[ERROR]${NC} Ubuntu $current_version is below minimum required version $min_version" >&2
            return 1
        fi
    else
        echo -e "${RED}[ERROR]${NC} Cannot determine Ubuntu version" >&2
        return 1
    fi
}

# Function to ensure log directory exists
ensure_log_dir() {
    local log_dir="${1:-/var/log/ubuntu-security-toolkit}"
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" || {
            echo -e "${RED}[ERROR]${NC} Failed to create log directory: $log_dir" >&2
            return 1
        }
    fi
    
    # Set appropriate permissions
    chmod 755 "$log_dir"
    return 0
}

# Function to check available disk space
check_disk_space() {
    local min_space_mb="${1:-100}"  # Default 100MB minimum
    local path="${2:-/}"
    
    local available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [ "$available_mb" -lt "$min_space_mb" ]; then
        echo -e "${RED}[ERROR]${NC} Insufficient disk space: ${available_mb}MB available, ${min_space_mb}MB required" >&2
        return 1
    fi
    
    return 0
}

# Function to check network connectivity
check_network() {
    local test_host="${1:-8.8.8.8}"
    
    if ! ping -c 1 -W 2 "$test_host" &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} No network connectivity detected" >&2
        return 1
    fi
    
    return 0
}

# Export functions for use in sourcing scripts
export -f check_root
export -f check_command
export -f check_package
export -f check_dependencies
export -f check_and_install_deps
export -f check_service
export -f is_container
export -f check_ubuntu_version
export -f ensure_log_dir
export -f check_disk_space
export -f check_network