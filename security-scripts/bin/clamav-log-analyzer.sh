#!/bin/bash

# ClamAV Log Analyzer for Security Reports
# This script analyzes ClamAV logs and outputs a formatted report section

# Variables
FRESHCLAM_LOG="/var/log/clamav/freshclam.log"
SCAN_LOG="/var/log/clamav/daily-scan.log"
DAYS_TO_CHECK=7
REPORT_FORMAT="${1:-text}"  # text or json

# Colors for text output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Initialize counters
THREATS_FOUND=0
UPDATE_ERRORS=0
SCAN_ERRORS=0
WARNING_COUNT=0
CRITICAL_COUNT=0

# Function to analyze freshclam logs
analyze_freshclam_logs() {
    local issues=()
    local last_update=""
    local update_failures=0
    
    if [ -f "$FRESHCLAM_LOG" ]; then
        # Check for update errors in the last N days
        update_failures=$(grep -i "error\|failed\|can't" "$FRESHCLAM_LOG" 2>/dev/null | \
            grep -v "Ignoring deprecated" | \
            awk -v date="$(date -d "$DAYS_TO_CHECK days ago" '+%a %b %d')" '$0 >= date' | \
            wc -l)
        
        # Get last successful update
        last_update=$(grep -E "Database updated|up-to-date" "$FRESHCLAM_LOG" 2>/dev/null | tail -1)
        
        # Check for connection issues
        connection_errors=$(grep -i "connection\|timeout\|refused" "$FRESHCLAM_LOG" 2>/dev/null | \
            awk -v date="$(date -d "$DAYS_TO_CHECK days ago" '+%a %b %d')" '$0 >= date' | \
            wc -l)
        
        # Check for mirror issues
        mirror_errors=$(grep -i "mirror\|403\|404\|500" "$FRESHCLAM_LOG" 2>/dev/null | \
            awk -v date="$(date -d "$DAYS_TO_CHECK days ago" '+%a %b %d')" '$0 >= date' | \
            wc -l)
        
        UPDATE_ERRORS=$((update_failures + connection_errors + mirror_errors))
        
        if [ $UPDATE_ERRORS -gt 0 ]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
            issues+=("Update errors detected: $UPDATE_ERRORS total ($update_failures failures, $connection_errors connection issues, $mirror_errors mirror issues)")
        fi
    else
        issues+=("Freshclam log file not found")
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    echo "${issues[@]}"
    echo "LAST_UPDATE:$last_update"
}

# Function to analyze scan logs
analyze_scan_logs() {
    local issues=()
    local infected_files=()
    local scan_warnings=()
    
    # Check system journals for clamscan results
    if command -v journalctl >/dev/null 2>&1; then
        # Look for infected files in journal
        infected_from_journal=$(sudo journalctl -u 'clam*' --since="$DAYS_TO_CHECK days ago" 2>/dev/null | \
            grep -i "found\|infected\|virus\|malware" | \
            grep -v "Infected files: 0" | \
            grep -v "PUA" || true)
        
        if [ -n "$infected_from_journal" ]; then
            while IFS= read -r line; do
                infected_files+=("$line")
                THREATS_FOUND=$((THREATS_FOUND + 1))
            done <<< "$infected_from_journal"
        fi
    fi
    
    # Check scan log if exists
    if [ -f "$SCAN_LOG" ]; then
        # Extract infected files
        infected_from_log=$(grep -i "FOUND" "$SCAN_LOG" 2>/dev/null | \
            grep -v "Infected files: 0" | \
            tail -20 || true)
        
        if [ -n "$infected_from_log" ]; then
            while IFS= read -r line; do
                infected_files+=("$line")
                THREATS_FOUND=$((THREATS_FOUND + 1))
            done <<< "$infected_from_log"
        fi
        
        # Check for scan errors
        scan_errors=$(grep -iE "error|failed|denied|cannot" "$SCAN_LOG" 2>/dev/null | \
            grep -v "Infected files: 0" | \
            wc -l)
        
        if [ $scan_errors -gt 0 ]; then
            SCAN_ERRORS=$scan_errors
            WARNING_COUNT=$((WARNING_COUNT + 1))
            scan_warnings+=("Scan errors detected: $scan_errors")
        fi
    fi
    
    # Check for PUA (Potentially Unwanted Applications)
    pua_detections=$(sudo journalctl -u 'clam*' --since="$DAYS_TO_CHECK days ago" 2>/dev/null | \
        grep -i "PUA" | wc -l || echo 0)
    
    if [ $pua_detections -gt 0 ]; then
        scan_warnings+=("PUA detections: $pua_detections")
    fi
    
    if [ $THREATS_FOUND -gt 0 ]; then
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi
    
    echo "INFECTED:${infected_files[@]}"
    echo "WARNINGS:${scan_warnings[@]}"
}

# Function to check ClamAV service health
check_service_health() {
    local health_issues=()
    
    # Check freshclam service
    if ! systemctl is-active --quiet clamav-freshclam 2>/dev/null; then
        health_issues+=("ClamAV Freshclam service is not running")
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi
    
    # Check database age
    for db in main daily; do
        db_file="/var/lib/clamav/${db}.cvd"
        [ -f "/var/lib/clamav/${db}.cld" ] && db_file="/var/lib/clamav/${db}.cld"
        
        if [ -f "$db_file" ]; then
            db_age=$(( ($(date +%s) - $(stat -c %Y "$db_file")) / 86400 ))
            if [ "$db" = "daily" ] && [ $db_age -gt 2 ]; then
                health_issues+=("Daily database is $db_age days old (should be <2)")
                WARNING_COUNT=$((WARNING_COUNT + 1))
            elif [ "$db" = "main" ] && [ $db_age -gt 90 ]; then
                health_issues+=("Main database is $db_age days old")
                WARNING_COUNT=$((WARNING_COUNT + 1))
            fi
        else
            health_issues+=("${db} database not found")
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
    done
    
    # Check for recent crashes or restarts
    recent_restarts=$(sudo journalctl -u clamav-freshclam --since="$DAYS_TO_CHECK days ago" 2>/dev/null | \
        grep -c "Started\|Stopped" || echo 0)
    
    if [ $recent_restarts -gt 10 ]; then
        health_issues+=("Excessive service restarts detected: $recent_restarts")
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    echo "${health_issues[@]}"
}

# Function to generate summary statistics
generate_statistics() {
    local stats=()
    
    # Get total signatures
    total_sigs=$(clamscan --version 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "unknown")
    
    # Get scan statistics if available
    if [ -f "$SCAN_LOG" ]; then
        last_scan_stats=$(grep -E "Scanned files:|Data scanned:|Time:" "$SCAN_LOG" 2>/dev/null | tail -3)
        stats+=("$last_scan_stats")
    fi
    
    stats+=("Total signatures: $total_sigs")
    stats+=("Threats found in last $DAYS_TO_CHECK days: $THREATS_FOUND")
    stats+=("Update errors: $UPDATE_ERRORS")
    stats+=("Scan errors: $SCAN_ERRORS")
    
    echo "${stats[@]}"
}

# Main report generation
generate_report() {
    local freshclam_analysis=$(analyze_freshclam_logs)
    local scan_analysis=$(analyze_scan_logs)
    local health_check=$(check_service_health)
    local statistics=$(generate_statistics)
    
    # Extract specific data
    local last_update=$(echo "$freshclam_analysis" | grep "LAST_UPDATE:" | cut -d: -f2-)
    local infected_files=$(echo "$scan_analysis" | grep "INFECTED:" | cut -d: -f2-)
    local scan_warnings=$(echo "$scan_analysis" | grep "WARNINGS:" | cut -d: -f2-)
    
    if [ "$REPORT_FORMAT" = "json" ]; then
        # JSON output for integration
        cat << EOF
{
  "clamav_report": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "period_days": $DAYS_TO_CHECK,
    "summary": {
      "threats_found": $THREATS_FOUND,
      "update_errors": $UPDATE_ERRORS,
      "scan_errors": $SCAN_ERRORS,
      "warnings": $WARNING_COUNT,
      "critical": $CRITICAL_COUNT
    },
    "status": {
      "severity": $([ $CRITICAL_COUNT -gt 0 ] && echo '"critical"' || [ $WARNING_COUNT -gt 0 ] && echo '"warning"' || echo '"ok"'),
      "freshclam_active": $(systemctl is-active --quiet clamav-freshclam && echo 'true' || echo 'false'),
      "last_update": "$last_update"
    },
    "issues": {
      "infected_files": $([ -n "$infected_files" ] && echo "[\"$infected_files\"]" || echo "[]"),
      "scan_warnings": $([ -n "$scan_warnings" ] && echo "[\"$scan_warnings\"]" || echo "[]"),
      "health_issues": $([ -n "$health_check" ] && echo "[\"$health_check\"]" || echo "[]")
    }
  }
}
EOF
    else
        # Text output for human reading
        echo "=== ClamAV Security Report ==="
        echo "Report Period: Last $DAYS_TO_CHECK days"
        echo "Generated: $(date)"
        echo ""
        
        # Summary with color coding
        echo "Summary:"
        if [ $CRITICAL_COUNT -gt 0 ]; then
            echo -e "  Status: ${RED}CRITICAL${NC} - Immediate attention required"
        elif [ $WARNING_COUNT -gt 0 ]; then
            echo -e "  Status: ${YELLOW}WARNING${NC} - Review recommended"
        else
            echo -e "  Status: ${GREEN}OK${NC} - No issues detected"
        fi
        
        echo "  Threats Found: $THREATS_FOUND"
        echo "  Update Errors: $UPDATE_ERRORS"
        echo "  Scan Errors: $SCAN_ERRORS"
        echo ""
        
        # Service Status
        echo "Service Status:"
        echo -n "  Freshclam: "
        systemctl is-active --quiet clamav-freshclam && echo -e "${GREEN}Active${NC}" || echo -e "${RED}Inactive${NC}"
        [ -n "$last_update" ] && echo "  Last Update: $last_update"
        echo ""
        
        # Critical Issues
        if [ $THREATS_FOUND -gt 0 ] && [ -n "$infected_files" ]; then
            echo -e "${RED}INFECTED FILES DETECTED:${NC}"
            echo "$infected_files" | while IFS= read -r line; do
                [ -n "$line" ] && echo "  ! $line"
            done
            echo ""
        fi
        
        # Warnings
        if [ -n "$scan_warnings" ] || [ -n "$health_check" ]; then
            echo -e "${YELLOW}Warnings:${NC}"
            [ -n "$scan_warnings" ] && echo "  - $scan_warnings"
            [ -n "$health_check" ] && echo "$health_check" | while IFS= read -r line; do
                [ -n "$line" ] && echo "  - $line"
            done
            echo ""
        fi
        
        # Statistics
        echo "Statistics:"
        echo "$statistics" | while IFS= read -r line; do
            [ -n "$line" ] && echo "  $line"
        done
        
        # Recommendations
        echo ""
        echo "Recommendations:"
        if [ $THREATS_FOUND -gt 0 ]; then
            echo "  • URGENT: Review and clean infected files immediately"
            echo "  • Run full system scan: clamscan -ri /"
            echo "  • Check system for compromise indicators"
        fi
        if [ $UPDATE_ERRORS -gt 0 ]; then
            echo "  • Check network connectivity and DNS resolution"
            echo "  • Verify freshclam configuration"
            echo "  • Review logs: sudo journalctl -u clamav-freshclam -n 50"
        fi
        if [ $SCAN_ERRORS -gt 0 ]; then
            echo "  • Review scan error details in logs"
            echo "  • Check file permissions for scanned directories"
        fi
        if [ $CRITICAL_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
            echo "  • No action required - system is healthy"
        fi
    fi
}

# Run the report
generate_report
