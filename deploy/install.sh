#!/bin/bash

# install.sh - Main installation script for Ubuntu Security Toolkit
# Enhanced version with proper logging, interactive handling, and UI

set -uo pipefail

# Script version
VERSION="3.0.0"

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
VERBOSE=false
UPDATE_PACKAGES=false

# Tripwire configuration
TRIPWIRE_SITE_KEY=""
TRIPWIRE_LOCAL_KEY=""
# No automatic key backups for security - users must backup manually
SKIP_TRIPWIRE=false
REINIT_TRIPWIRE=false

# Statistics
PACKAGES_INSTALLED=0
PACKAGES_FAILED=0
PACKAGES_SKIPPED=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --skip-tripwire)
            SKIP_TRIPWIRE=true
            shift
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --update|-u)
            UPDATE_PACKAGES=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v       Show detailed output"
            echo "  --skip-tripwire     Skip Tripwire installation"
            echo "  --non-interactive   Run without prompts"
            echo "  --update, -u        Update all security packages to latest versions"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to execute and log commands with real-time output
execute_with_log() {
    local description="$1"
    shift
    local command="$*"
    
    # Log command to file
    {
        echo "================== $(date '+%Y-%m-%d %H:%M:%S') =================="
        echo "Description: $description"
        echo "Command: $command"
        echo "==================== OUTPUT START ===================="
    } >> "$LOG_FILE"
    
    # Create temporary file for output capture
    local temp_output=$(mktemp)
    local exit_code=0
    
    if [ "$VERBOSE" = true ]; then
        # Show output in real-time and capture to file
        if eval "$command" 2>&1 | tee -a "$temp_output"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        # Hide output but still capture to file
        if eval "$command" > "$temp_output" 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    # Append output to log file
    cat "$temp_output" >> "$LOG_FILE"
    
    # Log completion
    {
        echo "==================== OUTPUT END ====================="
        echo "Exit code: $exit_code"
        echo "====================================================="
        echo ""
    } >> "$LOG_FILE"
    
    # Clean up
    rm -f "$temp_output"
    
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
        echo "User: ${SUDO_USER:-$USER}"
        echo "Script: $0 $*"
        echo "Options: VERBOSE=$VERBOSE, SKIP_TRIPWIRE=$SKIP_TRIPWIRE, INTERACTIVE=$INTERACTIVE"
        echo "=========================================="
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
    if [ "$SKIP_TRIPWIRE" = false ]; then
        echo -e "  ${CHECK_MARK} File integrity monitoring (Tripwire)"
    else
        echo -e "  ${GRAY}${CROSS_MARK} File integrity monitoring (Tripwire) - SKIPPED${NC}"
    fi
    echo
    echo "Installation options:"
    echo -e "  ${BULLET} Verbose output: ${VERBOSE}"
    echo -e "  ${BULLET} Interactive mode: ${INTERACTIVE}"
    echo -e "  ${BULLET} Log file: $LOG_FILE"
    echo
    
    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Ready to begin installation?" "y"; then
            print_info "Installation cancelled"
            exit 0
        fi
    else
        print_info "Starting non-interactive installation..."
        sleep 2
    fi
}

# Function to handle tripwire installation with improved interactive support
install_tripwire_improved() {
    print_section "Tripwire Installation"
    
    if [ "$SKIP_TRIPWIRE" = true ]; then
        print_task "Tripwire installation" "skip"
        print_info "Skipping Tripwire as requested"
        ((PACKAGES_SKIPPED++))
        return 0
    fi
    
    # Check if Tripwire is already installed
    local tripwire_installed=false
    local reinit_requested=false
    
    if dpkg -l tripwire 2>/dev/null | grep -q "^ii"; then
        tripwire_installed=true
        print_info "Tripwire is already installed"
        
        # Check if keys exist
        if [ -f "/etc/tripwire/site.key" ] && [ -f "/etc/tripwire/$(hostname)-local.key" ]; then
            print_warning "Existing Tripwire keys detected"
            echo
            echo -e "${YELLOW}Security Notice:${NC}"
            echo -e "  • Existing keys could be compromised if system was breached"
            echo -e "  • Reinitializing will create new keys and rebuild database"
            echo -e "  • Old keys will be permanently deleted"
            echo
            
            if confirm "Do you want to reinitialize Tripwire with new keys?" "n"; then
                reinit_requested=true
            else
                print_task "Keeping existing Tripwire configuration" "skip"
                ((PACKAGES_SKIPPED++))
                return 0
            fi
        else
            print_warning "Tripwire installed but keys are missing - will reconfigure"
            reinit_requested=true
        fi
    fi
    
    if [ "$INTERACTIVE" = false ]; then
        print_warning "Tripwire requires interactive setup - skipping in non-interactive mode"
        print_info "Run 'sudo apt-get install tripwire' manually to install"
        ((PACKAGES_SKIPPED++))
        return 0
    fi
    
    # Handle reinitialize request
    if [ "$reinit_requested" = true ] && [ "$tripwire_installed" = true ]; then
        print_header "Tripwire Reinitialization"
        echo
        print_warning "This will:"
        echo -e "  • Delete existing keys and configuration"
        echo -e "  • Generate new site and local keys"
        echo -e "  • Rebuild the Tripwire database from scratch"
        echo
        
        if confirm "Proceed with complete Tripwire reinitialization?" "y"; then
            print_status "Removing existing Tripwire configuration..."
            
            # Stop any running Tripwire processes
            execute_with_log "Stop Tripwire processes" pkill -f tripwire || true
            
            # Remove existing keys and database
            execute_with_log "Remove site key" rm -f /etc/tripwire/site.key
            execute_with_log "Remove local key" rm -f "/etc/tripwire/$(hostname)-local.key"
            execute_with_log "Remove Tripwire database" rm -f /var/lib/tripwire/*.twd
            execute_with_log "Remove reports" rm -rf /var/lib/tripwire/report/*
            
            print_success "Existing configuration removed"
            
            # Reconfigure Tripwire
            print_status "Reconfiguring Tripwire with new keys..."
            print_info "You will be prompted to create NEW passphrases"
            echo
            
            if dpkg-reconfigure tripwire < /dev/tty 2>&1 | tee -a "$INTERACTIVE_LOG"; then
                print_success "Tripwire reconfigured with new keys"
                tripwire_installed=true
            else
                print_error "Tripwire reconfiguration failed"
                ((PACKAGES_FAILED++))
                return 1
            fi
        else
            print_task "Tripwire reinitialization cancelled" "skip"
            ((PACKAGES_SKIPPED++))
            return 0
        fi
    elif [ "$tripwire_installed" = false ]; then
        # Fresh installation
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
    fi
    
    # Pre-configure debconf to reduce prompts
    echo "tripwire tripwire/use-sitekey boolean true" | debconf-set-selections
    echo "tripwire tripwire/use-localkey boolean true" | debconf-set-selections
    
    print_status "Installing Tripwire (interactive)..."
    print_info "Please follow the prompts to set up your passphrases"
    echo
    
    # Save current terminal settings
    local OLD_STTY=$(stty -g 2>/dev/null || true)
    
    # Install tripwire with proper terminal handling
    {
        echo "Installing Tripwire interactively at $(date)" 
        echo "User terminal: $(tty)"
    } >> "$INTERACTIVE_LOG"
    
    # Run installation with terminal attached
    if DEBIAN_FRONTEND=readline apt-get install -y tripwire < /dev/tty 2>&1 | tee -a "$INTERACTIVE_LOG"; then
        print_success "Tripwire installed successfully"
        ((PACKAGES_INSTALLED++))
        
        # Restore terminal settings
        stty "$OLD_STTY" 2>/dev/null || true
        
        # Display security warning about keys
        if [ -f "/etc/tripwire/site.key" ] && [ -f "/etc/tripwire/$(hostname)-local.key" ]; then
            echo
            show_summary "CRITICAL SECURITY NOTICE - TRIPWIRE KEYS" \
                "${RED}⚠ IMPORTANT: BACKUP YOUR KEYS NOW!${NC}" \
                "" \
                "Your Tripwire keys are located at:" \
                "  • Site key: /etc/tripwire/site.key" \
                "  • Local key: /etc/tripwire/$(hostname)-local.key" \
                "" \
                "${YELLOW}Security Best Practices:${NC}" \
                "  1. Backup these keys to SECURE OFFLINE storage immediately" \
                "  2. DO NOT keep key backups on this system" \
                "  3. Store keys separately from their passphrases" \
                "  4. If system is compromised, keys cannot be trusted" \
                "" \
                "To backup your keys manually:" \
                "  sudo cp /etc/tripwire/*.key /path/to/secure/usb/drive/" \
                "" \
                "${RED}Keys are NOT automatically backed up for security reasons${NC}"
            
            # Give user time to read and act on the warning
            echo
            print_warning "Please take a moment to securely backup your keys before continuing"
            if ! confirm "Have you backed up your Tripwire keys to secure offline storage?" "n"; then
                print_warning "Continuing without backup - keys may be lost if system fails!"
            fi
        fi
        
        # Initialize Tripwire database
        if confirm "Initialize Tripwire database now?" "y"; then
            print_status "Initializing Tripwire database..."
            print_info "You'll need to enter your local passphrase"
            if tripwire --init < /dev/tty 2>&1 | tee -a "$INTERACTIVE_LOG"; then
                print_success "Tripwire database initialized"
            else
                print_warning "Tripwire database initialization failed - run 'sudo tripwire --init' later"
            fi
        fi
    else
        print_error "Tripwire installation failed"
        ((PACKAGES_FAILED++))
        # Restore terminal settings
        stty "$OLD_STTY" 2>/dev/null || true
    fi
}

# Function to install GeoIP with improved error handling
install_geoip_improved() {
    print_section "GeoIP Dependencies"
    
    # Check Ubuntu version for package availability
    local ubuntu_version=$(lsb_release -rs)
    local geoip_packages=(
        "geoip-bin:GeoIP Binary"
        "geoip-database:GeoIP Database"
        "geoipupdate:GeoIP Updater"
    )
    
    # Add extra database only for older Ubuntu versions
    if [[ $(echo "$ubuntu_version < 24.04" | bc -l) -eq 1 ]]; then
        geoip_packages+=("geoip-database-extra:GeoIP Extra Data")
    fi
    
    local any_installed=false
    
    for pkg_desc in "${geoip_packages[@]}"; do
        local pkg="${pkg_desc%%:*}"
        local desc="${pkg_desc#*:}"
        
        if install_package_with_progress "$pkg" "$desc" "  "; then
            any_installed=true
        fi
    done
    
    # Verify GeoIP functionality
    print_status "Verifying GeoIP installation..."
    local geoip_working=false
    
    # Test basic GeoIP functionality
    if command -v geoiplookup >/dev/null 2>&1; then
        if geoiplookup 8.8.8.8 >/dev/null 2>&1; then
            geoip_working=true
            print_success "GeoIP is working correctly"
            
            # Show sample lookup
            local sample_result=$(geoiplookup 8.8.8.8 2>/dev/null)
            print_info "Sample lookup: $sample_result"
        fi
    fi
    
    # If basic GeoIP isn't working or we need GeoLite2 format
    if [ "$geoip_working" = false ] || [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
        print_warning "Installing GeoLite2 database for enhanced functionality..."
        
        if execute_with_log "Download GeoLite2" \
            "wget -q -O /tmp/GeoLite2-Country.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"; then
            
            execute_with_log "Create GeoIP directory" mkdir -p /usr/share/GeoIP
            execute_with_log "Move GeoLite2 database" mv /tmp/GeoLite2-Country.mmdb /usr/share/GeoIP/
            execute_with_log "Set permissions" chmod 644 /usr/share/GeoIP/GeoLite2-Country.mmdb
            print_success "GeoLite2 database installed"
        else
            print_warning "Could not download GeoLite2 database - some GeoIP features may be limited"
        fi
    fi
    
    # Make f2b-geoban script executable if it exists
    local f2b_script="$PROJECT_ROOT/common/fail2ban/f2b-geoban.sh"
    if [ -f "$f2b_script" ] && [ ! -x "$f2b_script" ]; then
        chmod +x "$f2b_script"
        print_info "Made f2b-geoban.sh executable"
    fi
    
    # Make update scripts executable
    local update_script="$PROJECT_ROOT/common/fail2ban/update-geoip.sh"
    local simple_update="$PROJECT_ROOT/common/fail2ban/update-geoip-simple.sh"
    
    if [ -f "$update_script" ] && [ ! -x "$update_script" ]; then
        chmod +x "$update_script"
        print_info "Made update-geoip.sh executable"
    fi
    
    if [ -f "$simple_update" ] && [ ! -x "$simple_update" ]; then
        chmod +x "$simple_update"
        print_info "Made update-geoip-simple.sh executable"
    fi
    
    # Setup GeoIP configuration
    print_status "Setting up GeoIP configuration..."
    
    # Copy example config if no config exists
    local config_dir="$PROJECT_ROOT/common/fail2ban"
    if [ ! -f "$config_dir/geoip-countries.conf" ] && [ -f "$config_dir/geoip-countries.conf.example" ]; then
        print_info "Creating GeoIP configuration from example"
        cp "$config_dir/geoip-countries.conf.example" "$config_dir/geoip-countries.conf"
    fi
    
    print_success "GeoIP tools configured"
    echo
    show_summary "GeoIP Configuration" \
        "IPdeny zone downloader is ready for use" \
        "" \
        "To configure country blocking:" \
        "  1. Edit: $config_dir/geoip-countries.conf" \
        "  2. Uncomment countries based on your security analysis" \
        "  3. Run: sudo $simple_update" \
        "" \
        "For guidance, see: $config_dir/README-GeoIP.md"
}

# Function to install a single package with progress feedback
install_package_with_progress() {
    local pkg="$1"
    local desc="$2"
    local status_prefix="$3"
    local force_update="${4:-false}"
    
    # Check if already installed
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        if [ "$force_update" = "true" ]; then
            # Update to latest version
            echo -ne "${status_prefix} ${desc} ${BLUE}[UPDATING]${NC}"
            if execute_with_log "Update $pkg" apt-get install -y --only-upgrade "$pkg"; then
                echo -e "\r${status_prefix} ${desc} ${GREEN}[UPDATED]${NC}                    "
                ((PACKAGES_INSTALLED++))
                return 0
            else
                echo -e "\r${status_prefix} ${desc} ${YELLOW}[CURRENT]${NC}                    "
                ((PACKAGES_SKIPPED++))
                return 0
            fi
        else
            echo -e "${status_prefix} ${desc} ${GRAY}[SKIP]${NC}"
            ((PACKAGES_SKIPPED++))
            return 0
        fi
    fi
    
    # Show installing status
    echo -ne "${status_prefix} ${desc} ${BLUE}[INSTALLING]${NC}"
    
    # Install package (always get latest version)
    if execute_with_log "Install $pkg" apt-get install -y "$pkg"; then
        # Move cursor back and show success
        echo -e "\r${status_prefix} ${desc} ${GREEN}[✓]${NC}                    "
        ((PACKAGES_INSTALLED++))
        return 0
    else
        # Move cursor back and show failure
        echo -e "\r${status_prefix} ${desc} ${RED}[✗]${NC}                    "
        ((PACKAGES_FAILED++))
        return 1
    fi
}

# Function to install security packages with improved progress display
install_security_packages_improved() {
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
    
    # Check if user wants to update already installed packages
    local update_existing="$UPDATE_PACKAGES"
    
    if [ "$UPDATE_PACKAGES" = true ]; then
        print_info "Update mode: Will update all packages to latest versions"
    elif [ "$PACKAGES_SKIPPED" -eq 0 ]; then
        # First run - check if any packages are already installed
        local installed_count=0
        for pkg_desc in "${packages[@]}"; do
            local pkg="${pkg_desc%%:*}"
            if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                ((installed_count++))
            fi
        done
        
        if [ "$installed_count" -gt 0 ]; then
            echo
            print_info "Found $installed_count security packages already installed"
            if [ "$INTERACTIVE" = true ] && confirm "Update all security packages to latest versions?" "y"; then
                update_existing=true
                print_info "Will update existing packages to latest versions"
            else
                print_info "Will skip already installed packages"
            fi
            echo
        fi
    fi
    
    print_info "Processing ${total} security packages..."
    echo
    
    for i in "${!packages[@]}"; do
        local pkg_desc="${packages[$i]}"
        local pkg="${pkg_desc%%:*}"
        local desc="${pkg_desc#*:}"
        local current=$((i + 1))
        local status_prefix="${BLUE}[${current}/${total}]${NC}"
        
        install_package_with_progress "$pkg" "$desc" "$status_prefix" "$update_existing"
    done
    
    echo
    show_stats "$PACKAGES_INSTALLED" "$PACKAGES_FAILED" "$PACKAGES_SKIPPED"
}

# Function to configure services with improved error handling
configure_services_improved() {
    print_header "Configuring Security Services"
    
    # ClamAV configuration
    print_section "ClamAV Antivirus"
    
    print_status "Stopping ClamAV for configuration..."
    execute_with_log "Stop freshclam" systemctl stop clamav-freshclam || true
    
    print_status "Updating virus definitions..."
    if execute_with_log "Update virus definitions" freshclam; then
        print_task "Virus definitions updated" "success"
    else
        print_task "Virus definitions update" "warning"
        print_info "You can update manually later with: sudo freshclam"
    fi
    
    execute_with_log "Start freshclam" systemctl start clamav-freshclam
    print_task "ClamAV service started" "success"
    
    # Fail2ban configuration
    print_section "Fail2ban Configuration"
    
    if [ -f "$SCRIPT_DIR/configure-fail2ban.sh" ]; then
        print_status "Configuring Fail2ban rules..."
        if execute_with_log "Configure fail2ban" bash "$SCRIPT_DIR/configure-fail2ban.sh"; then
            print_task "Fail2ban configured" "success"
        else
            print_task "Fail2ban configuration" "warning"
        fi
    else
        print_warning "Fail2ban configuration script not found"
    fi
    
    # Setup scheduled tasks
    print_section "Scheduled Security Tasks"
    
    # Create comprehensive cron jobs for all security tasks
    local cron_file="/etc/cron.d/ubuntu-security-toolkit"
    local cron_template="$SCRIPT_DIR/config/ubuntu-security-toolkit-cron"
    
    print_status "Setting up automated security scans and updates..."
    
    if [ -f "$cron_template" ]; then
        # Copy the cron template
        if sudo cp "$cron_template" "$cron_file"; then
            # Update paths in cron file to match actual installation
            sudo sed -i "s|/home/roctinam/ubuntu-setup|$PROJECT_ROOT|g" "$cron_file"
            
            # Set proper permissions
            sudo chmod 644 "$cron_file"
            sudo chown root:root "$cron_file"
            
            print_task "Security task scheduling configured" "success"
            
            # Show what was scheduled
            echo
            show_summary "Scheduled Security Tasks" \
                "Daily Tasks:" \
                "  • 1:00 AM - ClamAV quick scan" \
                "  • 3:00 AM - Comprehensive security scan" \
                "  • 4:00 AM - Fail2ban status check" \
                "  • 4:30 AM - Tripwire integrity check (if installed)" \
                "  • 4:45 AM - AIDE integrity check (if installed)" \
                "  • 5:00 AM - Disk space monitoring" \
                "  • 6:00 AM - Security updates check" \
                "" \
                "Weekly Tasks:" \
                "  • Sunday 2:00 AM - Full ClamAV system scan" \
                "  • Sunday 2:30 AM - GeoIP updates (if configured)" \
                "  • Saturday 2:00 AM - RKHunter database update" \
                "  • Monday 3:00 AM - Lynis security audit" \
                "" \
                "Monthly Tasks:" \
                "  • 1st of month 7:00 AM - Security summary report" \
                "" \
                "Logs: /var/log/ubuntu-security-toolkit/"
        else
            print_task "Cron job installation" "failed"
            print_warning "Failed to install cron jobs - you can install manually:"
            print_info "  sudo cp $cron_template /etc/cron.d/"
        fi
    else
        print_warning "Cron template not found at: $cron_template"
        print_info "Security tasks will need to be scheduled manually"
    fi
    
    # Make sure all referenced scripts are executable
    print_status "Making security scripts executable..."
    local scripts=(
        "$PROJECT_ROOT/common/monitoring/daily-security-scan.sh"
        "$PROJECT_ROOT/common/clamav/clamav-daily-scan.sh"
        "$PROJECT_ROOT/common/fail2ban/f2b-geoban.sh"
        "$PROJECT_ROOT/common/monitoring/generate-monthly-report.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            chmod +x "$script"
            print_info "Made $(basename "$script") executable"
        fi
    done
    
    # Enable and start services
    print_section "Enabling Security Services"
    
    local services=(
        "ufw:Firewall"
        "fail2ban:Intrusion Prevention"
        "clamav-daemon:Antivirus Daemon"
        "clamav-freshclam:Virus Update Service"
        "auditd:Audit Daemon"
        "apparmor:AppArmor"
        "haveged:Entropy Daemon"
    )
    
    for svc_desc in "${services[@]}"; do
        local svc="${svc_desc%%:*}"
        local desc="${svc_desc#*:}"
        
        if systemctl is-enabled "$svc" &>/dev/null; then
            print_task "$desc already enabled" "skip"
        else
            if execute_with_log "Enable $svc" systemctl enable "$svc"; then
                print_task "$desc enabled" "success"
            else
                print_task "$desc enable" "warning"
            fi
        fi
    done
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
    
    # Tripwire key reminder if installed
    if [ -f "/etc/tripwire/site.key" ] && [ -f "/etc/tripwire/$(hostname)-local.key" ]; then
        echo
        show_warning_box "Tripwire Keys Security Reminder" \
            "Remember to backup your Tripwire keys to secure offline storage!\n\nKeys are located at:\n/etc/tripwire/site.key\n/etc/tripwire/$(hostname)-local.key"
    fi
    
    echo
    print_section "Next Steps"
    echo -e "  1. Review logs: ${CYAN}$LOG_FILE${NC}"
    echo -e "  2. Run verification: ${CYAN}sudo $SCRIPT_DIR/verify-installation.sh${NC}"
    echo -e "  3. Configure SSH: ${CYAN}sudo $SCRIPT_DIR/deploy-ssh-hardening.sh${NC}"
    echo -e "  4. Test security: ${CYAN}sudo $PROJECT_ROOT/common/monitoring/daily-security-scan.sh${NC}"
    
    if [ "$SKIP_TRIPWIRE" = true ]; then
        echo -e "  5. Install Tripwire: ${CYAN}sudo apt-get install tripwire${NC}"
    fi
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

# Function to handle interrupt
handle_interrupt() {
    echo
    print_error "Installation interrupted by user"
    echo "Partial installation log: $LOG_FILE"
    exit 130
}

# Set up interrupt handler
trap handle_interrupt INT TERM

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
    
    if [ "$VERBOSE" = true ]; then
        print_info "Running: apt-get update"
    fi
    
    if execute_with_log "Update package lists" apt-get update; then
        print_task "Package lists updated" "success"
    else
        show_error_box "Update Failed" "Failed to update package lists\nCheck your internet connection and repository configuration"
        exit 1
    fi
    
    # Install packages
    install_security_packages_improved
    
    # Handle special packages
    install_tripwire_improved
    install_geoip_improved
    
    # Configure services
    configure_services_improved
    
    # Show summary
    show_final_summary
}

# Run main function
main "$@"