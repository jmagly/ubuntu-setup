# GeoIP Blocking Configuration Guide

This toolkit provides GeoIP blocking capabilities using free IPdeny zone files. The system is designed to be neutral - you configure which countries to block based on your server's specific needs.

## How to Identify Countries to Block

### 1. Analyze Failed Login Attempts

Check your authentication logs to see where attacks are coming from:

```bash
# Show failed SSH login attempts with IP addresses
sudo grep "Failed password" /var/log/auth.log | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -rn | head -20

# Look up country for specific IPs
geoiplookup 123.456.789.0
```

### 2. Use Fail2ban Statistics

Check which IPs fail2ban has already banned:

```bash
# Show banned IPs from all jails
sudo fail2ban-client status | grep "Jail list" -A 1

# Show banned IPs from SSH jail
sudo fail2ban-client status sshd

# Get country info for banned IPs
sudo fail2ban-client status sshd | grep "Banned IP" | while read ip; do
    echo "$ip - $(geoiplookup $ip)"
done
```

### 3. Use Analysis Tools

The toolkit includes analysis scripts to help identify patterns:

```bash
# Analyze recent attacks (if available)
sudo ./analyze-attacks.sh

# Check GeoIP data for recent bans
sudo ./f2b-geoban.sh -a
```

## Configuring Country Blocks

### Method 1: Configuration File (Recommended)

1. Copy the example configuration:
```bash
cp geoip-countries.conf.example geoip-countries.conf
```

2. Edit the configuration file:
```bash
nano geoip-countries.conf
```

3. Uncomment the country codes you want to block based on your analysis

4. Run the update script:
```bash
sudo ./update-geoip-simple.sh
```

### Method 2: Command Line

Specify countries directly when running the update:

```bash
# Block specific countries
sudo ./update-geoip-simple.sh cn ru ir

# This downloads zone files for China, Russia, and Iran
```

## Automatic Updates

The installer sets up a weekly cron job to update the IPdeny zone files. To modify the schedule:

```bash
sudo nano /etc/cron.d/geoip-update
```

## Testing Your Configuration

After configuring blocks, verify everything is working:

```bash
# Check GeoIP installation
/path/to/verify-geoip.sh

# List downloaded zone files
ls -la /usr/share/GeoIP/zones/

# Check combined blocklist size
wc -l /usr/share/GeoIP/zones/all-blocked.zone
```

## Important Notes

1. **Start Conservative**: Begin by blocking only countries that are actively attacking your server
2. **Monitor Impact**: Some legitimate users might be affected by country-wide blocks
3. **Regular Review**: Periodically review your blocks and adjust as needed
4. **Whitelist Important IPs**: If you have legitimate users from blocked countries, whitelist their specific IPs in fail2ban

## Integration with Fail2ban

The GeoIP data integrates with fail2ban to enhance blocking decisions. The downloaded zone files can be used by:

- Custom fail2ban actions
- IPset rules
- Direct iptables rules

For advanced integration, see the fail2ban documentation and the geo-block scripts in this directory.

## Troubleshooting

If downloads fail:
1. Check internet connectivity
2. Verify IPdeny.com is accessible
3. Check disk space in /usr/share/GeoIP/
4. Review logs at /var/log/geoip-update.log

## Privacy and Neutrality

This toolkit does not impose any default blocking policies. The choice of which countries to block is entirely up to the server administrator based on their specific security needs and traffic patterns.

## Personal Configurations

**Important**: The file `geoip-countries.conf` is listed in `.gitignore` and will not be committed to the repository. This ensures:

1. Your personal security choices remain private
2. No geopolitical opinions are shared publicly
3. Each user can maintain their own configuration

When creating your configuration, consider:
- Your geographic location and legitimate traffic sources
- Compliance requirements (OFAC sanctions, export controls)
- Your industry's specific threat landscape
- Current geopolitical situations

Example configurations for different scenarios:
- **High-security US-based servers**: May block sanctioned countries and high-risk regions
- **International business**: More selective blocking, focusing on known attack sources
- **Academic/Research**: Minimal blocking to maintain global accessibility
- **E-commerce**: Balance security with customer accessibility

Remember to document your blocking rationale for compliance and review purposes.