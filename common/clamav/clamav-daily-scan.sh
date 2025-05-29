#!/bin/bash

# Dynamic script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use relative paths for script invocations
"$SCRIPT_DIR/clamav-manager.sh" scan /path/to/scan

LOGFILE="/var/log/clamav/daily-scan.log"
SCAN_DIRS="/home /root /var/www /opt"
EMAIL="root@localhost"

echo "=== ClamAV Daily Scan Started at $(date) ===" >> $LOGFILE

# Scan specified directories
for dir in $SCAN_DIRS; do
    if [ -d "$dir" ]; then
        echo "Scanning $dir..." >> $LOGFILE
        clamscan -ri --exclude-dir="^/sys|^/proc|^/dev" "$dir" >> $LOGFILE 2>&1
    fi
done

# Check for infections
INFECTIONS=$(grep -i "infected files:" $LOGFILE | tail -1 | awk '{print $3}')

if [ "$INFECTIONS" != "0" ] && [ -n "$INFECTIONS" ]; then
    echo "WARNING: $INFECTIONS infected files found!" | mail -s "ClamAV Alert on $(hostname)" $EMAIL
fi

echo "=== Scan completed at $(date) ===" >> $LOGFILE
