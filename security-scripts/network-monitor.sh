#!/bin/bash
# Monitor suspicious network activity

THRESHOLD=100  # Connections threshold
LOGFILE="/var/log/network-monitor.log"

# Check for port scanning
CONNECTIONS=$(ss -tan | grep -c ESTABLISHED)
if [ $CONNECTIONS -gt $THRESHOLD ]; then
    echo "$(date): High connection count detected: $CONNECTIONS" >> $LOGFILE
    ss -tan | grep ESTABLISHED >> $LOGFILE
fi

# Check for unusual ports
UNUSUAL_PORTS=$(ss -tlnp | grep -vE ':(22|80|443|3306|5432|6379|8080|2222)')
if [ ! -z "$UNUSUAL_PORTS" ]; then
    echo "$(date): Unusual ports detected:" >> $LOGFILE
    echo "$UNUSUAL_PORTS" >> $LOGFILE
fi
