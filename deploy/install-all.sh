#!/bin/bash

# install-all.sh - Master installation script for Ubuntu Security Toolkit
# This script orchestrates the installation of all security tools and dependencies
# Supports Ubuntu 20.04, 22.04, and 24.04

set -euo pipefail

# Script version
VERSION="1.0.0"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REQUIREMENTS_DIR="$SCRIPT_DIR/requirements"
LOG_DIR="/var/log/ubuntu-security-toolkit"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Installation modes
INSTALL_MODE="standard"  # minimal, standard, full
DRY_RUN=false
INTERACTIVE=true
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION="$VERSION_ID"
        print_info "Detected Ubuntu $UBUNTU_VERSION"
        
        # Check if version is supported
        case "$UBUNTU_VERSION" in
            "20.04"|"22.04"|"24.04")
                print_success "Ubuntu version $UBUNTU_VERSION is supported"
                ;;
            *)
                print_warning "Ubuntu version $UBUNTU_VERSION is not officially tested"
                if [ "$FORCE" = false ]; then
                    read -p "Continue anyway? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        exit 1
                    fi
                fi
                ;;
        esac
    else
        print_error "Cannot detect Ubuntu version"
        exit 1
    fi
}

# Function to detect environment type
detect_environment() {
    # Check if running in container
    if [ -f /.dockerenv ] || grep -qa container=lxc /proc/1/environ 2>/dev/null; then
        IS_CONTAINER=true
        print_info "Running in container environment"
    else
        IS_CONTAINER=false
        print_info "Running on bare metal/VM"
    fi
    
    # Check if desktop environment exists
    if [ -n "${DESKTOP_SESSION:-}" ] || [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        IS_DESKTOP=true
        print_info "Desktop environment detected"
    else
        IS_DESKTOP=false
        print_info "Server environment (no desktop)"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Ubuntu Security Toolkit - Master Installer v${VERSION}

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    -m, --mode MODE      Installation mode: minimal, standard, full (default: standard)
    -n, --non-interactive Run without prompts
    -d, --dry-run        Show what would be installed without making changes
    -f, --force          Force installation on unsupported versions
    -h, --help           Display this help message
    -v, --version        Display version information

INSTALLATION MODES:
    minimal   - Core security tools only (fail2ban, ufw, auditd)
    standard  - Core + antivirus + monitoring tools (recommended)
    full      - All tools including optional enhancements

EXAMPLES:
    $(basename "$0")                    # Interactive standard installation
    $(basename "$0") -m full -n         # Non-interactive full installation
    $(basename "$0") -d                 # Dry run to see what would be installed

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                INSTALL_MODE="$2"
                shift 2
                ;;
            -n|--non-interactive)
                INTERACTIVE=false
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "Ubuntu Security Toolkit Installer v${VERSION}"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Function to create log directory
setup_logging() {
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$LOG_DIR"
        touch "$LOG_FILE"
        print_info "Installation log: $LOG_FILE"
    fi
}

# Function to load package lists based on installation mode
load_package_lists() {
    local packages=()
    
    # Core packages (always installed except Docker packages)
    if [ -f "$REQUIREMENTS_DIR/packages.txt" ]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
            # Skip Docker packages (handled separately)
            [[ "$line" =~ docker- ]] && continue
            # Extract package name (before the # comment)
            package=$(echo "$line" | cut -d'#' -f1 | xargs)
            [ -n "$package" ] && packages+=("$package")
        done < "$REQUIREMENTS_DIR/packages.txt"
    fi
    
    # Optional packages for full installation
    if [ "$INSTALL_MODE" = "full" ] && [ -f "$REQUIREMENTS_DIR/packages-optional.txt" ]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
            package=$(echo "$line" | cut -d'#' -f1 | xargs)
            [ -n "$package" ] && packages+=("$package")
        done < "$REQUIREMENTS_DIR/packages-optional.txt"
    fi
    
    # Filter packages based on installation mode
    case "$INSTALL_MODE" in
        minimal)
            # Only core security packages
            PACKAGES_TO_INSTALL=(
                "ufw" "fail2ban" "auditd" "apparmor" "apparmor-utils"
                "curl" "gnupg" "lsb-release" "software-properties-common"
                "git" "vim" "htop" "net-tools"
            )
            ;;
        standard)
            # Exclude optional packages
            PACKAGES_TO_INSTALL=()
            for pkg in "${packages[@]}"; do
                # Skip optional monitoring tools
                if [[ ! "$pkg" =~ ^(apache2|nginx|geoipupdate|mmdb-bin|iotop|iftop|ncdu|aide|tripwire|ossec-hids|podman|buildah|logwatch|sysstat|dstat|nmap|tcpdump|wireshark-cli|rsync|duplicity|rng-tools-debian)$ ]]; then
                    PACKAGES_TO_INSTALL+=("$pkg")
                fi
            done
            ;;
        full)
            PACKAGES_TO_INSTALL=("${packages[@]}")
            ;;
    esac
}

# Function to check existing installations
check_existing_packages() {
    print_status "Checking existing package installations..."
    
    local installed=()
    local missing=()
    
    for package in "${PACKAGES_TO_INSTALL[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            installed+=("$package")
        else
            missing+=("$package")
        fi
    done
    
    if [ ${#installed[@]} -gt 0 ]; then
        print_info "Already installed: ${#installed[@]} packages"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_info "To be installed: ${#missing[@]} packages"
        PACKAGES_TO_INSTALL=("${missing[@]}")
    else
        print_success "All required packages are already installed"
        PACKAGES_TO_INSTALL=()
    fi
}

# Function to install packages
install_packages() {
    if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
        return 0
    fi
    
    print_status "Installing packages..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would install the following packages:"
        printf '%s\n' "${PACKAGES_TO_INSTALL[@]}" | column
        return 0
    fi
    
    # Update package lists
    print_status "Updating package lists..."
    apt-get update -qq
    
    # Install packages
    for package in "${PACKAGES_TO_INSTALL[@]}"; do
        print_status "Installing $package..."
        if apt-get install -y "$package" >> "$LOG_FILE" 2>&1; then
            print_success "$package installed successfully"
        else
            print_warning "Failed to install $package (check log for details)"
        fi
    done
}

# Function to configure ClamAV
configure_clamav() {
    if ! command -v clamscan &> /dev/null; then
        return 0
    fi
    
    print_status "Configuring ClamAV..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would configure ClamAV"
        return 0
    fi
    
    # Stop clamav-freshclam to update databases
    systemctl stop clamav-freshclam || true
    
    # Update virus definitions
    print_status "Updating ClamAV virus definitions (this may take a while)..."
    if freshclam >> "$LOG_FILE" 2>&1; then
        print_success "ClamAV virus definitions updated"
    else
        print_warning "Failed to update ClamAV definitions (will retry on next run)"
    fi
    
    # Start services
    systemctl start clamav-freshclam || true
    systemctl enable clamav-freshclam || true
    
    # Enable daemon if requested
    if [ "$INSTALL_MODE" != "minimal" ]; then
        systemctl enable clamav-daemon || true
        systemctl start clamav-daemon || true
    fi
}

# Function to configure entropy services
configure_entropy() {
    print_status "Configuring entropy services..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would configure entropy services"
        return 0
    fi
    
    if [ "$IS_CONTAINER" = true ]; then
        # In containers, prefer rng-tools
        if command -v rngd &> /dev/null; then
            print_info "Configuring rng-tools for container environment"
            systemctl enable rng-tools || true
            systemctl start rng-tools || true
            # Disable haveged if present
            systemctl stop haveged 2>/dev/null || true
            systemctl disable haveged 2>/dev/null || true
        fi
    else
        # On bare metal/VMs, prefer haveged
        if command -v haveged &> /dev/null; then
            print_info "Configuring haveged for bare metal/VM environment"
            systemctl enable haveged || true
            systemctl start haveged || true
            # Disable rng-tools if present
            systemctl stop rng-tools 2>/dev/null || true
            systemctl disable rng-tools 2>/dev/null || true
        fi
    fi
}

# Function to configure mail system
configure_mail() {
    print_status "Checking mail system configuration..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would configure mail system"
        return 0
    fi
    
    # Check if any mail system is installed
    if command -v mail &> /dev/null || command -v sendmail &> /dev/null; then
        print_success "Mail system is available"
    else
        print_warning "No mail system found. Security reports will be saved to files only."
        print_info "To enable email reports, install mailutils or postfix"
    fi
}

# Function to run existing setup scripts
run_setup_scripts() {
    print_status "Running additional setup scripts..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run setup scripts"
        return 0
    fi
    
    # Run initial setup if not already done
    if [ -f "$SCRIPT_DIR/initial-setup.sh" ] && [ ! -f /etc/ubuntu-security-toolkit.configured ]; then
        print_status "Running initial system setup..."
        if bash "$SCRIPT_DIR/initial-setup.sh" >> "$LOG_FILE" 2>&1; then
            print_success "Initial setup completed"
            touch /etc/ubuntu-security-toolkit.configured
        else
            print_warning "Initial setup encountered issues (check log)"
        fi
    fi
    
    # Configure fail2ban
    if [ -f "$SCRIPT_DIR/configure-fail2ban.sh" ] && command -v fail2ban-client &> /dev/null; then
        print_status "Configuring fail2ban..."
        if bash "$SCRIPT_DIR/configure-fail2ban.sh" >> "$LOG_FILE" 2>&1; then
            print_success "Fail2ban configured"
        else
            print_warning "Fail2ban configuration encountered issues (check log)"
        fi
    fi
}

# Function to setup cron jobs
setup_cron_jobs() {
    print_status "Setting up scheduled security tasks..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would setup cron jobs"
        return 0
    fi
    
    # Create cron directory for our jobs
    mkdir -p /etc/cron.d
    
    # Daily security scan
    if [ -f "$PROJECT_ROOT/common/monitoring/daily-security-scan.sh" ]; then
        cat > /etc/cron.d/ubuntu-security-toolkit << EOF
# Ubuntu Security Toolkit - Automated Security Tasks
# Daily security scan at 3 AM
0 3 * * * root $PROJECT_ROOT/common/monitoring/daily-security-scan.sh >> $LOG_DIR/daily-scan.log 2>&1

# ClamAV daily scan at 2 AM (if installed)
0 2 * * * root [ -x $PROJECT_ROOT/common/clamav/clamav-daily-scan.sh ] && $PROJECT_ROOT/common/clamav/clamav-daily-scan.sh >> $LOG_DIR/clamav-daily.log 2>&1

# Update GeoIP databases weekly (Sunday at 4 AM)
0 4 * * 0 root [ -x $PROJECT_ROOT/common/fail2ban/update-geoip.sh ] && $PROJECT_ROOT/common/fail2ban/update-geoip.sh >> $LOG_DIR/geoip-update.log 2>&1
EOF
        print_success "Scheduled security tasks configured"
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would verify installation"
        return 0
    fi
    
    # Run verification script
    if [ -f "$SCRIPT_DIR/verify-installation.sh" ]; then
        if bash "$SCRIPT_DIR/verify-installation.sh"; then
            print_success "Installation verification passed"
        else
            print_warning "Some components may need attention"
        fi
    fi
}

# Function to display post-installation summary
show_summary() {
    echo
    echo "========================================================"
    echo "         Ubuntu Security Toolkit Installation Summary"
    echo "========================================================"
    echo "Installation Mode: $INSTALL_MODE"
    echo "Environment: $([ "$IS_CONTAINER" = true ] && echo "Container" || echo "Bare Metal/VM")"
    echo "              $([ "$IS_DESKTOP" = true ] && echo "Desktop" || echo "Server")"
    echo "Ubuntu Version: $UBUNTU_VERSION"
    echo
    
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN COMPLETED - No changes were made"
    else
        echo "Installation completed successfully!"
        echo
        echo "Next Steps:"
        echo "1. Review the installation log: $LOG_FILE"
        echo "2. Run verification: sudo $SCRIPT_DIR/verify-installation.sh"
        echo "3. Configure SSH hardening: sudo $SCRIPT_DIR/deploy-ssh-hardening.sh"
        echo "4. Review and adjust fail2ban rules as needed"
        echo "5. Set up user accounts if not already done"
        echo
        echo "Daily security scans will run automatically at 3 AM"
        echo "ClamAV scans will run daily at 2 AM"
        echo "GeoIP databases will update weekly on Sundays"
    fi
    echo "========================================================"
}

# Main installation flow
main() {
    # Parse arguments
    parse_args "$@"
    
    # Initial checks
    check_root
    setup_logging
    
    print_status "Starting Ubuntu Security Toolkit installation..."
    
    # System detection
    detect_ubuntu_version
    detect_environment
    
    # Load package lists
    load_package_lists
    
    # Check what needs to be installed
    check_existing_packages
    
    # Interactive confirmation
    if [ "$INTERACTIVE" = true ] && [ "$DRY_RUN" = false ] && [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
        echo
        print_info "Ready to install ${#PACKAGES_TO_INSTALL[@]} packages"
        read -p "Continue with installation? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Perform installation
    install_packages
    
    # Configure installed services
    configure_clamav
    configure_entropy
    configure_mail
    
    # Run setup scripts
    run_setup_scripts
    
    # Setup scheduled tasks
    setup_cron_jobs
    
    # Verify installation
    verify_installation
    
    # Show summary
    show_summary
}

# Run main function
main "$@"