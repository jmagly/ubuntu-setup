#!/bin/bash

echo "=== Ubuntu Security Hardening Status ==="
date
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check function
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} $2"
    else
        echo -e "${RED}[FAIL]${NC} $2"
    fi
}

echo "1. Checking Kernel Parameters..."
[ $(sysctl -n kernel.dmesg_restrict) -eq 1 ] && check_status 0 "Kernel log access restricted" || check_status 1 "Kernel log access NOT restricted"
[ $(sysctl -n net.ipv4.tcp_syncookies) -eq 1 ] && check_status 0 "SYN cookies enabled" || check_status 1 "SYN cookies NOT enabled"
[ $(sysctl -n kernel.randomize_va_space) -eq 2 ] && check_status 0 "ASLR fully enabled" || check_status 1 "ASLR NOT fully enabled"

echo ""
echo "2. Checking Network Security..."
[ $(sysctl -n net.ipv4.ip_forward) -eq 0 ] && check_status 0 "IP forwarding disabled" || check_status 1 "IP forwarding ENABLED"
[ $(sysctl -n net.ipv4.conf.all.rp_filter) -eq 1 ] && check_status 0 "Reverse path filtering enabled" || check_status 1 "Reverse path filtering NOT enabled"

echo ""
echo "3. Checking Services..."
systemctl is-active --quiet ufw && check_status 0 "Firewall (UFW) active" || check_status 1 "Firewall NOT active"
systemctl is-active --quiet fail2ban && check_status 0 "Fail2ban active" || check_status 1 "Fail2ban NOT active"
systemctl is-active --quiet auditd && check_status 0 "Auditd active" || check_status 1 "Auditd NOT active"

echo ""
echo "4. Checking Updates..."
UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst")
[ $UPDATES -eq 0 ] && check_status 0 "System up to date" || check_status 1 "$UPDATES updates available"

echo ""
echo "5. Checking Failed Logins (last 24h)..."
FAILED=$(journalctl --since "24 hours ago" 2>/dev/null | grep -c "Failed password" || echo 0)
echo "Failed login attempts: $FAILED"

echo ""
echo "=== Hardening Status Complete ==="
