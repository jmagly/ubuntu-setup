#!/bin/bash
# Daily Security Scan Script

LOG_DIR="/var/log/security-scans"
DATE=$(date +%Y%m%d-%H%M%S)
REPORT="${LOG_DIR}/security-report-${DATE}.log"

mkdir -p ${LOG_DIR}

echo "=== Daily Security Scan Report - ${DATE} ===" > ${REPORT}
echo "" >> ${REPORT}

# Run RKHunter
echo "=== RKHunter Scan ===" >> ${REPORT}
rkhunter --check --skip-keypress --report-warnings-only >> ${REPORT} 2>&1

# Run ClamAV
echo -e "\n=== ClamAV Scan ===" >> ${REPORT}
clamscan -r -i / --exclude-dir="^/sys" --exclude-dir="^/proc" >> ${REPORT} 2>&1

# Run Chkrootkit
echo -e "\n=== Chkrootkit Scan ===" >> ${REPORT}
chkrootkit >> ${REPORT} 2>&1

# Run Lynis audit
echo -e "\n=== Lynis Audit ===" >> ${REPORT}
lynis audit system --quiet >> ${REPORT} 2>&1

# Check for failed login attempts
echo -e "\n=== Failed Login Attempts (Last 24 hours) ===" >> ${REPORT}
journalctl --since "24 hours ago" | grep "Failed password" >> ${REPORT} 2>&1

# Check active connections
echo -e "\n=== Active Network Connections ===" >> ${REPORT}
ss -tunlp >> ${REPORT} 2>&1

# Email report to admin
mail -s "Daily Security Report - $(hostname)" root@localhost < ${REPORT}
