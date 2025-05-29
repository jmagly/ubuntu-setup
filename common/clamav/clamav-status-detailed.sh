#!/bin/bash

# Dynamic script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use relative paths for script invocations
"$SCRIPT_DIR/clamav-log-analyzer.sh" json

echo "=== ClamAV Detailed Status ==="
echo "Date: $(date)"
echo ""

# Service Status
echo "Services:"
echo -n "  clamav-freshclam: "
if systemctl is-active --quiet clamav-freshclam; then
    echo -e "\033[32m✓ active\033[0m"
else
    echo -e "\033[31m✗ inactive\033[0m"
fi

echo -n "  clamav-daemon: "
if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
    echo -e "\033[32m✓ active\033[0m"
else
    status=$(systemctl is-enabled clamav-daemon 2>&1)
    if [[ $status == *"not-found"* ]] || [[ $status == *"No such"* ]]; then
        echo -e "\033[33m- not installed\033[0m"
    else
        echo -e "\033[31m✗ inactive\033[0m"
    fi
fi

# Database Status
echo ""
echo "Virus Database Status:"
for db in main daily bytecode; do
    if [ -f "/var/lib/clamav/$db.cvd" ]; then
        dbfile="/var/lib/clamav/$db.cvd"
    elif [ -f "/var/lib/clamav/$db.cld" ]; then
        dbfile="/var/lib/clamav/$db.cld"
    else
        echo "  $db: Not found"
        continue
    fi
    
    # Get database info
    version=$(sigtool --info $dbfile 2>/dev/null | grep "Version:" | awk '{print $2}')
    sigs=$(sigtool --info $dbfile 2>/dev/null | grep "Signatures:" | awk '{print $2}')
    built=$(sigtool --info $dbfile 2>/dev/null | grep "Build time:" | cut -d':' -f2- | xargs)
    
    echo "  $db.cvd:"
    echo "    Version: $version"
    echo "    Signatures: $(printf "%'d" $sigs 2>/dev/null || echo $sigs)"
    echo "    Built: $built"
done

# Total signatures
echo ""
total_sigs=$(clamscan --version 2>/dev/null | grep -oE '[0-9]+' | tail -1)
echo "Total Signatures: $(printf "%'d" $total_sigs 2>/dev/null || echo $total_sigs)"

# Last update
echo ""
echo "Last Update Check:"
last_update=$(sudo journalctl -u clamav-freshclam -n 100 | grep -E "daily.c[lv]d updated|main.c[lv]d updated|bytecode.c[lv]d updated|up-to-date" | tail -3)
if [ -n "$last_update" ]; then
    echo "$last_update" | while read line; do
        echo "  $line"
    done
else
    echo "  No recent update information"
fi

# Next update
echo ""
echo "Next Scheduled Check:"
next_check=$(sudo journalctl -u clamav-freshclam -n 50 | grep -i "next check" | tail -1 | cut -d':' -f4- | xargs)
if [ -n "$next_check" ]; then
    echo "  $next_check"
else
    echo "  Check interval: every 1 hour (24 checks/day)"
fi

# System resources
echo ""
echo "Resource Usage:"
if pgrep freshclam > /dev/null; then
    freshclam_pid=$(pgrep freshclam)
    freshclam_mem=$(ps -p $freshclam_pid -o rss= | awk '{print int($1/1024)"MB"}')
    echo "  freshclam: PID $freshclam_pid, Memory: $freshclam_mem"
fi

if pgrep clamd > /dev/null; then
    clamd_pid=$(pgrep clamd)
    clamd_mem=$(ps -p $clamd_pid -o rss= | awk '{print int($1/1024)"MB"}')
    echo "  clamd: PID $clamd_pid, Memory: $clamd_mem"
fi
