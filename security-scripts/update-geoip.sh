#!/bin/bash

# Update GeoIP databases
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
