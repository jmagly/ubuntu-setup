#!/bin/bash

echo "=== Fixing ClamAV Installation ==="
echo ""

# 1. Stop all ClamAV services
echo "Stopping ClamAV services..."
sudo systemctl stop clamav-freshclam
sudo systemctl stop clamav-daemon 2>/dev/null
sudo killall freshclam 2>/dev/null

# 2. Fix directory permissions
echo "Fixing directory permissions..."
sudo mkdir -p /var/log/clamav /var/lib/clamav /var/run/clamav
sudo chown -R clamav:clamav /var/log/clamav
sudo chown -R clamav:clamav /var/lib/clamav
sudo chown -R clamav:clamav /var/run/clamav
sudo chmod 755 /var/log/clamav /var/lib/clamav /var/run/clamav

# 3. Clean up lock files
echo "Cleaning up lock files..."
sudo rm -f /var/log/clamav/*.lock
sudo rm -f /var/run/clamav/*.pid
sudo rm -f /var/lib/clamav/*.lock

# 4. Fix log files
echo "Fixing log files..."
sudo touch /var/log/clamav/freshclam.log
sudo touch /var/log/clamav/clamav.log
sudo chown clamav:adm /var/log/clamav/*.log
sudo chmod 640 /var/log/clamav/*.log

# 5. Fix configuration
echo "Fixing configuration..."
if grep -q "^Example" /etc/clamav/freshclam.conf; then
    sudo sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf
    echo "  Commented out Example line"
fi

if grep -q "^Example" /etc/clamav/clamd.conf 2>/dev/null; then
    sudo sed -i 's/^Example/#Example/' /etc/clamav/clamd.conf
    echo "  Commented out Example line in clamd.conf"
fi

# 6. Test freshclam manually
echo ""
echo "Testing freshclam..."
sudo -u clamav freshclam --config-file=/etc/clamav/freshclam.conf --datadir=/var/lib/clamav

# 7. Start service
echo ""
echo "Starting clamav-freshclam service..."
sudo systemctl start clamav-freshclam
sleep 2
sudo systemctl status clamav-freshclam --no-pager

echo ""
echo "=== Fix Complete ==="
