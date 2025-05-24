#!/bin/bash
# f2b-geoban.sh - Enhanced forensic information for banned IPs

# Check if we should include archived logs
include_archived=0
if [[ "$1" == "-a" || "$1" == "--all" ]]; then
    include_archived=1
fi

# Function to truncate text to specified length
truncate_text() {
    local text="$1"
    local max_length="$2"
    
    if [ ${#text} -gt $max_length ]; then
        echo "${text:0:$((max_length-3))}..."
    else
        echo "$text"
    fi
}

# Collect banned IPs with additional info
declare -A ip_count
declare -A ip_service
declare -A ip_first_seen
declare -A ip_last_seen

# Get log data - focusing specifically on Ban NOTICE entries
if [ $include_archived -eq 1 ]; then
    log_data=$(sudo zgrep "NOTICE.*Ban " /var/log/fail2ban.log*)
else
    log_data=$(sudo grep "NOTICE.*Ban " /var/log/fail2ban.log)
fi

# Process each ban entry
while read -r line; do
    # Extract IP address - more strictly matching
    ip=$(echo "$line" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    
    # Skip entries without valid IPs
    if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        continue
    fi
    
    # Extract timestamp without milliseconds
    timestamp=$(echo "$line" | awk '{print $1" "$2}' | sed 's/,[0-9]*$//')
    
    # Extract service (jail name) - looking specifically for [service] after NOTICE
    service=$(echo "$line" | grep -oE 'NOTICE[[:space:]]+\[[^]]+\]' | sed 's/NOTICE[[:space:]]*\[\([^]]*\)\]/\1/')
    
    # Update data structures
    if [ -n "${ip_count[$ip]}" ]; then
        ip_count[$ip]=$((ip_count[$ip] + 1))
    else
        ip_count[$ip]=1
        ip_first_seen[$ip]="$timestamp"
        ip_service[$ip]="$service"
    fi
    ip_last_seen[$ip]="$timestamp"
    
done <<< "$log_data"

# Print header with wider columns for dates
printf "%-5s %-15s %-20s %-12s %-19s %-19s %-30s\n" "Count" "IP Address" "Country" "Service" "First Seen" "Last Seen" "Hostname"
printf "%-5s %-15s %-20s %-12s %-19s %-19s %-30s\n" "-----" "---------------" "--------------------" "------------" "-------------------" "-------------------" "------------------------------"

# Generate output with timestamps for sorting
(for ip in "${!ip_count[@]}"; do
    # Get country and truncate if needed
    full_country=$(geoiplookup "$ip" 2>/dev/null | head -1 | sed -e 's/GeoIP Country Edition: //' -e 's/IP Address not found/Unknown/')
    country=$(truncate_text "$full_country" 20)
    
    # Get hostname (with timeout) - not truncated
    hostname=$(timeout 1 host "$ip" 2>/dev/null | grep "domain name" | awk '{print $NF}' | sed 's/\.$//' || echo "No PTR record")
    
    # Truncate service if needed
    service=$(truncate_text "${ip_service[$ip]}" 12)
    
    # Format for sorting - timestamp first, then print formatted row
    echo "${ip_last_seen[$ip]}|${ip_count[$ip]}|${ip}|${country}|${service}|${ip_first_seen[$ip]}|${ip_last_seen[$ip]}|${hostname}"
done) | sort -r | while IFS="|" read -r _ count ip country service first_seen last_seen hostname; do
    # Print formatted output
    printf "%-5s %-15s %-20s %-12s %-19s %-19s %s\n" "$count" "$ip" "$country" "$service" "$first_seen" "$last_seen" "$hostname"
done

echo ""
echo "Total unique IPs banned: ${#ip_count[@]}"
echo "Report generated: $(date)"
