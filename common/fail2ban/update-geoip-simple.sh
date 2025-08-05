#!/bin/bash

# update-geoip-simple.sh - Simple GeoIP database updater focusing on IPdeny data
# This script downloads country zone files from IPdeny for use with fail2ban

set -uo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPDENY_URL="https://www.ipdeny.com/ipblocks/data/countries"
GEOIP_DIR="/usr/share/GeoIP/zones"
LOG_FILE="/var/log/geoip-update.log"
CONFIG_FILE="$SCRIPT_DIR/geoip-countries.conf"
EXAMPLE_CONFIG="$SCRIPT_DIR/geoip-countries.conf.example"

# Default is empty - users must configure
DEFAULT_COUNTRIES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

# Create directories if needed
setup_directories() {
    echo -e "${YELLOW}Setting up directories...${NC}"
    
    # Create GeoIP zones directory
    if ! sudo mkdir -p "$GEOIP_DIR"; then
        echo -e "${RED}Failed to create $GEOIP_DIR${NC}"
        exit 1
    fi
    
    # Create log directory
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chmod 666 "$LOG_FILE" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Directories ready${NC}"
}

# Download country zone file
download_country() {
    local country="$1"
    local url="${IPDENY_URL}/${country}.zone"
    local output_file="${GEOIP_DIR}/${country}.zone"
    local temp_file="/tmp/${country}.zone.tmp"
    
    echo -n "  Downloading ${country^^}... "
    
    if wget -q -O "$temp_file" "$url" 2>/dev/null; then
        if [ -s "$temp_file" ]; then
            # Validate that file contains IP addresses
            if grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$temp_file"; then
                sudo mv "$temp_file" "$output_file"
                local count=$(wc -l < "$output_file")
                echo -e "${GREEN}✓${NC} ($count networks)"
                log "Downloaded ${country^^}: $count networks"
                return 0
            else
                echo -e "${RED}✗ Invalid content${NC}"
                rm -f "$temp_file"
                return 1
            fi
        else
            echo -e "${RED}✗ Empty file${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}✗ Download failed${NC}"
        rm -f "$temp_file"
        return 1
    fi
}

# Load countries from config file
load_country_config() {
    local countries=()
    
    if [ -f "$CONFIG_FILE" ]; then
        log "Loading country list from $CONFIG_FILE"
        
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Extract country code (remove comments and trim whitespace)
            local country=$(echo "$line" | cut -d'#' -f1 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
            
            # Skip if empty after removing comments
            [[ -z "$country" ]] && continue
            
            # Validate country code (2 letters)
            if [[ "$country" =~ ^[a-z]{2}$ ]]; then
                countries+=("$country")
            else
                log "Warning: Invalid country code: $line"
            fi
        done < "$CONFIG_FILE"
        
        if [ ${#countries[@]} -eq 0 ]; then
            echo -e "${YELLOW}No countries configured in $CONFIG_FILE${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Loaded ${#countries[@]} countries from configuration${NC}"
        DEFAULT_COUNTRIES=("${countries[@]}")
        return 0
    else
        return 1
    fi
}

# Update all configured countries
update_countries() {
    local countries=("${@:-${DEFAULT_COUNTRIES[@]}}")
    local success=0
    local failed=0
    
    echo -e "\n${YELLOW}Downloading IPdeny zone files...${NC}"
    
    for country in "${countries[@]}"; do
        if download_country "$country"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    echo -e "\n${GREEN}Summary: $success downloaded, $failed failed${NC}"
    
    # Create a combined file for easy access
    if [ "$success" -gt 0 ]; then
        echo -e "\n${YELLOW}Creating combined zone file...${NC}"
        sudo cat "$GEOIP_DIR"/*.zone 2>/dev/null | sort -u > /tmp/all-zones.tmp
        sudo mv /tmp/all-zones.tmp "$GEOIP_DIR/all-blocked.zone"
        local total=$(wc -l < "$GEOIP_DIR/all-blocked.zone")
        echo -e "${GREEN}✓ Combined file created with $total unique networks${NC}"
        log "Created combined file: $total networks from $success countries"
    fi
}

# Update legacy GeoIP databases if geoipupdate is available
update_legacy_geoip() {
    echo -e "\n${YELLOW}Updating legacy GeoIP databases...${NC}"
    
    if command -v geoipupdate &> /dev/null; then
        if sudo geoipupdate 2>/dev/null; then
            echo -e "${GREEN}✓ Legacy GeoIP databases updated${NC}"
            log "Updated legacy GeoIP databases"
        else
            echo -e "${YELLOW}⚠ Legacy GeoIP update failed (license key may be required)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ geoipupdate not available${NC}"
    fi
    
    # Update GeoLite2 if not present
    if [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
        echo -e "\n${YELLOW}Downloading GeoLite2 database...${NC}"
        if wget -q -O /tmp/GeoLite2-Country.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb; then
            sudo mv /tmp/GeoLite2-Country.mmdb /usr/share/GeoIP/
            echo -e "${GREEN}✓ GeoLite2 database installed${NC}"
            log "Downloaded GeoLite2 database"
        else
            echo -e "${YELLOW}⚠ GeoLite2 download failed${NC}"
        fi
    fi
}

# Create a sample fail2ban action configuration
create_fail2ban_config() {
    echo -e "\n${YELLOW}Creating fail2ban configuration...${NC}"
    
    local action_file="/etc/fail2ban/action.d/geoip-block.local"
    
    if [ ! -f "$action_file" ]; then
        sudo tee "$action_file" > /dev/null << 'EOF'
# Fail2Ban action configuration for GeoIP blocking
[Definition]
actionban = # Check country of IP
            COUNTRY=$(geoiplookup <ip> 2>/dev/null | awk -F': ' '{print $2}' | cut -d',' -f1)
            # Log the ban with country info
            echo "$(date): Banned <ip> from $COUNTRY" >> /var/log/fail2ban-geoip.log
EOF
        echo -e "${GREEN}✓ Created fail2ban GeoIP action${NC}"
    else
        echo -e "${GREEN}✓ Fail2ban GeoIP action already exists${NC}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}=== IPdeny GeoIP Update Script ===${NC}\n"
    
    # Check for root/sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo -e "${RED}This script requires sudo privileges${NC}"
        exit 1
    fi
    
    log "Starting GeoIP update"
    
    # Setup directories
    setup_directories
    
    # Handle country selection
    if [ $# -eq 0 ]; then
        # No arguments - try to load from config
        if ! load_country_config; then
            echo -e "${YELLOW}No configuration file found at: $CONFIG_FILE${NC}"
            echo -e "${YELLOW}Example configuration available at: $EXAMPLE_CONFIG${NC}"
            echo
            echo "To configure:"
            echo "  1. Copy the example: cp $EXAMPLE_CONFIG $CONFIG_FILE"
            echo "  2. Edit the file to uncomment countries you want to block"
            echo "  3. Run this script again"
            echo
            echo "Or specify countries directly: $0 cn ru ir"
            exit 1
        fi
    else
        # Countries specified on command line
        echo -e "${GREEN}Using countries from command line${NC}"
    fi
    
    # Update IPdeny zone files
    update_countries "$@"
    
    # Update legacy databases
    update_legacy_geoip
    
    # Create fail2ban config
    create_fail2ban_config
    
    echo -e "\n${GREEN}=== Update Complete ===${NC}"
    echo -e "\nZone files location: ${YELLOW}$GEOIP_DIR${NC}"
    echo -e "Combined blocklist: ${YELLOW}$GEOIP_DIR/all-blocked.zone${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    log "GeoIP update completed"
}

# Run main
main "$@"