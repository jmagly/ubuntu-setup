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

# Check if Docker is running
DOCKER_RUNNING=false
if systemctl is-active --quiet docker; then
    DOCKER_RUNNING=true
fi

# IP forwarding check with Docker context
if [ $(sysctl -n net.ipv4.ip_forward) -eq 0 ]; then
    check_status 0 "IP forwarding disabled"
else
    if [ "$DOCKER_RUNNING" = true ]; then
        check_status 1 "IP forwarding ENABLED (Docker is active - this is expected)"
    else
        check_status 1 "IP forwarding ENABLED"
    fi
fi

# Reverse path filtering check with Docker context
if [ $(sysctl -n net.ipv4.conf.all.rp_filter) -eq 1 ]; then
    check_status 0 "Reverse path filtering enabled (strict mode)"
elif [ $(sysctl -n net.ipv4.conf.all.rp_filter) -eq 2 ]; then
    if [ "$DOCKER_RUNNING" = true ]; then
        check_status 1 "Reverse path filtering in loose mode (Docker is active - this is expected)"
    else
        check_status 1 "Reverse path filtering in loose mode"
    fi
else
    check_status 1 "Reverse path filtering NOT enabled"
fi

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
echo "6. Checking GeoIP Blocking..."
GEOIP_DIR="/usr/share/GeoIP/zones"
if [ -d "$GEOIP_DIR" ]; then
    # Count zone files (countries)
    COUNTRY_COUNT=$(find "$GEOIP_DIR" -name "*.zone" -not -name "all-blocked.zone" 2>/dev/null | wc -l)
    
    if [ "$COUNTRY_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[ACTIVE]${NC} GeoIP blocking enabled for $COUNTRY_COUNT countries"
        
        # List blocked countries
        echo "  Blocked countries:"
        for zone in "$GEOIP_DIR"/*.zone; do
            [ -f "$zone" ] || continue
            [ "$(basename "$zone")" = "all-blocked.zone" ] && continue
            
            country=$(basename "$zone" .zone | tr '[:lower:]' '[:upper:]')
            networks=$(wc -l < "$zone" 2>/dev/null || echo 0)
            printf "    - %s: %'d networks\n" "$country" "$networks"
        done | sort
        
        # Show total networks if combined file exists
        if [ -f "$GEOIP_DIR/all-blocked.zone" ]; then
            TOTAL_NETWORKS=$(wc -l < "$GEOIP_DIR/all-blocked.zone")
            printf "  Total networks blocked: %'d\n" "$TOTAL_NETWORKS"
        fi
    else
        echo -e "${YELLOW}[WARN]${NC} GeoIP blocking configured but no countries loaded"
    fi
else
    echo -e "${YELLOW}[INFO]${NC} GeoIP blocking not configured"
fi

echo ""
echo "=== Hardening Status Complete ==="
