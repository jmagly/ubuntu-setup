#!/bin/bash

# Analyze fail2ban logs and auto-block countries

# Load configuration
source /etc/geo-block/config.conf

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@" | sudo tee -a "$LOG_FILE"
}

# Analyze attacks by country
analyze_attacks() {
    log "INFO" "Analyzing attack patterns"
    
    # Get attack data from fail2ban logs
    local attack_data=$(/usr/local/bin/f2b-geoban.sh -a -f csv | tail -n +2)
    
    # Count total attacks
    local total_attacks=0
    declare -A country_attacks
    declare -A country_codes
    
    # Process attack data
    while IFS=',' read -r count ip country_full; do
        # Clean up country data
        country_full=$(echo "$country_full" | tr -d '"' | sed 's/^ *//;s/ *$//')
        count=$(echo "$count" | tr -d '"')
        
        # Extract country code (assuming format like "US United States")
        local country_code=$(echo "$country_full" | awk '{print $1}')
        
        # Skip if no valid country code
        if [[ ! "$country_code" =~ ^[A-Z]{2}$ ]]; then
            continue
        fi
        
        # Aggregate by country
        country_attacks["$country_code"]=$((${country_attacks["$country_code"]:-0} + count))
        country_codes["$country_code"]="$country_full"
        total_attacks=$((total_attacks + count))
    done <<< "$attack_data"
    
    # Analyze and create recommendations
    local new_blocks=()
    
    for country in "${!country_attacks[@]}"; do
        local attacks=${country_attacks[$country]}
        local percentage=$((attacks * 100 / total_attacks))
        
        # Check if country is already blocked or whitelisted
        local already_blocked=0
        for blocked in "${BLOCKED_COUNTRIES[@]}"; do
            [[ "$country" == "$blocked" ]] && already_blocked=1 && break
        done
        
        if is_whitelisted "$country"; then
            log "INFO" "Country $country has $attacks attacks ($percentage%) but is whitelisted"
            continue
        fi
        
        if [[ $already_blocked -eq 1 ]]; then
            continue
        fi
        
        # Check auto-block criteria
        if [[ $attacks -gt $AUTO_BLOCK_THRESHOLD ]] || [[ $percentage -gt $AUTO_BLOCK_PERCENTAGE ]]; then
            log "WARNING" "Country $country exceeds threshold: $attacks attacks ($percentage%)"
            new_blocks+=("$country")
        fi
    done
    
    # Return findings
    echo "${new_blocks[@]}"
}

# Update auto-blocked countries
update_auto_blocks() {
    local new_blocks=($@)
    
    if [[ ${#new_blocks[@]} -eq 0 ]]; then
        log "INFO" "No new countries to auto-block"
        return
    fi
    
    log "INFO" "Auto-blocking ${#new_blocks[@]} new countries: ${new_blocks[*]}"
    
    # Read existing auto-blocks
    local existing_blocks=()
    if [ -f /etc/geo-block/auto-blocked.conf ]; then
        while IFS= read -r line; do
            [[ -n "$line" && ! "$line" =~ ^# ]] && existing_blocks+=("$line")
        done < /etc/geo-block/auto-blocked.conf
    fi
    
    # Add new blocks
    {
        echo "# Auto-blocked countries based on attack analysis"
        echo "# Last updated: $(date)"
        echo ""
        
        # Combine existing and new
        for country in "${existing_blocks[@]}" "${new_blocks[@]}"; do
            echo "$country"
        done | sort -u
    } | sudo tee /etc/geo-block/auto-blocked.conf > /dev/null
    
    # Send notification
    if [[ "$NOTIFY_ON_AUTO_BLOCK" == "true" ]]; then
        {
            echo "Subject: [Geo-Block] New countries auto-blocked on $(hostname)"
            echo ""
            echo "The following countries have been automatically blocked due to excessive attacks:"
            echo ""
            for country in "${new_blocks[@]}"; do
                echo "  - $country: ${country_codes[$country]}"
                echo "    Attacks: ${country_attacks[$country]} ($(( ${country_attacks[$country]} * 100 / total_attacks ))%)"
            done
            echo ""
            echo "Total attacks analyzed: $total_attacks"
            echo ""
            echo "To review or modify, edit: /etc/geo-block/auto-blocked.conf"
        } | sendmail "$NOTIFY_EMAIL" 2>/dev/null || true
    fi
    
    # Trigger update
    /usr/local/bin/geo-block/update-geoip.sh
}

# Generate report
generate_report() {
    local attack_data=$(/usr/local/bin/f2b-geoban.sh -a -f csv | tail -n +2)
    
    echo "=== Geo-Block Attack Analysis Report ==="
    echo "Generated: $(date)"
    echo ""
    
    # Top attacking countries
    echo "Top 10 Attacking Countries:"
    echo "$attack_data" | awk -F',' '{
        gsub(/"/, "", $3)
        attacks[$3] += $1
    }
    END {
        for (country in attacks) {
            print attacks[country], country
        }
    }' | sort -nr | head -10 | while read count country; do
        printf "  %-40s %6d attacks\n" "$country" "$count"
    done
    
    echo ""
    echo "Current Configuration:"
    echo "  Blocked countries: ${#BLOCKED_COUNTRIES[@]}"
    echo "  Whitelisted countries: ${#WHITELISTED_COUNTRIES[@]}"
    echo "  Auto-block threshold: $AUTO_BLOCK_THRESHOLD attacks or $AUTO_BLOCK_PERCENTAGE%"
    
    # Check current blocks
    if [ -f /etc/geo-block/auto-blocked.conf ]; then
        local auto_blocked=($(grep -v '^#' /etc/geo-block/auto-blocked.conf | grep -v '^$'))
        echo "  Auto-blocked countries: ${#auto_blocked[@]}"
    fi
}

# Main execution
main() {
    case "${1:-analyze}" in
        analyze)
            if [[ "$AUTO_BLOCK_ENABLED" == "true" ]]; then
                new_blocks=$(analyze_attacks)
                if [[ -n "$new_blocks" ]]; then
                    update_auto_blocks $new_blocks
                fi
            else
                log "INFO" "Auto-blocking is disabled"
            fi
            ;;
        report)
            generate_report
            ;;
        *)
            echo "Usage: $0 [analyze|report]"
            exit 1
            ;;
    esac
}

main "$@"
