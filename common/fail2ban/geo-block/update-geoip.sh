#!/bin/bash

# Enhanced GeoIP update script with fixed logging and error handling

# Load configuration
source /etc/geo-block/config.conf

# Set timeout for downloads
DOWNLOAD_TIMEOUT=30
WGET_RETRIES=2

# Logging function - fixed to prevent duplication
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also output to console
    echo "[$timestamp] [$level] $message"
}

# Check if country is whitelisted
is_whitelisted() {
    local country=$1
    for wl in "${WHITELISTED_COUNTRIES[@]}"; do
        [[ "$country" == "$wl" ]] && return 0
    done
    return 1
}

# Load auto-blocked countries
load_auto_blocked() {
    if [ -f /etc/geo-block/auto-blocked.conf ]; then
        while IFS= read -r line; do
            [[ -n "$line" && ! "$line" =~ ^# ]] && BLOCKED_COUNTRIES+=("$line")
        done < /etc/geo-block/auto-blocked.conf
    fi
}

# Create backup of current rules
backup_current_rules() {
    local backup_dir="/var/backups/geo-block"
    sudo mkdir -p "$backup_dir"
    local backup_file="$backup_dir/ipset-backup-$(date +%Y%m%d-%H%M%S).conf"
    
    if sudo ipset list blocked-countries &>/dev/null; then
        sudo ipset save blocked-countries > "$backup_file"
        log "INFO" "Backed up current rules to $backup_file"
    fi
}

# Clean up any existing temporary ipset
cleanup_temp_ipset() {
    if sudo ipset list blocked-countries-new &>/dev/null; then
        log "INFO" "Cleaning up existing temporary ipset"
        sudo ipset destroy blocked-countries-new
    fi
}

# Test network connectivity
test_connectivity() {
    log "INFO" "Testing network connectivity"
    
    # Test DNS
    if ! host www.ipdeny.com >/dev/null 2>&1; then
        log "ERROR" "DNS resolution failed for www.ipdeny.com"
        return 1
    fi
    
    # Test HTTP connectivity
    if ! wget -q --spider --timeout=10 "https://www.ipdeny.com" 2>/dev/null; then
        log "ERROR" "Cannot reach www.ipdeny.com"
        return 1
    fi
    
    log "INFO" "Network connectivity OK"
    return 0
}

# Download country blocks with progress
download_country_blocks() {
    local country=$1
    local output_file="${country,,}.zone"
    local url="${UPDATE_SOURCES[0]}/${output_file}"
    
    log "INFO" "Downloading blocks for $country"
    
    # Download with progress dots
    local wget_output=$(mktemp)
    
    if wget --timeout="$DOWNLOAD_TIMEOUT" \
           --tries="$WGET_RETRIES" \
           --progress=dot:giga \
           -O "$output_file" \
           "$url" 2>&1 | tee "$wget_output" | while read line; do
        if [[ "$line" =~ \.\.\.\.\.\. ]]; then
            echo -n "."
        fi
    done; then
        echo ""  # New line after dots
        
        # Verify file has content
        if [ -s "$output_file" ]; then
            local lines=$(wc -l < "$output_file")
            log "INFO" "Downloaded $lines IP blocks for $country"
            rm -f "$wget_output"
            return 0
        else
            log "ERROR" "Downloaded file for $country is empty"
            rm -f "$output_file" "$wget_output"
            return 1
        fi
    else
        echo ""  # New line after dots
        log "ERROR" "Failed to download blocks for $country"
        # Show wget error
        tail -5 "$wget_output" | while read line; do
            log "DEBUG" "wget: $line"
        done
        rm -f "$wget_output"
        return 1
    fi
}

# Update geo IP blocks
update_blocks() {
    log "INFO" "Starting GeoIP update"
    
    # Test connectivity first
    if ! test_connectivity; then
        log "ERROR" "Network connectivity test failed. Aborting update."
        return 1
    fi
    
    # Clean up any existing temporary ipset
    cleanup_temp_ipset
    
    # Create temporary directory
    local tmp_dir=$(mktemp -d)
    if ! cd "$tmp_dir"; then
        log "ERROR" "Failed to create temporary directory"
        return 1
    fi
    
    # Create new ipset
    log "INFO" "Creating new ipset"
    if ! sudo ipset create blocked-countries-new hash:net maxelem 2097152 timeout 0; then
        log "ERROR" "Failed to create new ipset"
        cd /
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # Statistics
    local total_ips=0
    local blocked_count=0
    local failed_count=0
    local skipped_count=0
    
    # Load auto-blocked countries
    load_auto_blocked
    
    # Remove duplicates and whitelisted countries
    local unique_countries=()
    for country in "${BLOCKED_COUNTRIES[@]}"; do
        if ! is_whitelisted "$country"; then
            # Check if already in array
            local found=0
            for uc in "${unique_countries[@]}"; do
                [[ "$uc" == "$country" ]] && found=1 && break
            done
            [[ $found -eq 0 ]] && unique_countries+=("$country")
        else
            log "WARNING" "Skipping whitelisted country: $country"
            ((skipped_count++))
        fi
    done
    
    log "INFO" "Processing ${#unique_countries[@]} countries: ${unique_countries[*]}"
    
    # Download and process IP blocks
    for country in "${unique_countries[@]}"; do
        echo -n "Processing $country..."
        
        if download_country_blocks "$country"; then
            # Add IPs to ipset
            local added=0
            local file="${country,,}.zone"
            
            # Process file in chunks for better performance
            while IFS= read -r ip; do
                # Skip comments and empty lines
                [[ -z "$ip" || "$ip" =~ ^# ]] && continue
                
                # Validate IP format
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                    if sudo ipset add -exist blocked-countries-new "$ip" 2>/dev/null; then
                        ((added++))
                        ((total_ips++))
                    fi
                fi
                
                # Show progress every 100 IPs
                if ((added % 100 == 0)); then
                    echo -n "."
                fi
            done < "$file"
            
            echo " Added $added IPs"
            ((blocked_count++))
            
            # Clean up country file
            rm -f "$file"
        else
            ((failed_count++))
            # Try alternative source if primary fails
            log "WARNING" "Trying alternative source for $country"
            # Add alternative download logic here if needed
        fi
    done
    
    # Clean up temporary directory
    cd /
    rm -rf "$tmp_dir"
    
    # Check if we have any IPs
    local new_size=$(sudo ipset list blocked-countries-new 2>/dev/null | grep -c "^[0-9]" || echo 0)
    if [ "$new_size" -eq 0 ]; then
        log "ERROR" "No IPs were added to the new set. Aborting update."
        sudo ipset destroy blocked-countries-new
        return 1
    fi
    
    log "INFO" "New ipset contains $new_size entries"
    
    # Swap ipsets atomically
    log "INFO" "Swapping ipsets"
    if sudo ipset list blocked-countries &>/dev/null; then
        if sudo ipset swap blocked-countries-new blocked-countries; then
            sudo ipset destroy blocked-countries-new
            log "INFO" "Successfully swapped ipsets"
        else
            log "ERROR" "Failed to swap ipsets"
            sudo ipset destroy blocked-countries-new
            return 1
        fi
    else
        sudo ipset rename blocked-countries-new blocked-countries
        log "INFO" "Renamed new ipset to blocked-countries"
    fi
    
    # Save ipset
    sudo mkdir -p /etc/ipset.d
    if sudo ipset save blocked-countries > /etc/ipset.d/blocked-countries.conf; then
        log "INFO" "Saved ipset configuration"
    else
        log "ERROR" "Failed to save ipset configuration"
    fi
    
    log "INFO" "Update complete: $blocked_count countries processed, $failed_count failed, $total_ips IPs blocked"
    
    # Update iptables rules
    update_iptables_rules
    
    return 0
}

# Update iptables rules
update_iptables_rules() {
    log "INFO" "Updating iptables rules"
    
    # Remove existing geo-block rules
    local removed=0
    while sudo iptables -L INPUT -n --line-numbers | grep -q "GEO-BLOCK"; do
        local line=$(sudo iptables -L INPUT -n --line-numbers | grep "GEO-BLOCK" | head -1 | awk '{print $1}')
        sudo iptables -D INPUT "$line"
        ((removed++))
    done
    
    [ $removed -gt 0 ] && log "INFO" "Removed $removed existing rules"
    
    # Add rules for each protected service
    local added=0
    for port in "${PROTECTED_SERVICES[@]}"; do
        if sudo iptables -I INPUT -p tcp --dport "$port" -m set --match-set blocked-countries src -m comment --comment "GEO-BLOCK" -j DROP 2>/dev/null; then
            ((added++))
        fi
        if sudo iptables -I INPUT -p udp --dport "$port" -m set --match-set blocked-countries src -m comment --comment "GEO-BLOCK" -j DROP 2>/dev/null; then
            ((added++))
        fi
    done
    
    log "INFO" "Added $added iptables rules"
    
    # Save iptables rules
    if command -v netfilter-persistent &>/dev/null; then
        sudo netfilter-persistent save
    elif [ -f /etc/iptables/rules.v4 ]; then
        sudo iptables-save > /etc/iptables/rules.v4
    fi
    
    log "INFO" "iptables rules updated and saved"
}

# Signal handler for clean exit
cleanup_on_exit() {
    log "WARNING" "Update interrupted, cleaning up..."
    cleanup_temp_ipset
    exit 1
}

# Main execution
main() {
    # Check for root or sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Set up signal handlers
    trap cleanup_on_exit INT TERM
    
    # Lock file to prevent concurrent runs
    local lockfile="/var/run/geo-block-update.lock"
    exec 200>"$lockfile"
    
    if ! flock -n 200; then
        log "ERROR" "Another update is already running"
        exit 1
    fi
    
    # Start time
    local start_time=$(date +%s)
    
    # Backup current rules
    backup_current_rules
    
    # Update blocks
    if update_blocks; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "INFO" "Update completed successfully in $duration seconds"
    else
        log "ERROR" "Update failed"
        flock -u 200
        exit 1
    fi
    
    # Remove lock
    flock -u 200
}

# Run main
main "$@"
