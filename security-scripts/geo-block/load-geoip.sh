#!/bin/bash

# Load ipset
ipset restore < /etc/ipset.conf

# Add iptables rule for ipset
iptables -I INPUT -p tcp --dport 22 -m set --match-set blocked-countries src -j DROP
