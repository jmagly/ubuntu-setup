#!/bin/bash
# example-with-deps.sh - Example script showing dependency management
# This demonstrates how to properly use the dependency checking library

set -euo pipefail

# Script directory and project root detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source the dependency checking library
source "$PROJECT_ROOT/common/lib/dependency-check.sh" 2>/dev/null || {
    echo "Error: Cannot find dependency-check.sh library" >&2
    echo "Make sure you're running this from within the ubuntu-security-toolkit directory" >&2
    exit 1
}

# Script description
SCRIPT_NAME="Example Script with Dependencies"
SCRIPT_VERSION="1.0.0"

# Function to display usage
usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

This is an example script showing how to use dependency checking.

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    -h, --help     Display this help message
    -v, --version  Display version information
    -i, --install  Auto-install missing dependencies

EXAMPLES:
    $(basename "$0")           # Check dependencies only
    $(basename "$0") --install # Install missing dependencies

EOF
}

# Parse command line arguments
AUTO_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "$SCRIPT_NAME v$SCRIPT_VERSION"
            exit 0
            ;;
        -i|--install)
            AUTO_INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main script logic
main() {
    echo "=== $SCRIPT_NAME ==="
    echo
    
    # Example 1: Check if running as root (optional for this example)
    if check_root 2>/dev/null; then
        echo "✓ Running as root"
    else
        echo "✗ Not running as root (some features may be limited)"
    fi
    
    # Example 2: Check Ubuntu version
    echo
    echo "Checking Ubuntu version..."
    if check_ubuntu_version "20.04"; then
        echo "✓ Ubuntu version is supported"
    else
        echo "⚠ Ubuntu version may not be fully tested"
    fi
    
    # Example 3: Check for required commands/packages
    echo
    echo "Checking required dependencies..."
    
    # Define required dependencies
    # Format: "command" or "command/package" if package name differs
    REQUIRED_DEPS=(
        "curl"
        "jq"
        "git"
        "nc/netcat"         # nc command provided by netcat package
        "ss/iproute2"       # ss command provided by iproute2 package
    )
    
    if [ "$AUTO_INSTALL" = true ]; then
        # Auto-install missing dependencies
        echo "Auto-installing missing dependencies..."
        if check_and_install_deps "${REQUIRED_DEPS[@]}"; then
            echo "✓ All dependencies installed successfully"
        else
            echo "✗ Failed to install some dependencies"
            exit 1
        fi
    else
        # Just check without installing
        if check_dependencies "${REQUIRED_DEPS[@]}"; then
            echo "✓ All dependencies are installed"
        else
            echo
            echo "To auto-install missing dependencies, run:"
            echo "  $(basename "$0") --install"
            exit 1
        fi
    fi
    
    # Example 4: Check for optional features
    echo
    echo "Checking optional features..."
    
    # Check if mail is available for notifications
    if command_exists "mail"; then
        echo "✓ Mail notifications available"
    else
        echo "ℹ Mail not available (notifications will be file-only)"
    fi
    
    # Check if running in a container
    if is_container; then
        echo "ℹ Running in container environment"
    else
        echo "ℹ Running on bare metal or VM"
    fi
    
    # Example 5: Check disk space
    echo
    echo "Checking disk space..."
    if check_disk_space 100 "/tmp"; then
        echo "✓ Sufficient disk space in /tmp"
    else
        echo "⚠ Low disk space in /tmp"
    fi
    
    # Example 6: Check network connectivity
    echo
    echo "Checking network connectivity..."
    if check_network; then
        echo "✓ Network connectivity confirmed"
    else
        echo "⚠ No network connectivity detected"
    fi
    
    # Example 7: Ensure log directory
    echo
    echo "Setting up logging..."
    LOG_DIR="/tmp/example-script-logs"
    if ensure_log_dir "$LOG_DIR"; then
        echo "✓ Log directory ready: $LOG_DIR"
        
        # Write a test log
        echo "$(date): Example script executed" >> "$LOG_DIR/example.log"
    else
        echo "✗ Failed to create log directory"
    fi
    
    # Example 8: Check specific services
    echo
    echo "Checking services..."
    if check_service "ssh"; then
        echo "✓ SSH service is active"
    else
        echo "ℹ SSH service is not active"
    fi
    
    echo
    echo "=== Dependency check complete ==="
    echo
    echo "This example demonstrates:"
    echo "- How to source the dependency library"
    echo "- Various types of dependency checks"
    echo "- Auto-installation of missing packages"
    echo "- Proper error handling and user feedback"
    echo
    echo "Use this as a template for new scripts in the toolkit!"
}

# Run main function
main