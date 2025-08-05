#!/bin/bash
# generate-monthly-report.sh - Generate monthly security summary report
# Part of Ubuntu Security Toolkit

set -euo pipefail

# Configuration
LOG_DIR="/var/log/ubuntu-security-toolkit"
REPORT_DIR="$LOG_DIR/monthly-reports"
DATE=$(date +%Y%m)
REPORT="$REPORT_DIR/security-summary-${DATE}.txt"
EMAIL_REPORT=true
EMAIL_RECIPIENT="root@localhost"

# Create report directory
mkdir -p "$REPORT_DIR"

# Start report
{
    echo "================================================================"
    echo "         Ubuntu Security Toolkit - Monthly Summary Report"
    echo "================================================================"
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "System: $(uname -a)"
    echo

    # === Failed Login Summary ===
    echo "=== Failed Login Attempts Summary ==="
    if [ -f /var/log/auth.log ]; then
        echo "Top 10 IPs with failed SSH attempts:"
        grep "Failed password" /var/log/auth.log* 2>/dev/null | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
            sort | uniq -c | sort -rn | head -10 || echo "No failed attempts found"
    fi
    echo

    # === Fail2ban Summary ===
    echo "=== Fail2ban Activity Summary ==="
    if command -v fail2ban-client &>/dev/null; then
        echo "Currently banned IPs:"
        sudo fail2ban-client status 2>/dev/null | grep "Jail list" || echo "Fail2ban not running"
        
        # Count bans from fail2ban log
        if [ -f /var/log/fail2ban.log ]; then
            echo
            echo "Monthly ban statistics:"
            grep "Ban" /var/log/fail2ban.log 2>/dev/null | wc -l | xargs echo "Total bans:"
        fi
    fi
    echo

    # === ClamAV Summary ===
    echo "=== ClamAV Scan Summary ==="
    if [ -d "$LOG_DIR" ]; then
        echo "Infections found this month:"
        grep -h "FOUND" "$LOG_DIR"/clamav-*.log 2>/dev/null | tail -20 || echo "No infections found"
        
        # Count total scans
        echo
        ls -1 "$LOG_DIR"/clamav-*.log 2>/dev/null | wc -l | xargs echo "Total scans performed:"
    fi
    echo

    # === RKHunter Summary ===
    echo "=== RKHunter Summary ==="
    if [ -f /var/log/rkhunter.log ]; then
        echo "Latest warnings:"
        grep -i "warning" /var/log/rkhunter.log 2>/dev/null | tail -10 || echo "No warnings"
    fi
    echo

    # === System Updates ===
    echo "=== Security Updates Status ==="
    echo "Available security updates:"
    apt-get upgrade -s 2>/dev/null | grep -i security | head -10 || echo "No security updates available"
    echo

    # === Disk Usage ===
    echo "=== Disk Usage ==="
    df -h | grep -E "^/dev|Filesystem"
    echo

    # === GeoIP Blocking Status ===
    echo "=== GeoIP Blocking Status ==="
    if [ -d /usr/share/GeoIP/zones ]; then
        echo "Active country blocks:"
        ls -1 /usr/share/GeoIP/zones/*.zone 2>/dev/null | wc -l | xargs echo "Countries blocked:"
        
        if [ -f /usr/share/GeoIP/zones/all-blocked.zone ]; then
            wc -l /usr/share/GeoIP/zones/all-blocked.zone | awk '{print "Total networks blocked: " $1}'
        fi
    else
        echo "GeoIP blocking not configured"
    fi
    echo

    # === Service Status ===
    echo "=== Security Service Status ==="
    for service in ufw fail2ban clamav-daemon auditd apparmor; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo "$service: Active"
        else
            echo "$service: Inactive or not installed"
        fi
    done
    echo

    # === Log File Sizes ===
    echo "=== Log File Status ==="
    echo "Security toolkit logs:"
    du -sh "$LOG_DIR"/*.log 2>/dev/null | tail -20 || echo "No logs found"
    echo

    echo "================================================================"
    echo "                    End of Monthly Report"
    echo "================================================================"
} > "$REPORT"

# Send email if configured
if [ "$EMAIL_REPORT" = true ] && command -v mail &>/dev/null; then
    cat "$REPORT" | mail -s "Security Monthly Report - $(hostname) - $(date +%B\ %Y)" "$EMAIL_RECIPIENT"
    echo "Report emailed to: $EMAIL_RECIPIENT"
fi

echo "Monthly report generated: $REPORT"