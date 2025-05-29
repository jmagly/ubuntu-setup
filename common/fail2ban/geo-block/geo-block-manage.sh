#!/bin/bash

# Geo-block management script

# Load configuration
source /etc/geo-block/config.conf

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Show current status
show_status() {
    echo "=== Geo-Block Status ==="
    echo ""
    
    # Check if ipset exists
    if sudo ipset list blocked-countries &>/dev/null; then
        local ip_count=$(sudo ipset list blocked-countries | grep -c "^[0-9]")
        echo -e "IPSet: ${GREEN}Active${NC} ($ip_count IP blocks)"
    else
        echo -e "IPSet: ${RED}Not found${NC}"
    fi
    
    # Check iptables rules
    local rule_count=$(sudo iptables -L INPUT -n | grep -c "GEO-BLOCK")
    if [[ $rule_count -gt 0 ]]; then
        echo -e "Firewall Rules: ${GREEN}Active${NC} ($rule_count rules)"
    else
        echo -e "Firewall Rules: ${RED}Not found${NC}"
    fi
    
    echo ""
    echo "Configuration:"
    echo "  Manually blocked: ${#BLOCKED_COUNTRIES[@]} countries"
    
    if [ -f /etc/geo-block/auto-blocked.conf ]; then
        local auto_blocked=($(grep -v '^#' /etc/geo-block/auto-blocked.conf | grep -v '^$'))
        echo "  Auto-blocked: ${#auto_blocked[@]} countries"
    fi
    
    echo "  Whitelisted: ${#WHITELISTED_COUNTRIES[@]} countries"
    echo "  Protected ports: ${PROTECTED_SERVICES[*]}"
    echo ""
    
    # Show last update
    if [ -f "$LOG_FILE" ]; then
        local last_update=$(grep "Update complete" "$LOG_FILE" | tail -1)
        if [[ -n "$last_update" ]]; then
            echo "Last update: $(echo "$last_update" | awk -F'[][]' '{print $2}')"
        fi
    fi
}

# Add country to blocklist
add_country() {
    local country=$1
    
    # Validate country code
    if [[ ! "$country" =~ ^[A-Z]{2}$ ]]; then
        echo -e "${RED}Error: Invalid country code. Use ISO 3166-1 alpha-2 format (e.g., CN, RU)${NC}"
        return 1
    fi
    
    # Check if whitelisted
    if is_whitelisted "$country"; then
        echo -e "${YELLOW}Warning: $country is whitelisted. Remove from whitelist first.${NC}"
        return 1
    fi
    
    # Add to config
    sudo sed -i "/^BLOCKED_COUNTRIES=/,/^)/ s/^)$/    \"$country\"  # Added $(date +%Y-%m-%d)\n)/" /etc/geo-block/config.conf
    echo -e "${GREEN}Added $country to blocklist${NC}"
    
    # Update blocks
    /usr/local/bin/geo-block/update-geoip.sh
}

# Remove country from blocklist
remove_country() {
    local country=$1
    
    # Remove from config
    sudo sed -i "/^BLOCKED_COUNTRIES=/,/^)/ {/\"$country\"/d}" /etc/geo-block/config.conf
    
    # Remove from auto-blocked if present
    if [ -f /etc/geo-block/auto-blocked.conf ]; then
        sudo sed -i "/^$country$/d" /etc/geo-block/auto-blocked.conf
    fi
    
    echo -e "${GREEN}Removed $country from blocklist${NC}"
    
    # Update blocks
    /usr/local/bin/geo-block/update-geoip.sh
}

# Test if an IP would be blocked
test_ip() {
    local ip=$1
    
    if sudo ipset test blocked-countries "$ip" &>/dev/null; then
        echo -e "${RED}IP $ip would be BLOCKED${NC}"
        
        # Try to identify country
        if command -v geoiplookup &>/dev/null; then
            local country=$(geoiplookup "$ip" 2>/dev/null | head -1)
            echo "Country: $country"
        fi
    else
        echo -e "${GREEN}IP $ip would be ALLOWED${NC}"
    fi
}

# Main menu
case "${1:-status}" in
    status)
        show_status
        ;;
    add)
        add_country "$2"
        ;;
    remove)
        remove_country "$2"
        ;;
    update)
        /usr/local/bin/geo-block/update-geoip.sh
        ;;
    analyze)
        /usr/local/bin/geo-block/analyze-attacks.sh analyze
        ;;
    report)
        /usr/local/bin/geo-block/analyze-attacks.sh report
        ;;
    test)
        test_ip "$2"
        ;;
    list)
        echo "=== Blocked Countries ==="
        printf "%s\n" "${BLOCKED_COUNTRIES[@]}" | sort
        if [ -f /etc/geo-block/auto-blocked.conf ]; then
            echo ""
            echo "=== Auto-Blocked Countries ==="
            grep -v '^#' /etc/geo-block/auto-blocked.conf | grep -v '^$' | sort
        fi
        ;;
    whitelist)
        echo "=== Whitelisted Countries ==="
        printf "%s\n" "${WHITELISTED_COUNTRIES[@]}" | sort
        ;;
    *)
        echo "Geo-Block Management Tool"
        echo ""
        echo "Usage: $0 [command] [args]"
        echo ""
        echo "Commands:"
        echo "  status              Show current geo-block status"
        echo "  add <CC>           Add country to blocklist (2-letter code)"
        echo "  remove <CC>        Remove country from blocklist"
        echo "  update             Update IP blocks from sources"
        echo "  analyze            Analyze attacks and auto-block"
        echo "  report             Generate attack analysis report"
        echo "  test <IP>          Test if an IP would be blocked"
        echo "  list               List all blocked countries"
        echo "  whitelist          List whitelisted countries"
        ;;
esac
