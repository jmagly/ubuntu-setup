#!/bin/bash

# Fail2ban module for security reports
generate_f2b_report() {
    local format="${1:-text}"
    
    if [ "$format" = "json" ]; then
        # JSON output
        /usr/local/bin/f2b-geoban.sh -a -j -t 20 -f json
    else
        # Text report
        echo "=== FAIL2BAN INTRUSION ATTEMPTS ==="
        echo ""
        
        # Active jails status
        echo "Active Security Jails:"
        sudo fail2ban-client status | grep "Jail list" | sed 's/.*://;s/,/\n/g' | while read jail; do
            if [ -n "$jail" ]; then
                jail=$(echo $jail | xargs)
                banned=$(sudo fail2ban-client status $jail 2>/dev/null | grep "Currently banned:" | awk '{print $NF}')
                total=$(sudo fail2ban-client status $jail 2>/dev/null | grep "Total banned:" | awk '{print $NF}')
                echo "  • $jail: $banned currently banned, $total total"
            fi
        done
        
        echo ""
        echo "Top 20 Attacking IPs (All Time):"
        /usr/local/bin/f2b-geoban.sh -a -j -t 20
        
        echo ""
        echo "Geographic Distribution:"
        /usr/local/bin/f2b-geoban.sh -a -t 999 | tail -n +4 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | \
            sed 's/^ *//;s/ *$//' | sort | uniq -c | sort -nr | head -10 | \
            awk '{count=$1; $1=""; printf "  • %-30s %d attacks\n", $0, count}'
    fi
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    generate_f2b_report "$@"
fi
