#!/bin/bash

# update-geoip.sh - Update GeoIP databases from various sources
# This script updates both legacy GeoIP and IPdeny zone files

set -euo pipefail

# Dynamic script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Don't call f2b-geoban.sh here to avoid recursion
# Just update the databases

echo "=== GeoIP Database Update ==="
echo "Updating GeoIP databases..."

# Update package databases
if command -v geoipupdate &> /dev/null; then
    sudo geoipupdate
else
    # Manual update for GeoLite databases
    cd /tmp
    
    # Download latest GeoLite Country database
    wget -q https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb
    
    if [ -f GeoLite2-Country.mmdb ]; then
        sudo mv GeoLite2-Country.mmdb /usr/share/GeoIP/
        echo "GeoLite2 Country database updated"
    fi
    
    cd - > /dev/null
fi

echo "GeoIP database update complete"
