# Ubuntu Security Toolkit - Quick Reference

## Installation Commands

```bash
# Quick install (standard mode)
sudo ./deploy/install-all.sh

# Full installation with all features
sudo ./deploy/install-all.sh --mode full

# Dry run (see what would be installed)
sudo ./deploy/install-all.sh --dry-run

# Verify installation
sudo ./deploy/verify-installation.sh
```

## Daily Operations

### Security Scanning

```bash
# Run comprehensive security scan
sudo ./common/monitoring/daily-security-scan.sh

# Quick ClamAV scan of home directory
sudo ./common/clamav/clamav-manager.sh scan /home

# Check for rootkits
sudo rkhunter --check --skip-keypress

# Run security audit
sudo lynis audit system --quiet
```

### Service Management

```bash
# Check all security service status
sudo systemctl status ufw fail2ban clamav-freshclam auditd

# Restart fail2ban after config changes
sudo systemctl restart fail2ban

# Update ClamAV definitions
sudo ./common/clamav/clamav-manager.sh update

# Enable ClamAV real-time scanning
sudo ./common/clamav/clamav-manager.sh enable-daemon
```

### Monitoring & Logs

```bash
# View recent security scan reports
ls -la /var/log/ubuntu-security-toolkit/security-scans/

# Check fail2ban bans with geo-location
sudo ./common/fail2ban/f2b-geoban.sh

# Monitor active network connections
sudo ss -tunlp

# Check system entropy
cat /proc/sys/kernel/random/entropy_avail

# View failed login attempts
sudo journalctl --since "24 hours ago" | grep "Failed password"
```

## Troubleshooting Commands

### Dependency Issues

```bash
# Check missing dependencies
sudo ./deploy/verify-installation.sh

# Install missing security tools
sudo ./deploy/install-security-tools.sh

# Fix broken packages
sudo apt --fix-broken install
```

### ClamAV Issues

```bash
# Check ClamAV status
sudo ./common/clamav/clamav-manager.sh status

# Fix ClamAV database errors
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam

# Check ClamAV logs
sudo journalctl -u clamav-freshclam -n 50
```

### Fail2ban Issues

```bash
# Check fail2ban status
sudo fail2ban-client status

# List all jails
sudo fail2ban-client status | grep "Jail list"

# Check specific jail
sudo fail2ban-client status sshd

# Unban an IP
sudo fail2ban-client unban <IP>

# Reload fail2ban
sudo fail2ban-client reload
```

### Low Entropy

```bash
# Check entropy level
watch -n 1 cat /proc/sys/kernel/random/entropy_avail

# Fix container entropy
sudo ./common/monitoring/fix-container-entropy.sh

# Install entropy daemon (bare metal)
sudo apt install haveged
sudo systemctl enable --now haveged
```

## Configuration Locations

```bash
# SSH hardening
/etc/ssh/sshd_config.d/99-hardening.conf

# Fail2ban jails
/etc/fail2ban/jail.local

# Audit rules
/etc/audit/rules.d/

# Cron jobs
/etc/cron.d/ubuntu-security-toolkit

# Toolkit logs
/var/log/ubuntu-security-toolkit/

# ClamAV database
/var/lib/clamav/

# UFW rules
/etc/ufw/
```

## Emergency Commands

```bash
# Disable all fail2ban jails (if locked out)
sudo fail2ban-client stop

# Stop all security scans
sudo pkill clamscan
sudo pkill rkhunter
sudo pkill lynis

# Check disk space
df -h /var/log

# Clean old logs
sudo find /var/log/ubuntu-security-toolkit -name "*.log" -mtime +30 -delete

# Reset UFW to defaults
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
```

## Useful One-Liners

```bash
# Count failed SSH attempts by IP
sudo journalctl -u ssh | grep "Failed" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | sort | uniq -c | sort -rn

# Find large log files
find /var/log -type f -size +100M -exec ls -lh {} \;

# Check listening ports
sudo ss -tlnp | grep LISTEN

# Show top 10 banned IPs
sudo fail2ban-client status sshd | grep -A 10 "Banned IP"

# Quick security summary
echo "=== Security Status ===" && \
echo "Firewall: $(sudo ufw status | grep Status)" && \
echo "Fail2ban: $(sudo systemctl is-active fail2ban)" && \
echo "ClamAV: $(sudo systemctl is-active clamav-freshclam)" && \
echo "Entropy: $(cat /proc/sys/kernel/random/entropy_avail) bits"
```

## Script Help

Most scripts support `--help` or `help` commands:

```bash
./deploy/install-all.sh --help
./common/clamav/clamav-manager.sh help
./common/fail2ban/f2b-geoban.sh --help
```