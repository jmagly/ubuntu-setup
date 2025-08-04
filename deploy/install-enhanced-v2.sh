#!/bin/bash

# install-enhanced-v2.sh - Enhanced installation script with proper logging
# Fixed version that captures all command outputs while maintaining good UX

set -euo pipefail

# Script version
VERSION="2.1.0"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source UI helper
source "$PROJECT_ROOT/common/lib/ui-helper.sh" 2>/dev/null || {
    echo "Error: Cannot find ui-helper.sh"
    exit 1
}

# Source dependency checker
source "$PROJECT_ROOT/common/lib/dependency-check.sh" 2>/dev/null || {
    echo "Error: Cannot find dependency-check.sh"
    exit 1
}

# Installation configuration
LOG_DIR="/var/log/ubuntu-security-toolkit"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
INTERACTIVE_LOG="$LOG_DIR/interactive-$(date +%Y%m%d-%H%M%S).log"
INSTALL_MODE="standard"
DRY_RUN=false
INTERACTIVE=true

# Tripwire configuration
TRIPWIRE_SITE_KEY=""
TRIPWIRE_LOCAL_KEY=""
TRIPWIRE_KEYS_DIR="/etc/tripwire/keys-backup"

# Statistics
PACKAGES_INSTALLED=0
PACKAGES_FAILED=0
PACKAGES_SKIPPED=0

# Function to log command output
log_command() {
    local description="$1"
    shift
    local command="$@"
    
    echo "[$description] Running: $command" >> "$LOG_FILE"
    echo "================== START OUTPUT ==================" >> "$LOG_FILE"
    
    # Run command and capture output
    if $command >> "$LOG_FILE" 2>&1; then
        local exit_code=0
    else
        local exit_code=$?
    fi
    
    echo "================== END OUTPUT (exit: $exit_code) ==================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    return $exit_code
}

# Function to check root
check_root_enhanced() {
    if [ "$EUID" -ne 0 ]; then
        show_error_box "Root Required" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to setup logging
setup_logging_enhanced() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    touch "$INTERACTIVE_LOG"
    
    # Log system info
    {
        echo "Installation started at: $(date)"
        echo "System: $(uname -a)"
        echo "Ubuntu: $(lsb_release -d | cut -f2)"
        echo "User: $USER"
        echo "Script: $0 $@"
        echo "----------------------------------------"
    } >> "$LOG_FILE"
}

# Function to display welcome screen
show_welcome() {
    clear
    print_header "Ubuntu Security Toolkit - Enhanced Installer v$VERSION"
    
    echo -e "${SHIELD} ${BOLD_BLUE}Security-Focused System Hardening${NC}"
    echo
    echo "This installer will configure:"
    echo -e "  ${CHECK_MARK} System hardening and firewall"
    echo -e "  ${CHECK_MARK} Intrusion detection (Fail2ban)"
    echo -e "  ${CHECK_MARK} Antivirus (ClamAV)"
    echo -e "  ${CHECK_MARK} Rootkit detection (RKHunter, Chkrootkit)"
    echo -e "  ${CHECK_MARK} Security auditing (Lynis)"
    echo -e "  ${CHECK_MARK} File integrity monitoring (Tripwire)"
    echo
    
    if ! confirm "Ready to begin installation?" "y"; then
        print_info "Installation cancelled"
        exit 0
    fi
}

# Function to handle tripwire installation
install_tripwire() {
    print_section "Tripwire Installation"
    
    if dpkg -l tripwire 2>/dev/null | grep -q "^ii"; then
        print_task "Tripwire already installed" "skip"
        ((PACKAGES_SKIPPED++))
        return 0
    fi
    
    print_info "Tripwire requires interactive key generation"
    print_info "You will be prompted to create two passphrases:"
    echo -e "  ${BULLET} Site passphrase (for configuration files)"
    echo -e "  ${BULLET} Local passphrase (for database/reports)"
    echo
    print_warning "IMPORTANT: Save these passphrases securely!"
    echo
    
    if ! confirm "Proceed with Tripwire installation?" "y"; then
        print_task "Tripwire installation" "skip"
        ((PACKAGES_SKIPPED++))
        return 0
    fi
    
    # Pre-configure debconf to reduce prompts
    echo "tripwire tripwire/use-sitekey boolean true" | debconf-set-selections
    echo "tripwire tripwire/use-localkey boolean true" | debconf-set-selections
    
    print_status "Installing Tripwire (interactive)..."
    
    # Install tripwire interactively
    echo "Installing Tripwire interactively..." >> "$LOG_FILE"
    DEBIAN_FRONTEND=readline apt-get install -y tripwire 2>&1 | tee -a "$INTERACTIVE_LOG"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "Tripwire installed successfully"
        ((PACKAGES_INSTALLED++))
        
        # Backup keys if they exist
        if [ -f "/etc/tripwire/site.key" ] && [ -f "/etc/tripwire/$(hostname)-local.key" ]; then
            print_status "Backing up Tripwire keys..."
            log_command "Backup Tripwire keys" mkdir -p "$TRIPWIRE_KEYS_DIR"
            log_command "Copy site key" cp /etc/tripwire/site.key "$TRIPWIRE_KEYS_DIR/"
            log_command "Copy local key" cp "/etc/tripwire/$(hostname)-local.key" "$TRIPWIRE_KEYS_DIR/"
            log_command "Secure keys directory" chmod 700 "$TRIPWIRE_KEYS_DIR"
            log_command "Secure key files" chmod 600 "$TRIPWIRE_KEYS_DIR"/*.key
            
            show_summary "Tripwire Keys Backup" \
                "Location: $TRIPWIRE_KEYS_DIR" \
                "Site key: $TRIPWIRE_KEYS_DIR/site.key" \
                "Local key: $TRIPWIRE_KEYS_DIR/$(hostname)-local.key" \
                "" \
                "Keep these backups secure!"
        fi
        
        # Initialize Tripwire database
        if confirm "Initialize Tripwire database now?" "y"; then
            print_status "Initializing Tripwire database..."
            tripwire --init 2>&1 | tee -a "$INTERACTIVE_LOG"
            print_success "Tripwire database initialized"
        fi
    else
        print_error "Tripwire installation failed"
        ((PACKAGES_FAILED++))
    fi
}

# Function to fix GeoIP installation
install_geoip_fixed() {
    print_section "GeoIP Dependencies"
    
    local geoip_packages=(
        "geoip-bin"
        "geoip-database" 
        "geoip-database-extra"
        "geoipupdate"
    )
    
    for pkg in "${geoip_packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            print_task "$pkg" "skip"
            ((PACKAGES_SKIPPED++))
        else
            print_status "Installing $pkg..."
            if log_command "Install $pkg" apt-get install -y "$pkg"; then
                print_task "$pkg" "success"
                ((PACKAGES_INSTALLED++))
            else
                print_task "$pkg" "warning"
                print_warning "Failed to install $pkg - GeoIP features may be limited"
                ((PACKAGES_FAILED++))
            fi
        fi
    done
    
    # Try to download GeoLite2 database if official packages fail
    if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ] && [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
        print_status "Downloading GeoLite2 database..."
        
        if log_command "Download GeoLite2" wget -q -O /tmp/GeoLite2-Country.mmdb \
            "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"; then
            
            log_command "Move GeoLite2 database" mv /tmp/GeoLite2-Country.mmdb /usr/share/GeoIP/
            log_command "Set permissions" chmod 644 /usr/share/GeoIP/GeoLite2-Country.mmdb
            print_success "GeoLite2 database downloaded"
        else
            print_warning "Could not download GeoLite2 database"
        fi
    fi
}

# Function to install security packages with progress
install_security_packages() {
    print_header "Installing Security Packages"
    
    local packages=(
        "ufw:Firewall"
        "fail2ban:Intrusion Prevention"
        "auditd:System Auditing"
        "apparmor:Access Control"
        "apparmor-utils:AppArmor Utils"
        "clamav:Antivirus Engine"
        "clamav-daemon:Antivirus Daemon"
        "clamav-freshclam:Virus Definitions"
        "rkhunter:Rootkit Hunter"
        "chkrootkit:Rootkit Scanner"
        "lynis:Security Auditing"
        "aide:File Integrity"
        "mailutils:Email Reports"
        "haveged:Entropy Daemon"
    )
    
    local total=${#packages[@]}
    local current=0
    
    print_info "Checking and installing ${total} security packages..."
    echo
    
    for pkg_desc in "${packages[@]}"; do
        local pkg="${pkg_desc%%:*}"
        local desc="${pkg_desc#*:}"
        
        ((current++))
        
        # Update progress line
        printf "\r${BLUE}[${current}/${total}]${NC} Processing: %-20s" "$desc"
        
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            ((PACKAGES_SKIPPED++))
            echo " [SKIP]"
            echo "[$desc] Package $pkg already installed" >> "$LOG_FILE"
        else
            echo " [INSTALLING]"
            if log_command "Install $pkg" apt-get install -y "$pkg"; then
                ((PACKAGES_INSTALLED++))
                printf "\r${BLUE}[${current}/${total}]${NC} %-30s ${GREEN}[✓]${NC}\n" "$desc"
            else
                ((PACKAGES_FAILED++))
                printf "\r${BLUE}[${current}/${total}]${NC} %-30s ${RED}[✗]${NC}\n" "$desc"
            fi
        fi
    done
    
    echo # New line after progress
    show_stats "$PACKAGES_INSTALLED" "$PACKAGES_FAILED" "$PACKAGES_SKIPPED"
}

# Function to configure services with visual feedback
configure_services() {
    print_header "Configuring Security Services"
    
    # ClamAV configuration
    print_section "ClamAV Antivirus"
    
    print_status "Stopping ClamAV for configuration..."
    log_command "Stop freshclam" systemctl stop clamav-freshclam || true
    
    print_status "Updating virus definitions..."
    if log_command "Update virus definitions" freshclam; then
        print_task "Virus definitions updated" "success"
    else
        print_task "Virus definitions update" "warning"
    fi
    
    log_command "Start freshclam" systemctl start clamav-freshclam
    print_task "ClamAV service started" "success"
    
    # Fail2ban configuration
    print_section "Fail2ban Configuration"
    
    if [ -f "$SCRIPT_DIR/configure-fail2ban.sh" ]; then
        print_status "Configuring Fail2ban rules..."
        if log_command "Configure fail2ban" bash "$SCRIPT_DIR/configure-fail2ban.sh"; then
            print_task "Fail2ban configured" "success"
        else
            print_task "Fail2ban configuration" "warning"
        fi
    fi
}

# Function to show final summary
show_final_summary() {
    local status="SUCCESS"
    if [ "$PACKAGES_FAILED" -gt 0 ]; then
        status="COMPLETED WITH WARNINGS"
    fi
    
    print_header "Installation $status"
    
    show_summary "Installation Summary" \
        "Packages installed: $PACKAGES_INSTALLED" \
        "Packages failed: $PACKAGES_FAILED" \
        "Packages skipped: $PACKAGES_SKIPPED" \
        "" \
        "Log file: $LOG_FILE" \
        "Interactive log: $INTERACTIVE_LOG"
    
    if [ -d "$TRIPWIRE_KEYS_DIR" ]; then
        echo
        show_warning_box "Tripwire Keys" \
            "Your Tripwire keys have been backed up to:\n$TRIPWIRE_KEYS_DIR\n\nStore these keys securely!"
    fi
    
    echo
    print_section "Next Steps"
    echo -e "  1. Review logs: ${CYAN}$LOG_FILE${NC}"
    echo -e "  2. Run verification: ${CYAN}sudo $SCRIPT_DIR/verify-installation.sh${NC}"
    echo -e "  3. Configure SSH: ${CYAN}sudo $SCRIPT_DIR/deploy-ssh-hardening.sh${NC}"
    echo -e "  4. Test security: ${CYAN}sudo $PROJECT_ROOT/common/monitoring/daily-security-scan.sh${NC}"
    echo
    
    if [ "$PACKAGES_FAILED" -gt 0 ]; then
        print_warning "Some packages failed to install. Review the log for details."
    fi
    
    # Log final summary
    {
        echo ""
        echo "Installation completed at: $(date)"
        echo "Status: $status"
        echo "Packages installed: $PACKAGES_INSTALLED"
        echo "Packages failed: $PACKAGES_FAILED"
        echo "Packages skipped: $PACKAGES_SKIPPED"
    } >> "$LOG_FILE"
}

# Main installation flow
main() {
    # Initial setup
    check_root_enhanced
    setup_logging_enhanced
    
    # Show welcome
    show_welcome
    
    # Update package lists
    print_section "System Preparation"
    print_status "Updating package lists..."
    if log_command "Update package lists" apt-get update; then
        print_task "Package lists updated" "success"
    else
        show_error_box "Update Failed" "Failed to update package lists"
        exit 1
    fi
    
    # Install packages
    install_security_packages
    
    # Handle special packages
    install_tripwire
    install_geoip_fixed
    
    # Configure services
    configure_services
    
    # Show summary
    show_final_summary
}

# Run main function
main "$@"