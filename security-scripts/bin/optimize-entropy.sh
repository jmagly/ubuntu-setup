#!/bin/bash

echo "=== Optimizing Entropy Configuration ==="
echo ""

# 1. Ensure haveged is optimized
echo "Checking haveged configuration..."
if ! grep -q "DAEMON_ARGS" /etc/systemd/system/haveged.service.d/override.conf 2>/dev/null; then
    echo "Optimizing haveged..."
    sudo mkdir -p /etc/systemd/system/haveged.service.d/
    cat << 'HAVEGED' | sudo tee /etc/systemd/system/haveged.service.d/override.conf
[Service]
Environment="DAEMON_ARGS=-w 2048"
ExecStart=
ExecStart=/usr/sbin/haveged $DAEMON_ARGS --Foreground --verbose=1
HAVEGED
    sudo systemctl daemon-reload
    sudo systemctl restart haveged
fi

# 2. Check current entropy
CURRENT=$(cat /proc/sys/kernel/random/entropy_avail)
echo "Current entropy: $CURRENT"

# 3. Decision logic
if [ $CURRENT -gt 2000 ]; then
    echo ""
    echo "✓ Entropy is excellent with haveged alone"
    echo "Disabling unnecessary rng-tools-debian..."
    sudo systemctl stop rng-tools-debian
    sudo systemctl disable rng-tools-debian
    echo "Done! System is using haveged only."
else
    echo ""
    echo "⚠ Entropy could be improved"
    echo "Keeping both haveged and rng-tools-debian..."
    # Try to fix rng-tools-debian
    if [ ! -e /dev/hwrng ]; then
        echo "Configuring rng-tools-debian for urandom source..."
        cat << 'RNG' | sudo tee /etc/default/rng-tools-debian
HRNGDEVICE=/dev/urandom
RNGDOPTIONS="-r /dev/urandom -o /dev/random -t 1"
RNG
        sudo systemctl restart rng-tools-debian
    fi
fi

# 4. Final status
echo ""
echo "=== Final Status ==="
echo "Entropy: $(cat /proc/sys/kernel/random/entropy_avail)"
echo -n "haveged: "
systemctl is-active haveged
echo -n "rng-tools: "
systemctl is-active rng-tools-debian
