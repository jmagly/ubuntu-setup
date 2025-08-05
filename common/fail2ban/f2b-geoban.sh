#!/bin/bash
# f2b-geoban.sh - Enhanced fail2ban banned IPs analyzer with geolocation

# Dynamic script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use relative paths for script invocations
"$SCRIPT_DIR/update-geoip.sh"

# Script version
VERSION="2.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
INCLUDE_ARCHIVED=0
SHOW_JAIL_INFO=0
TOP_LIMIT=0
OUTPUT_FORMAT="table"
SHOW_TIME_RANGE=0

# Function to display usage
usage() {
    cat << EOF
Fail2ban Geolocation Analyzer v${VERSION}

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    -a, --all          Include archived logs
    -j, --jails        Show jail information
    -t, --top N        Show only top N entries
    -f, --format FMT   Output format: table (default), csv, json
    -r, --time-range   Show time range of bans
    -h, --help         Display this help message
    -v, --version      Display version information

EXAMPLES:
    $(basename "$0")                    # Show current log bans
    $(basename "$0") -a -j              # Show all bans with jail info
    $(basename "$0") -t 20 -f csv       # Top 20 in CSV format
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            INCLUDE_ARCHIVED=1
            shift
            ;;
        -j|--jails)
            SHOW_JAIL_INFO=1
            shift
            ;;
        -t|--top)
            TOP_LIMIT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -r|--time-range)
            SHOW_TIME_RANGE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "f2b-geoban version ${VERSION}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Function to check and install dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in geoiplookup jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing missing dependencies: ${missing_deps[*]}${NC}"
        sudo apt-get update -qq
        
        for dep in "${missing_deps[@]}"; do
            case $dep in
                geoiplookup)
                    sudo apt-get install -y geoip-bin geoip-database geoip-database-extra
                    ;;
                jq)
                    sudo apt-get install -y jq
                    ;;
            esac
        done
    fi
    
    # Check for GeoIP databases
    if [ ! -f /usr/share/GeoIP/GeoIP.dat ] && [ ! -f /usr/share/GeoIP/GeoLite2-Country.mmdb ]; then
        echo -e "${YELLOW}GeoIP database not found. Installing...${NC}"
        sudo apt-get install -y geoip-database geoip-database-extra
        
        # Try to update the database
        if command -v geoipupdate &> /dev/null; then
            sudo geoipupdate
        fi
    fi
}

# Function to get geolocation info with better error handling
get_geo_info() {
    local ip=$1
    local country="Unknown"
    local city=""
    
    # Check if geoiplookup is available
    if command -v geoiplookup &> /dev/null; then
        # Try to get country info
        local geo_output=$(geoiplookup "$ip" 2>&1)
        
        # Check if database exists and lookup succeeded
        if [[ ! "$geo_output" =~ "Can't open" ]] && [[ ! "$geo_output" =~ "not found" ]]; then
            # Extract country from various possible formats
            if [[ "$geo_output" =~ "GeoIP Country Edition:" ]]; then
                country=$(echo "$geo_output" | sed 's/GeoIP Country Edition: //' | cut -d',' -f2 | sed 's/^ *//')
            else
                # Handle other formats
                country=$(echo "$geo_output" | grep -v "^$" | head -1)
            fi
        fi
        
        # Try city database if available
        if [ -f /usr/share/GeoIP/GeoIPCity.dat ]; then
            local city_output=$(geoiplookup -f /usr/share/GeoIP/GeoIPCity.dat "$ip" 2>&1)
            if [[ ! "$city_output" =~ "Can't open" ]] && [[ ! "$city_output" =~ "not found" ]]; then
                city=$(echo "$city_output" | grep -oP '(?<=, )[^,]+(?=, [^,]+, [A-Z]{2})' | head -1 || echo "")
            fi
        fi
    fi
    
    # Clean up and validate output
    country=$(echo "$country" | tr -d '\n' | sed -e 's/IP Address not found/Unknown/' -e 's/^\s*//' -e 's/\s*$//')
    
    # If country is empty or just whitespace, set to Unknown
    if [ -z "$(echo "$country" | tr -d '[:space:]')" ]; then
        country="Unknown"
    fi
    
    # Handle common country codes
    case "$country" in
        "US") country="United States" ;;
        "CN") country="China" ;;
        "RU") country="Russia" ;;
        "GB") country="United Kingdom" ;;
        "DE") country="Germany" ;;
        "FR") country="France" ;;
        "JP") country="Japan" ;;
        "KR") country="South Korea" ;;
        "IN") country="India" ;;
        "BR") country="Brazil" ;;
    esac
    
    echo "${country}|${city}"
}

# Function to get ban details including jail
get_ban_details() {
    local search_cmd
    
    if [ $INCLUDE_ARCHIVED -eq 1 ]; then
        search_cmd="sudo zgrep -h 'Ban ' /var/log/fail2ban.log*"
    else
        search_cmd="sudo grep 'Ban ' /var/log/fail2ban.log"
    fi
    
    # Extract IP, jail, and timestamp information
    eval "$search_cmd" | while read -r line; do
        # Extract timestamp
        timestamp=$(echo "$line" | grep -oP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
        
        # Extract jail name
        jail=$(echo "$line" | grep -oP '\[\K[^\]]+(?=\])' | head -1)
        
        # Extract IP
        ip=$(echo "$line" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')
        
        if [ -n "$ip" ]; then
            echo "${ip}|${jail}|${timestamp}"
        fi
    done
}

# Function to analyze and aggregate data
analyze_bans() {
    local ban_data
    declare -A ip_counts
    declare -A ip_jails
    declare -A ip_first_seen
    declare -A ip_last_seen
    
    # Collect all ban data
    while IFS='|' read -r ip jail timestamp; do
        # Count occurrences
        ((ip_counts["$ip"]++))
        
        # Track jails
        if [ -n "$jail" ]; then
            if [ -z "${ip_jails[$ip]}" ]; then
                ip_jails["$ip"]="$jail"
            else
                # Add jail if not already present
                if [[ ! "${ip_jails[$ip]}" =~ "$jail" ]]; then
                    ip_jails["$ip"]="${ip_jails[$ip]},$jail"
                fi
            fi
        fi
        
        # Track time range
        if [ -n "$timestamp" ]; then
            if [ -z "${ip_first_seen[$ip]}" ] || [[ "$timestamp" < "${ip_first_seen[$ip]}" ]]; then
                ip_first_seen["$ip"]="$timestamp"
            fi
            if [ -z "${ip_last_seen[$ip]}" ] || [[ "$timestamp" > "${ip_last_seen[$ip]}" ]]; then
                ip_last_seen["$ip"]="$timestamp"
            fi
        fi
    done < <(get_ban_details)
    
    # Output aggregated data
    for ip in "${!ip_counts[@]}"; do
        echo "${ip_counts[$ip]}|$ip|${ip_jails[$ip]:-unknown}|${ip_first_seen[$ip]:-}|${ip_last_seen[$ip]:-}"
    done | sort -t'|' -k1 -nr
}

# Function to output in table format
output_table() {
    local data="$1"
    local count=0
    
    # Print header
    printf "${BLUE}"
    if [ $SHOW_JAIL_INFO -eq 1 ] && [ $SHOW_TIME_RANGE -eq 1 ]; then
        printf "%-6s %-15s %-30s %-20s %-19s %-19s\n" "Count" "IP Address" "Country" "Jail(s)" "First Seen" "Last Seen"
        printf "%-6s %-15s %-30s %-20s %-19s %-19s\n" "------" "---------------" "------------------------------" "--------------------" "-------------------" "-------------------"
    elif [ $SHOW_JAIL_INFO -eq 1 ]; then
        printf "%-6s %-15s %-30s %-20s\n" "Count" "IP Address" "Country" "Jail(s)"
        printf "%-6s %-15s %-30s %-20s\n" "------" "---------------" "------------------------------" "--------------------"
    elif [ $SHOW_TIME_RANGE -eq 1 ]; then
        printf "%-6s %-15s %-30s %-19s %-19s\n" "Count" "IP Address" "Country" "First Seen" "Last Seen"
        printf "%-6s %-15s %-30s %-19s %-19s\n" "------" "---------------" "------------------------------" "-------------------" "-------------------"
    else
        printf "%-6s %-15s %-30s\n" "Count" "IP Address" "Country"
        printf "%-6s %-15s %-30s\n" "------" "---------------" "------------------------------"
    fi
    printf "${NC}"
    
    # Process and display data
    echo "$data" | while IFS='|' read -r count ip jails first_seen last_seen; do
        # Get geolocation
        geo_info=$(get_geo_info "$ip")
        country=$(echo "$geo_info" | cut -d'|' -f1)
        city=$(echo "$geo_info" | cut -d'|' -f2)
        
        # Format location
        if [ -n "$city" ] && [ "$city" != "" ]; then
            location="${country}, ${city}"
        else
            location="$country"
        fi
        
        # Truncate long strings
        location=$(echo "$location" | cut -c1-30)
        jails=$(echo "$jails" | cut -c1-20)
        
        # Color coding for high counts
        if [ "$count" -gt 100 ]; then
            printf "${RED}"
        elif [ "$count" -gt 50 ]; then
            printf "${YELLOW}"
        fi
        
        # Output based on options
        if [ $SHOW_JAIL_INFO -eq 1 ] && [ $SHOW_TIME_RANGE -eq 1 ]; then
            printf "%-6s %-15s %-30s %-20s %-19s %-19s\n" "$count" "$ip" "$location" "$jails" "${first_seen:0:19}" "${last_seen:0:19}"
        elif [ $SHOW_JAIL_INFO -eq 1 ]; then
            printf "%-6s %-15s %-30s %-20s\n" "$count" "$ip" "$location" "$jails"
        elif [ $SHOW_TIME_RANGE -eq 1 ]; then
            printf "%-6s %-15s %-30s %-19s %-19s\n" "$count" "$ip" "$location" "${first_seen:0:19}" "${last_seen:0:19}"
        else
            printf "%-6s %-15s %-30s\n" "$count" "$ip" "$location"
        fi
        
        printf "${NC}"
        
        # Check limit
        ((count++))
        if [ $TOP_LIMIT -gt 0 ] && [ $count -ge $TOP_LIMIT ]; then
            break
        fi
    done
}

# Function to output in CSV format
output_csv() {
    local data="$1"
    local count=0
    
    # Print header
    echo -n "Count,IP Address,Country"
    [ $SHOW_JAIL_INFO -eq 1 ] && echo -n ",Jails"
    [ $SHOW_TIME_RANGE -eq 1 ] && echo -n ",First Seen,Last Seen"
    echo ""
    
    # Process data
    echo "$data" | while IFS='|' read -r count ip jails first_seen last_seen; do
        geo_info=$(get_geo_info "$ip")
        country=$(echo "$geo_info" | cut -d'|' -f1 | tr ',' ' ')
        
        echo -n "\"$count\",\"$ip\",\"$country\""
        [ $SHOW_JAIL_INFO -eq 1 ] && echo -n ",\"$jails\""
        [ $SHOW_TIME_RANGE -eq 1 ] && echo -n ",\"$first_seen\",\"$last_seen\""
        echo ""
        
        ((count++))
        if [ $TOP_LIMIT -gt 0 ] && [ $count -ge $TOP_LIMIT ]; then
            break
        fi
    done
}

# Function to output in JSON format
output_json() {
    local data="$1"
    local count=0
    local first=1
    
    echo "{"
    echo "  \"metadata\": {"
    echo "    \"generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "    \"include_archived\": $( [ $INCLUDE_ARCHIVED -eq 1 ] && echo "true" || echo "false" ),"
    echo "    \"hostname\": \"$(hostname)\""
    echo "  },"
    echo "  \"banned_ips\": ["
    
    echo "$data" | while IFS='|' read -r count ip jails first_seen last_seen; do
        geo_info=$(get_geo_info "$ip")
        country=$(echo "$geo_info" | cut -d'|' -f1)
        city=$(echo "$geo_info" | cut -d'|' -f2)
        
        [ $first -eq 0 ] && echo ","
        first=0
        
        echo -n "    {"
        echo -n "\"ip\": \"$ip\", "
        echo -n "\"count\": $count, "
        echo -n "\"country\": \"$country\""
        
        [ -n "$city" ] && echo -n ", \"city\": \"$city\""
        [ $SHOW_JAIL_INFO -eq 1 ] && echo -n ", \"jails\": \"$jails\""
        [ $SHOW_TIME_RANGE -eq 1 ] && echo -n ", \"first_seen\": \"$first_seen\", \"last_seen\": \"$last_seen\""
        
        echo -n "}"
        
        ((count++))
        if [ $TOP_LIMIT -gt 0 ] && [ $count -ge $TOP_LIMIT ]; then
            break
        fi
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Main execution
main() {
    # Check dependencies
    if ! check_dependencies; then
        echo -e "${RED}Error: Failed to install required dependencies${NC}"
        echo -e "${YELLOW}The script will continue but GeoIP lookups may not work${NC}"
        echo
    fi
    
    # Check if fail2ban is installed
    if ! command -v fail2ban-client &> /dev/null; then
        echo -e "${RED}Error: fail2ban is not installed${NC}"
        exit 1
    fi
    
    # Check if log file exists
    if [ ! -f /var/log/fail2ban.log ]; then
        echo -e "${RED}Error: /var/log/fail2ban.log not found${NC}"
        exit 1
    fi
    
    # Get and analyze ban data
    echo -e "${GREEN}Analyzing fail2ban logs...${NC}" >&2
    ban_data=$(analyze_bans)
    
    if [ -z "$ban_data" ]; then
        echo -e "${YELLOW}No banned IPs found${NC}"
        exit 0
    fi
    
    # Apply limit if specified
    if [ $TOP_LIMIT -gt 0 ]; then
        ban_data=$(echo "$ban_data" | head -n $TOP_LIMIT)
    fi
    
    # Output in requested format
    case $OUTPUT_FORMAT in
        csv)
            output_csv "$ban_data"
            ;;
        json)
            output_json "$ban_data"
            ;;
        *)
            output_table "$ban_data"
            ;;
    esac
    
    # Show summary
    if [ "$OUTPUT_FORMAT" = "table" ]; then
        total_ips=$(echo "$ban_data" | wc -l)
        total_bans=$(echo "$ban_data" | awk -F'|' '{sum+=$1} END {print sum}')
        echo ""
        echo -e "${GREEN}Summary: ${total_ips} unique IPs, ${total_bans} total bans${NC}"
        
        if [ $INCLUDE_ARCHIVED -eq 0 ]; then
            echo -e "${BLUE}Tip: Use -a flag to include archived logs${NC}"
        fi
    fi
}

# Run main function
main
