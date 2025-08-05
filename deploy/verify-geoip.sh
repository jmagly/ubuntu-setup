#!/bin/bash

# verify-geoip.sh - Verify GeoIP installation and functionality

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== GeoIP Installation Verification ===${NC}"
echo

# Check installed packages
echo -e "${YELLOW}Installed GeoIP packages:${NC}"
dpkg -l | grep -i geoip | awk '{print "  • " $2 " (" $3 ")"}'
echo

# Check GeoIP databases
echo -e "${YELLOW}GeoIP databases:${NC}"
if [ -d "/usr/share/GeoIP" ]; then
    ls -lh /usr/share/GeoIP/ | grep -v "^total" | awk '{print "  • " $9 " (" $5 ")"}'
else
    echo -e "  ${RED}✗ GeoIP directory not found${NC}"
fi
echo

# Test geoiplookup command
echo -e "${YELLOW}Testing geoiplookup:${NC}"
if command -v geoiplookup >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ geoiplookup command found${NC}"
    
    # Test some IPs
    test_ips=(
        "8.8.8.8:Google DNS"
        "1.1.1.1:Cloudflare DNS"
        "93.184.216.34:example.com"
        "185.199.108.153:github.com"
    )
    
    echo -e "\n${YELLOW}Sample lookups:${NC}"
    for ip_info in "${test_ips[@]}"; do
        ip="${ip_info%%:*}"
        desc="${ip_info#*:}"
        result=$(geoiplookup "$ip" 2>/dev/null || echo "Lookup failed")
        echo -e "  • $ip ($desc): ${result#GeoIP Country Edition: }"
    done
else
    echo -e "  ${RED}✗ geoiplookup command not found${NC}"
fi
echo

# Check fail2ban integration
echo -e "${YELLOW}Fail2ban GeoIP integration:${NC}"
f2b_script="/home/roctinam/ubuntu-setup/common/fail2ban/f2b-geoban.sh"
if [ -f "$f2b_script" ]; then
    if [ -x "$f2b_script" ]; then
        echo -e "  ${GREEN}✓ f2b-geoban.sh is executable${NC}"
    else
        echo -e "  ${RED}✗ f2b-geoban.sh is not executable${NC}"
        echo -e "    Run: chmod +x $f2b_script"
    fi
else
    echo -e "  ${RED}✗ f2b-geoban.sh not found${NC}"
fi

# Check for GeoLite2 database
echo
echo -e "${YELLOW}GeoLite2 database (for enhanced features):${NC}"
if [ -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
    echo -e "  ${GREEN}✓ GeoLite2-Country.mmdb found${NC}"
    ls -lh /usr/share/GeoIP/GeoLite2-Country.mmdb | awk '{print "    Size: " $5 ", Modified: " $6 " " $7 " " $8}'
else
    echo -e "  ${YELLOW}⚠ GeoLite2-Country.mmdb not found${NC}"
    echo -e "    Some advanced GeoIP features may not work"
fi

# Check for IPdeny zone files
echo
echo -e "${YELLOW}IPdeny zone files:${NC}"
if [ -d "/usr/share/GeoIP/zones" ]; then
    zone_count=$(ls -1 /usr/share/GeoIP/zones/*.zone 2>/dev/null | wc -l)
    if [ "$zone_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓ $zone_count country zone files found${NC}"
        echo -e "  ${YELLOW}Available zones:${NC}"
        for zone in /usr/share/GeoIP/zones/*.zone; do
            if [ -f "$zone" ]; then
                country=$(basename "$zone" .zone | tr '[:lower:]' '[:upper:]')
                count=$(wc -l < "$zone")
                echo -e "    • $country: $count networks"
            fi
        done | head -10
        if [ "$zone_count" -gt 10 ]; then
            echo -e "    ... and $((zone_count - 10)) more"
        fi
        
        if [ -f "/usr/share/GeoIP/zones/all-blocked.zone" ]; then
            local total=$(wc -l < "/usr/share/GeoIP/zones/all-blocked.zone")
            echo -e "  ${GREEN}✓ Combined blocklist: $total networks${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ No zone files found${NC}"
        echo -e "    Run: sudo /home/roctinam/ubuntu-setup/common/fail2ban/update-geoip-simple.sh"
    fi
else
    echo -e "  ${RED}✗ IPdeny directory not found${NC}"
fi

# Check geoipupdate configuration
echo
echo -e "${YELLOW}GeoIP update configuration:${NC}"
if [ -f "/etc/GeoIP.conf" ]; then
    echo -e "  ${GREEN}✓ /etc/GeoIP.conf found${NC}"
    if grep -q "YOUR_LICENSE_KEY_HERE" /etc/GeoIP.conf 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ License key not configured${NC}"
        echo -e "    To enable automatic updates, register at https://www.maxmind.com"
    fi
else
    echo -e "  ${YELLOW}⚠ /etc/GeoIP.conf not found${NC}"
fi

# Check IPdeny zone files
echo
echo -e "${YELLOW}IPdeny zone files:${NC}"
if [ -d "/usr/share/GeoIP/zones" ]; then
    echo -e "  ${GREEN}✓ Zone directory found${NC}"
    
    if [ -f "/usr/share/GeoIP/zones/all-blocked.zone" ]; then
        total_ips=$(wc -l < "/usr/share/GeoIP/zones/all-blocked.zone")
        echo -e "  ${GREEN}✓ Combined blocklist: $total_ips networks${NC}"
    fi
    
    echo -e "\n  Available country zones:"
    for zone in /usr/share/GeoIP/zones/*.zone; do
        if [ -f "$zone" ] && [ "$zone" != "/usr/share/GeoIP/zones/all-blocked.zone" ]; then
            country=$(basename "$zone" .zone)
            count=$(wc -l < "$zone")
            echo -e "    • ${country^^}: $count networks"
        fi
    done
else
    echo -e "  ${YELLOW}⚠ IPdeny zone directory not found${NC}"
    echo -e "    Run: sudo /home/roctinam/ubuntu-setup/common/fail2ban/update-geoip-simple.sh"
fi

echo
echo -e "${BLUE}=== Verification Complete ===${NC}"