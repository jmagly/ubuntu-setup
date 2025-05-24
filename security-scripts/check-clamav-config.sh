#!/bin/bash

echo "=== ClamAV Configuration Check ==="
echo ""

# Check if clamav user exists
if id "clamav" &>/dev/null; then
    echo "✓ ClamAV user exists"
else
    echo "✗ ClamAV user missing - creating..."
    sudo useradd -r -s /bin/false -c "ClamAV" clamav
fi

# Check directories
echo ""
echo "Checking directories:"
for dir in /var/log/clamav /var/lib/clamav /var/run/clamav; do
    if [ -d "$dir" ]; then
        echo "✓ $dir exists"
        ls -ld "$dir"
    else
        echo "✗ $dir missing - creating..."
        sudo mkdir -p "$dir"
        sudo chown clamav:clamav "$dir"
    fi
done

# Check configuration files
echo ""
echo "Configuration files:"
for conf in /etc/clamav/freshclam.conf /etc/clamav/clamd.conf; do
    if [ -f "$conf" ]; then
        echo "✓ $conf exists"
        # Check for common issues
        grep -E "^Example|^#Example" "$conf" && echo "  ⚠ Example line needs to be commented out"
    else
        echo "✗ $conf missing"
    fi
done
