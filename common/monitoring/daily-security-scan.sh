#!/bin/bash
# daily-security-scan.sh - Comprehensive daily security scan for Ubuntu systems
# Part of Ubuntu Security Toolkit
# Runs multiple security scanners and generates a consolidated report

set -euo pipefail

# Script directory and common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")"))"

# Source dependency checking library
source "$PROJECT_ROOT/common/lib/dependency-check.sh" 2>/dev/null || {
    echo "Error: Cannot find dependency-check.sh library" >&2
    exit 1
}

# Configuration
LOG_DIR="/var/log/ubuntu-security-toolkit/security-scans"
DATE=$(date +%Y%m%d-%H%M%S)
REPORT="${LOG_DIR}/security-report-${DATE}.log"
EMAIL_REPORT=true
EMAIL_RECIPIENT="root@localhost"

# Pre-flight checks
if ! check_root; then
    exit 1
fi

# Check required dependencies
echo "Checking dependencies..."
REQUIRED_DEPS=(
    "rkhunter"
    "clamscan/clamav"
    "chkrootkit"
    "lynis"
    "ss/iproute2"
    "journalctl/systemd"
)

# Auto-install missing dependencies
if ! check_and_install_deps "${REQUIRED_DEPS[@]}"; then
    echo "Failed to install required dependencies. Run: sudo $PROJECT_ROOT/deploy/install-security-tools.sh"
    exit 1
fi

# Optional dependency for email reports
if ! command -v mail &> /dev/null; then
    echo -e "${YELLOW}[WARNING]${NC} Mail command not found - reports will be saved to file only"
    EMAIL_REPORT=false
fi

# Ensure log directory exists
ensure_log_dir "$LOG_DIR"

# Initialize report
echo "Ubuntu Security Toolkit - Daily Security Scan Report" > "${REPORT}"
echo "====================================================" >> "${REPORT}"
echo "Date: $(date)" >> "${REPORT}"
echo "Hostname: $(hostname)" >> "${REPORT}"
echo "System: $(uname -a)" >> "${REPORT}"
echo "" >> "${REPORT}"

# Function to run scan with error handling
run_scan() {
    local scanner="$1"
    local command="$2"
    
    echo -e "\n=== $scanner Scan ===" >> "${REPORT}"
    echo "Start time: $(date)" >> "${REPORT}"
    
    if eval "$command" >> "${REPORT}" 2>&1; then
        echo "Status: Completed successfully" >> "${REPORT}"
    else
        echo "Status: Completed with warnings/errors (exit code: $?)" >> "${REPORT}"
    fi
    
    echo "End time: $(date)" >> "${REPORT}"
}

# Run RKHunter
if command -v rkhunter &> /dev/null; then
    run_scan "RKHunter" "rkhunter --check --skip-keypress --report-warnings-only"
else
    echo -e "\n=== RKHunter Scan ===" >> "${REPORT}"
    echo "SKIPPED: rkhunter not installed" >> "${REPORT}"
fi

# Run ClamAV
if command -v clamscan &> /dev/null; then
    # Update virus definitions first (if freshclam is available)
    if command -v freshclam &> /dev/null && systemctl is-active clamav-freshclam &> /dev/null; then
        echo "Updating ClamAV virus definitions..." >> "${REPORT}"
        freshclam --quiet 2>&1 | head -20 >> "${REPORT}"
    fi
    
    # Run scan on critical directories
    SCAN_DIRS="/home /root /etc /usr/local /opt"
    run_scan "ClamAV" "clamscan --quiet --recursive --infected --exclude-dir='^/sys' --exclude-dir='^/proc' --exclude-dir='^/dev' --max-filesize=100M --max-scansize=100M $SCAN_DIRS"
else
    echo -e "\n=== ClamAV Scan ===" >> "${REPORT}"
    echo "SKIPPED: clamav not installed" >> "${REPORT}"
fi

# Run Chkrootkit
if command -v chkrootkit &> /dev/null; then
    run_scan "Chkrootkit" "chkrootkit -q"
else
    echo -e "\n=== Chkrootkit Scan ===" >> "${REPORT}"
    echo "SKIPPED: chkrootkit not installed" >> "${REPORT}"
fi

# Run Lynis audit
if command -v lynis &> /dev/null; then
    run_scan "Lynis Security Audit" "lynis audit system --quiet --no-colors"
else
    echo -e "\n=== Lynis Security Audit ===" >> "${REPORT}"
    echo "SKIPPED: lynis not installed" >> "${REPORT}"
fi

# Check for failed login attempts
echo -e "\n=== Failed Login Attempts (Last 24 hours) ===" >> "${REPORT}"
if command -v journalctl &> /dev/null; then
    failed_count=$(journalctl --since "24 hours ago" 2>/dev/null | grep -c "Failed password" || echo "0")
    echo "Total failed login attempts: $failed_count" >> "${REPORT}"
    
    if [ "$failed_count" -gt 0 ]; then
        echo "\nTop 10 IPs with failed login attempts:" >> "${REPORT}"
        journalctl --since "24 hours ago" 2>/dev/null | grep "Failed password" | \
            grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | \
            sort | uniq -c | sort -rn | head -10 >> "${REPORT}"
    fi
else
    echo "SKIPPED: journalctl not available" >> "${REPORT}"
fi

# Check active connections
echo -e "\n=== Active Network Connections ===" >> "${REPORT}"
if command -v ss &> /dev/null; then
    echo "Listening ports:" >> "${REPORT}"
    ss -tunlp 2>/dev/null | grep LISTEN >> "${REPORT}" || echo "No listening ports found" >> "${REPORT}"
    
    echo -e "\nEstablished connections:" >> "${REPORT}"
    established_count=$(ss -tun 2>/dev/null | grep -c ESTAB || echo "0")
    echo "Total established connections: $established_count" >> "${REPORT}"
    
    if [ "$established_count" -gt 0 ] && [ "$established_count" -lt 50 ]; then
        ss -tun 2>/dev/null | grep ESTAB | head -20 >> "${REPORT}"
    fi
else
    echo "SKIPPED: ss command not available" >> "${REPORT}"
fi

# Check system updates
echo -e "\n=== System Update Status ===" >> "${REPORT}"
if command -v apt-get &> /dev/null; then
    updates_available=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo "0")
    echo "Updates available: $updates_available" >> "${REPORT}"
    
    if [ "$updates_available" -gt 0 ]; then
        echo "Security updates:" >> "${REPORT}"
        apt-get -s upgrade 2>/dev/null | grep -i security | head -10 >> "${REPORT}"
    fi
fi

# Check disk usage
echo -e "\n=== Disk Usage ===" >> "${REPORT}"
df -h | grep -vE '^(tmpfs|devtmpfs|udev)' >> "${REPORT}"

# Check for suspicious processes
echo -e "\n=== Suspicious Process Check ===" >> "${REPORT}"
# Look for processes with deleted binaries
deleted_procs=$(ls -la /proc/*/exe 2>/dev/null | grep deleted | wc -l)
if [ "$deleted_procs" -gt 0 ]; then
    echo "WARNING: Found $deleted_procs processes with deleted executables" >> "${REPORT}"
    ls -la /proc/*/exe 2>/dev/null | grep deleted | head -10 >> "${REPORT}"
else
    echo "No processes with deleted executables found" >> "${REPORT}"
fi

# Summary
echo -e "\n=== Scan Summary ===" >> "${REPORT}"
echo "Report generated at: $(date)" >> "${REPORT}"
echo "Report location: ${REPORT}" >> "${REPORT}"

# Email report if available
if [ "$EMAIL_REPORT" = true ] && command -v mail &> /dev/null; then
    # Create summary for email subject
    warnings=$(grep -c "WARNING\|INFECTED\|Vulnerable" "${REPORT}" || echo "0")
    subject="Daily Security Report - $(hostname) - $(date +%Y-%m-%d)"
    
    if [ "$warnings" -gt 0 ]; then
        subject="[ATTENTION] $subject - $warnings warnings found"
    fi
    
    # Send email
    mail -s "$subject" "$EMAIL_RECIPIENT" < "${REPORT}" && \
        echo "Report emailed to $EMAIL_RECIPIENT" || \
        echo "Failed to email report"
fi

# Always show report location
echo -e "\n${GREEN}Security scan completed.${NC}"
echo "Report saved to: ${REPORT}"

# Show warning summary
if [ -f "${REPORT}" ]; then
    warnings=$(grep -c "WARNING\|INFECTED\|Vulnerable" "${REPORT}" || echo "0")
    if [ "$warnings" -gt 0 ]; then
        echo -e "${YELLOW}Found $warnings warnings/issues that need attention${NC}"
        exit 1
    else
        echo -e "${GREEN}No critical issues found${NC}"
        exit 0
    fi
fi
