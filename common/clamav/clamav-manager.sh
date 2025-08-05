#!/bin/bash

# Dynamic script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        "$SCRIPT_DIR/clamav-status-detailed.sh"
        "$SCRIPT_DIR/clamav-status-detailed.sh"
        "$SCRIPT_DIR/clamav-status-detailed.sh"
        
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
    
    disable-daemon)
        echo "=== Disabling ClamAV Daemon ==="
        
        if ! check_root; then
            echo "Run with sudo to disable daemon"
            exit 1
        fi
        
        echo "Stopping and disabling clamav-daemon..."
        systemctl stop clamav-daemon 2>/dev/null || true
        systemctl disable clamav-daemon 2>/dev/null || true
        echo -e "${GREEN}ClamAV daemon disabled${NC}"
        ;;
    
    help|--help|-h)
        cat << EOF
ClamAV Manager - Ubuntu Security Toolkit

Usage: $0 <command> [options]

Commands:
    update          Update virus definitions
    status          Show ClamAV status and database info
    scan <path>     Scan specified path for viruses
    enable-daemon   Enable real-time scanning daemon
    disable-daemon  Disable real-time scanning daemon
    help            Show this help message

Examples:
    $0 update                    # Update virus definitions
    $0 status                    # Check ClamAV status
    $0 scan /home               # Scan /home directory
    $0 scan / --exclude=/mnt    # Scan root, exclude /mnt
    
For more options, see: man clamscan
EOF
        ;;
    
    *)
        echo "Error: Unknown command '${1:-}'"
        echo "Usage: $0 {update|status|scan <path>|enable-daemon|disable-daemon|help}"
        echo "Run '$0 help' for more information"
        exit 1
        ;;
esac
