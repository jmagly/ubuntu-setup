#!/bin/bash

echo "=== Entropy Sufficiency Test ==="
echo ""

# Stop rng-tools temporarily
echo "Testing with haveged only..."
sudo systemctl stop rng-tools-debian 2>/dev/null

sleep 2

# Check entropy with just haveged
HAVEGED_ONLY=$(cat /proc/sys/kernel/random/entropy_avail)
echo "Entropy with haveged only: $HAVEGED_ONLY"

# Quick stress test
echo "Performing entropy stress test..."
for i in {1..5}; do
    dd if=/dev/random of=/dev/null bs=1 count=256 2>/dev/null
    sleep 0.5
    echo "Test $i: $(cat /proc/sys/kernel/random/entropy_avail)"
done

sleep 2
FINAL=$(cat /proc/sys/kernel/random/entropy_avail)
echo ""
echo "Final entropy level: $FINAL"

# Recommendation
echo ""
echo "=== Recommendation ==="
if [ $FINAL -gt 2000 ]; then
    echo "✓ haveged alone is maintaining excellent entropy (>2000)"
    echo "  rng-tools-debian is NOT needed"
    echo ""
    echo "To disable rng-tools-debian:"
    echo "  sudo systemctl disable rng-tools-debian"
    echo "  sudo systemctl mask rng-tools-debian"
elif [ $FINAL -gt 1000 ]; then
    echo "⚠ haveged is maintaining acceptable entropy (>1000)"
    echo "  rng-tools-debian is optional"
else
    echo "✗ Additional entropy sources recommended"
    echo "  Keep rng-tools-debian configured"
fi
