#!/bin/bash

echo "=== Geo-Block Connection Debug ==="
echo ""

# Test DNS
echo "Testing DNS resolution..."
if host www.ipdeny.com; then
    echo "✓ DNS OK"
else
    echo "✗ DNS Failed"
fi

echo ""
echo "Testing connectivity to ipdeny.com..."
if wget --spider --timeout=10 https://www.ipdeny.com 2>&1 | grep -q "200 OK"; then
    echo "✓ HTTPS connection OK"
else
    echo "✗ HTTPS connection failed"
fi

echo ""
echo "Testing download of a small country (LU - Luxembourg)..."
if wget --timeout=30 -O /tmp/test-lu.zone "https://www.ipdeny.com/ipblocks/data/countries/lu.zone"; then
    lines=$(wc -l < /tmp/test-lu.zone)
    echo "✓ Download successful: $lines IP blocks"
    rm -f /tmp/test-lu.zone
else
    echo "✗ Download failed"
fi

echo ""
echo "Current ipset status:"
if sudo ipset list -n | grep -q blocked-countries; then
    count=$(sudo ipset list blocked-countries 2>/dev/null | grep -c "^[0-9]" || echo 0)
    echo "✓ blocked-countries exists: $count entries"
else
    echo "✗ blocked-countries not found"
fi
