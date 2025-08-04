#!/bin/bash

# install-security-tools.sh - Install core security tools for Ubuntu Security Toolkit
# This script specifically handles installation of security scanning and monitoring tools
# that are not included in the initial-setup.sh

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/ubuntu-security-toolkit-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to detect if running in container
is_container() {
    if [ -f /.dockerenv ] || grep -qa container=lxc /proc/1/environ 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check prerequisites
check_root

# Create log file
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

print_status "Starting security tools installation..."

# Update package lists
print_status "Updating package lists..."
apt-get update -qq || {
    print_error "Failed to update package lists"
    exit 1
}

# Core security tools
SECURITY_TOOLS=(
    "clamav"
    "clamav-daemon"
    "clamav-freshclam"
    "rkhunter"
    "chkrootkit"
    "lynis"
    "mailutils"
)

# Entropy tools (conditional based on environment)
if is_container; then
    print_status "Container environment detected - will install rng-tools"
    SECURITY_TOOLS+=("rng-tools")
else
    print_status "Bare metal/VM environment detected - will install haveged"
    SECURITY_TOOLS+=("haveged")
fi

# Check which packages need to be installed
TO_INSTALL=()
for tool in "${SECURITY_TOOLS[@]}"; do
    if ! dpkg -l "$tool" 2>/dev/null | grep -q "^ii"; then
        TO_INSTALL+=("$tool")
    else
        print_success "$tool is already installed"
    fi
done

# Install missing packages
if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    print_status "Installing ${#TO_INSTALL[@]} security tools..."
    
    for tool in "${TO_INSTALL[@]}"; do
        print_status "Installing $tool..."
        if apt-get install -y "$tool" >> "$LOG_FILE" 2>&1; then
            print_success "$tool installed successfully"
        else
            print_error "Failed to install $tool"
            exit 1
        fi
    done
else
    print_success "All security tools are already installed"
fi

# Configure ClamAV
if command -v clamscan &> /dev/null; then
    print_status "Configuring ClamAV..."
    
    # Stop clamav-freshclam service temporarily
    systemctl stop clamav-freshclam 2>/dev/null || true
    
    # Update virus definitions
    print_status "Updating ClamAV virus definitions (this may take several minutes)..."
    if freshclam >> "$LOG_FILE" 2>&1; then
        print_success "ClamAV virus definitions updated"
    else
        print_warning "Failed to update ClamAV definitions - will retry on service start"
    fi
    
    # Start and enable services
    systemctl enable clamav-freshclam 2>/dev/null || true
    systemctl start clamav-freshclam 2>/dev/null || true
    
    # Enable daemon for real-time scanning (optional)
    print_status "ClamAV daemon can be enabled for real-time scanning"
    print_status "To enable: sudo systemctl enable --now clamav-daemon"
fi

# Configure rkhunter
if command -v rkhunter &> /dev/null; then
    print_status "Configuring rkhunter..."
    
    # Update rkhunter database
    rkhunter --update >> "$LOG_FILE" 2>&1 || print_warning "Failed to update rkhunter database"
    
    # Update properties database
    rkhunter --propupd >> "$LOG_FILE" 2>&1 || print_warning "Failed to update rkhunter properties"
    
    print_success "rkhunter configured"
fi

# Configure lynis
if command -v lynis &> /dev/null; then
    print_status "Configuring lynis..."
    
    # Update lynis if possible
    lynis update info >> "$LOG_FILE" 2>&1 || true
    
    print_success "lynis configured"
fi

# Configure entropy services
if is_container; then
    if command -v rngd &> /dev/null; then
        print_status "Configuring rng-tools for container environment..."
        systemctl enable rng-tools 2>/dev/null || true
        systemctl start rng-tools 2>/dev/null || true
        print_success "rng-tools configured"
    fi
else
    if command -v haveged &> /dev/null; then
        print_status "Configuring haveged for bare metal/VM environment..."
        systemctl enable haveged 2>/dev/null || true
        systemctl start haveged 2>/dev/null || true
        print_success "haveged configured"
    fi
fi

# Test mail configuration
print_status "Testing mail configuration..."
if command -v mail &> /dev/null; then
    echo "Ubuntu Security Toolkit mail test" | mail -s "Test Email" root 2>/dev/null || {
        print_warning "Mail command available but sending failed"
        print_warning "You may need to configure a mail relay or local delivery"
    }
else
    print_warning "Mail command not available - reports will be saved to files only"
fi

# Display summary
echo
echo "========================================================"
echo "         Security Tools Installation Summary"
echo "========================================================"
echo "Installed tools:"
for tool in "${SECURITY_TOOLS[@]}"; do
    if command -v "${tool%%-*}" &> /dev/null || dpkg -l "$tool" 2>/dev/null | grep -q "^ii"; then
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool (failed)"
    fi
done
echo
echo "Next steps:"
echo "1. Run a test scan: sudo ${SCRIPT_DIR%/deploy}/common/monitoring/daily-security-scan.sh"
echo "2. Check ClamAV status: sudo systemctl status clamav-freshclam"
echo "3. Run initial rkhunter scan: sudo rkhunter --check --skip-keypress"
echo "4. Run lynis audit: sudo lynis audit system"
echo
echo "Log file: $LOG_FILE"
echo "========================================================" 

print_success "Security tools installation completed!"