#!/bin/bash

# ClamAV section for comprehensive security report
# This can be called by your main security report script

# Function to add to your main security report
add_clamav_report() {
    local format="${1:-text}"
    local report_file="${2:-/dev/stdout}"
    
    if [ "$format" = "json" ]; then
        # Get JSON output
        /usr/local/bin/clamav-log-analyzer.sh json
    else
        # Get text output with formatting
        {
            echo ""
            echo "=================================================================================="
            echo "                              ANTIVIRUS STATUS                                    "
            echo "=================================================================================="
            echo ""
            /usr/local/bin/clamav-log-analyzer.sh text
            echo ""
        } >> "$report_file"
    fi
}

# Function to get quick status for dashboard/summary
get_clamav_status() {
    local threats=$(/usr/local/bin/clamav-log-analyzer.sh json | jq -r '.clamav_report.summary.threats_found' 2>/dev/null || echo "0")
    local critical=$(/usr/local/bin/clamav-log-analyzer.sh json | jq -r '.clamav_report.summary.critical' 2>/dev/null || echo "0")
    local status="OK"
    
    [ "$critical" -gt 0 ] && status="CRITICAL"
    [ "$threats" -gt 0 ] && status="THREATS_FOUND"
    
    echo "$status"
}

# If called directly, run the report
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    add_clamav_report "$@"
fi
