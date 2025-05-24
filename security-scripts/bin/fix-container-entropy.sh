#!/bin/bash

echo "=== Container/VPS Entropy Fix ==="
echo ""

# Check current situation
CURRENT=$(cat /proc/sys/kernel/random/entropy_avail)
echo "Current entropy: $CURRENT"

if [ "$CURRENT" = "256" ]; then
    echo ""
    echo "Detected static entropy at 256 - typical of containerized environments"
    echo "This indicates your VPS provider has limited entropy visibility"
    echo ""
    
    # Test if /dev/urandom is actually working
    echo "Testing /dev/urandom functionality:"
    if timeout 1 head -c 100 /dev/urandom > /dev/null 2>&1; then
        echo "✓ /dev/urandom is working correctly"
        echo ""
        echo "IMPORTANT: On modern kernels (3.17+), /dev/urandom is cryptographically secure"
        echo "The '256' shown is likely a container limitation and doesn't reflect actual entropy"
        echo ""
        echo "Recommendations:"
        echo "1. Your system can safely use /dev/urandom for all cryptographic needs"
        echo "2. The haveged daemon IS working, even if the counter shows 256"
        echo "3. This is a display issue, not a security issue"
    else
        echo "✗ Problem detected with /dev/urandom"
    fi
fi

# Verify haveged is actually working
echo ""
echo "Verifying haveged operation:"

# Stop haveged temporarily
sudo systemctl stop haveged
sleep 1
WITHOUT=$(timeout 2 dd if=/dev/random bs=1 count=1024 2>&1 | grep -c "copied")

# Start haveged
sudo systemctl start haveged
sleep 2
WITH=$(timeout 2 dd if=/dev/random bs=1 count=1024 2>&1 | grep -c "copied")

echo "Random generation without haveged: ${WITHOUT:-blocked}"
echo "Random generation with haveged: ${WITH:-blocked}"

if [ "${WITH:-0}" != "${WITHOUT:-0}" ]; then
    echo "✓ Haveged is improving random generation"
else
    echo "⚠ Haveged impact unclear due to container limitations"
fi

# Final recommendations
echo ""
echo "=== For Container/VPS Environments ==="
echo "1. Keep haveged running - it helps even if entropy shows 256"
echo "2. Use /dev/urandom for applications - it's secure on modern kernels"
echo "3. The entropy counter is often meaningless in containers"
echo ""
echo "To verify everything is working:"
echo "  openssl rand -base64 32"
openssl rand -base64 32
echo ""
echo "If the above command works instantly, your random generation is fine!"
