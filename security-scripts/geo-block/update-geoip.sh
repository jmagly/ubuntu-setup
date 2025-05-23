#!/bin/bash

# Countries to block
COUNTRIES=("BG" "RU" "SA" "OM" "ZA" "CN" "IN" "KP")

# Create an ipset for countries if it doesn't exist
ipset create -exist blocked-countries hash:net

# Create a temp file for download
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Download the latest IP blocks for each country
for country in "${COUNTRIES[@]}"; do
  echo "Downloading IP blocks for $country"
  wget -q "https://www.ipdeny.com/ipblocks/data/countries/${country}.zone"
  if [ -f "$country.zone" ]; then
    # Add the country's IP blocks to ipset
    while IFS= read -r ip; do
      ipset add -exist blocked-countries "$ip"
    done < "$country.zone"
  fi
done

# Clean up
cd /
rm -rf "$TMP_DIR"

# Save ipset
ipset save blocked-countries > /etc/ipset.conf

echo "GeoIP blocks updated successfully"
