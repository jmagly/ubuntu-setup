#!/bin/bash

echo "=== Clean Rebuild of Geo-blocking ==="
echo ""

# Remove all geo-block iptables rules
echo "Removing iptables rules..."
while sudo iptables -L INPUT -n --line-numbers | grep -q "GEO-BLOCK"; do
    line=$(sudo iptables -L INPUT -n --line-numbers | grep "GEO-BLOCK" | head -1 | awk '{print $1}')
    sudo iptables -D INPUT "$line"
done

# Destroy all related ipsets
echo "Removing ipsets..."
for ipset in blocked-countries blocked-countries-new test-country; do
    if sudo ipset list -n | grep -q "^${ipset}$"; then
        echo "  Destroying $ipset"
        sudo ipset destroy "$ipset"
    fi
done

# Clear any stale lock files
echo "Clearing lock files..."
sudo rm -f /var/run/geo-block-update.lock

echo ""
echo "Clean complete. Running fresh update..."
echo ""

# Run fresh update
sudo /usr/local/bin/geo-block/update-geoip.sh
