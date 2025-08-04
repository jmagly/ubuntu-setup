#!/bin/bash

# verify-installation.sh - Verify Ubuntu Security Toolkit installation
# This script checks that all required components are properly installed and configured

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REQUIREMENTS_DIR="$SCRIPT_DIR/requirements"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_check() {
    echo -n "  Checking $1... "
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((CHECKS_PASSED++))
}

print_fail() {
    echo -e "${RED}FAIL${NC} - $1"
    ((CHECKS_FAILED++))
}

print_warning() {
    echo -e "${YELLOW}WARNING${NC} - $1"
    ((CHECKS_WARNING++))
}

print_info() {
    echo -e "  ${CYAN}INFO:${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Function to check if service is active
service_active() {
    systemctl is-active "$1" &> /dev/null
}

# Function to check if service is enabled
service_enabled() {
    systemctl is-enabled "$1" &> /dev/null
}

# Function to check file permissions
check_file_perms() {
    local file="$1"
    local expected_perms="$2"
    local actual_perms=$(stat -c "%a" "$file" 2>/dev/null)
    
    if [ "$actual_perms" = "$expected_perms" ]; then
        return 0
    else
        return 1
    fi
}

# Function to detect environment
detect_environment() {
    if [ -f /.dockerenv ] || grep -qa container=lxc /proc/1/environ 2>/dev/null; then
        IS_CONTAINER=true
    else
        IS_CONTAINER=false
    fi
}

# Detect environment
detect_environment

# Header
echo "Ubuntu Security Toolkit - Installation Verification"
echo "=================================================="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Environment: $([ "$IS_CONTAINER" = true ] && echo "Container" || echo "Bare Metal/VM")"
echo

# Check core system packages
print_header "Core System Packages"

CORE_PACKAGES=(
    "ufw"
    "fail2ban"
    "auditd"
    "apparmor"
    "apparmor-utils"
    "curl"
    "git"
)

for pkg in "${CORE_PACKAGES[@]}"; do
    print_check "$pkg"
    if package_installed "$pkg"; then
        print_pass
    else
        print_fail "Package not installed"
    fi
done

# Check security tools
print_header "Security Tools"

SECURITY_TOOLS=(
    "clamav"
    "clamav-daemon"
    "clamav-freshclam"
    "rkhunter"
    "chkrootkit"
    "lynis"
)

for tool in "${SECURITY_TOOLS[@]}"; do
    print_check "$tool"
    if package_installed "$tool"; then
        print_pass
    else
        print_fail "Not installed"
    fi
done

# Check entropy tools
print_header "Entropy Management"

if [ "$IS_CONTAINER" = true ]; then
    print_check "rng-tools (container environment)"
    if package_installed "rng-tools"; then
        print_pass
    else
        print_warning "rng-tools not installed - may have entropy issues in container"
    fi
else
    print_check "haveged (bare metal/VM environment)"
    if package_installed "haveged"; then
        print_pass
    else
        print_warning "haveged not installed - may have low entropy"
    fi
fi

# Check mail system
print_header "Mail System"

print_check "mail command"
if command_exists "mail"; then
    print_pass
    print_info "Mail system available for security reports"
else
    print_warning "No mail command - reports will be file-only"
fi

# Check GeoIP dependencies
print_header "GeoIP Support"

print_check "geoiplookup"
if command_exists "geoiplookup"; then
    print_pass
else
    print_warning "geoiplookup not installed - fail2ban geo-blocking limited"
fi

print_check "GeoIP database"
if [ -f "/usr/share/GeoIP/GeoIP.dat" ] || [ -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
    print_pass
else
    print_warning "No GeoIP database found"
fi

# Check services
print_header "System Services"

SERVICES=(
    "ufw:enabled:Firewall"
    "fail2ban:active:Intrusion Prevention"
    "auditd:active:System Auditing"
    "apparmor:active:Application Armor"
    "ssh:active:SSH Server"
    "clamav-freshclam:active:ClamAV Updates"
)

for service_check in "${SERVICES[@]}"; do
    IFS=':' read -r service status description <<< "$service_check"
    print_check "$description ($service)"
    
    if [ "$status" = "active" ]; then
        if service_active "$service"; then
            print_pass
        else
            print_fail "Service not active"
        fi
    elif [ "$status" = "enabled" ]; then
        if service_enabled "$service"; then
            print_pass
        else
            print_fail "Service not enabled"
        fi
    fi
done

# Check optional services
print_header "Optional Services"

print_check "ClamAV daemon"
if service_active "clamav-daemon"; then
    print_pass
    print_info "Real-time scanning enabled"
else
    print_warning "Not active - on-demand scanning only"
fi

# Check firewall rules
print_header "Firewall Configuration"

print_check "UFW status"
if ufw status | grep -q "Status: active"; then
    print_pass
    # Count rules
    rule_count=$(ufw status numbered | grep -c '^\[' || echo "0")
    print_info "$rule_count firewall rules configured"
else
    print_fail "Firewall not active"
fi

# Check fail2ban jails
print_header "Fail2ban Configuration"

print_check "Active jails"
if command_exists "fail2ban-client"; then
    jail_count=$(fail2ban-client status | grep "Number of jail" | awk '{print $NF}' || echo "0")
    if [ "$jail_count" -gt 0 ]; then
        print_pass
        print_info "$jail_count jails active"
    else
        print_warning "No active jails"
    fi
else
    print_fail "fail2ban-client not found"
fi

# Check script permissions
print_header "Script Permissions"

EXECUTABLE_SCRIPTS=(
    "$PROJECT_ROOT/common/monitoring/daily-security-scan.sh"
    "$PROJECT_ROOT/common/clamav/clamav-manager.sh"
    "$PROJECT_ROOT/common/fail2ban/f2b-geoban.sh"
    "$SCRIPT_DIR/install-all.sh"
    "$SCRIPT_DIR/install-security-tools.sh"
)

for script in "${EXECUTABLE_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        print_check "$(basename "$script")"
        if [ -x "$script" ]; then
            print_pass
        else
            print_fail "Not executable"
        fi
    fi
done

# Check log directory
print_header "Logging Configuration"

print_check "Log directory"
if [ -d "/var/log/ubuntu-security-toolkit" ]; then
    print_pass
else
    print_warning "Log directory not created"
fi

# Check cron jobs
print_header "Scheduled Tasks"

print_check "Security toolkit cron jobs"
if [ -f "/etc/cron.d/ubuntu-security-toolkit" ]; then
    print_pass
    print_info "Automated security scans configured"
else
    print_warning "No cron jobs configured"
fi

# Check ClamAV definitions
print_header "Antivirus Definitions"

print_check "ClamAV virus definitions"
if [ -d "/var/lib/clamav" ] && [ "$(find /var/lib/clamav -name "*.cv*" -o -name "*.cld" | wc -l)" -gt 0 ]; then
    print_pass
    # Get definition age
    if [ -f "/var/lib/clamav/daily.cvd" ] || [ -f "/var/lib/clamav/daily.cld" ]; then
        def_age=$(find /var/lib/clamav -name "daily.c*" -mtime +7 | wc -l)
        if [ "$def_age" -gt 0 ]; then
            print_warning "Virus definitions are older than 7 days"
        else
            print_info "Virus definitions are up to date"
        fi
    fi
else
    print_fail "No virus definitions found"
fi

# Check SSH hardening
print_header "SSH Configuration"

print_check "SSH hardening config"
if [ -f "/etc/ssh/sshd_config.d/99-hardening.conf" ]; then
    print_pass
    print_info "SSH hardening deployed"
else
    print_warning "SSH hardening not deployed"
fi

# Check entropy levels
print_header "System Entropy"

print_check "Available entropy"
if [ -f "/proc/sys/kernel/random/entropy_avail" ]; then
    entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    if [ "$entropy" -gt 1000 ]; then
        print_pass
        print_info "Entropy: $entropy bits"
    else
        print_warning "Low entropy: $entropy bits"
    fi
else
    print_fail "Cannot check entropy"
fi

# Summary
echo
echo "========================================================"
echo "                  Verification Summary"
echo "========================================================"
echo -e "Checks Passed:  ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks Failed:  ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings:       ${YELLOW}$CHECKS_WARNING${NC}"
echo

if [ "$CHECKS_FAILED" -eq 0 ]; then
    if [ "$CHECKS_WARNING" -eq 0 ]; then
        echo -e "${GREEN}All checks passed!${NC} The Ubuntu Security Toolkit is properly installed."
    else
        echo -e "${YELLOW}Installation complete with warnings.${NC} Review warnings above."
    fi
    exit 0
else
    echo -e "${RED}Installation verification failed!${NC} Please address the issues above."
    echo
    echo "To fix missing packages, run:"
    echo "  sudo $SCRIPT_DIR/install-all.sh"
    echo
    echo "For specific security tools:"
    echo "  sudo $SCRIPT_DIR/install-security-tools.sh"
    exit 1
fi