#!/bin/bash

case "$1" in
    update)
        echo "=== ClamAV Database Update ==="
        # Check if service is running
        if systemctl is-active --quiet clamav-freshclam; then
            echo "Freshclam service is running - forcing immediate update..."
            # Send SIGUSR1 to freshclam to trigger immediate update
            sudo pkill -SIGUSR1 freshclam
            echo "Update triggered. Check logs with: sudo journalctl -u clamav-freshclam -f"
        else
            echo "Freshclam service not running - starting manual update..."
            sudo freshclam
        fi
        ;;
    
    status)
        echo "=== ClamAV Status ==="
        echo ""
        echo "Services:"
        for service in clamav-freshclam clamav-daemon; do
            status=$(systemctl is-active $service 2>/dev/null || echo "not-installed")
            if [ "$status" = "active" ]; then
                echo "✓ $service: active"
            else
                echo "✗ $service: $status"
            fi
        done
        
        echo ""
        echo "Database versions:"
        /usr/local/bin/clamav-status-detailed.sh
        /usr/local/bin/clamav-status-detailed.sh
        /usr/local/bin/clamav-status-detailed.sh
        
        echo ""
        echo "Last update check:"
        sudo journalctl -u clamav-freshclam -n 1 --no-pager | grep -E "ClamAV update|up-to-date"
        ;;
    
    scan)
        shift
        if [ -z "$1" ]; then
            echo "Usage: $0 scan <path>"
            exit 1
        fi
        echo "=== Scanning $@ ==="
        clamscan -r --bell -i "$@"
        ;;
    
    enable-daemon)
        echo "=== Enabling ClamAV Daemon ==="
        sudo systemctl enable clamav-daemon
        sudo systemctl start clamav-daemon
        sudo systemctl status clamav-daemon --no-pager
        ;;
    
    *)
        echo "ClamAV Manager"
        echo "Usage: $0 {update|status|scan <path>|enable-daemon}"
        echo ""
        echo "  update       - Force database update"
        echo "  status       - Show ClamAV status"
        echo "  scan <path>  - Scan specified path"
        echo "  enable-daemon - Enable ClamAV daemon for faster scanning"
        ;;
esac
