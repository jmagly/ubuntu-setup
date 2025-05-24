#!/bin/bash

# Quick fail2ban summary
echo "=== Fail2ban Summary ==="
echo "Active Jails:"
sudo fail2ban-client status | grep "Jail list" | sed 's/.*://;s/,/\n/g' | while read jail; do
    if [ -n "$jail" ]; then
        jail=$(echo $jail | xargs)
        status=$(sudo fail2ban-client status $jail 2>/dev/null | grep -E "Currently (banned|failed)" | sed 's/.*://' | xargs)
        echo "  $jail: $status"
    fi
done

echo ""
echo "Recent Activity (last 24h):"
sudo journalctl -u fail2ban --since="24 hours ago" | grep -c "Ban" | xargs echo "  Bans:"
sudo journalctl -u fail2ban --since="24 hours ago" | grep -c "Unban" | xargs echo "  Unbans:"

echo ""
echo "Top 5 Banned Countries:"
/usr/local/bin/f2b-geoban.sh -t 999 | tail -n +4 | awk -F' ' '{print $3,$4}' | sed 's/Unknown/Unknown Country/g' | sort | uniq -c | sort -nr | head -5
