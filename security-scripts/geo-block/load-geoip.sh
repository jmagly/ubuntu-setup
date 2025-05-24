#!/bin/bash

# Load geo-blocking rules at boot

# Load configuration
source /etc/geo-block/config.conf

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BOOT] $@" | sudo tee -a "$LOG_FILE"
}

log "Loading geo-blocking rules"

# Restore ipset
if [ -f /etc/ipset.d/blocked-countries.conf ]; then
    sudo ipset restore < /etc/ipset.d/blocked-countries.conf
    log "Loaded ipset rules"
else
    log "ERROR: ipset configuration not found"
    # Try to update
    /usr/local/bin/geo-block/update-geoip.sh
fi

# Add iptables rules
for port in "${PROTECTED_SERVICES[@]}"; do
    sudo iptables -I INPUT -p tcp --dport "$port" -m set --match-set blocked-countries src -m comment --comment "GEO-BLOCK" -j DROP
    sudo iptables -I INPUT -p udp --dport "$port" -m set --match-set blocked-countries src -m comment --comment "GEO-BLOCK" -j DROP
done

log "Applied iptables rules for ports: ${PROTECTED_SERVICES[*]}"
