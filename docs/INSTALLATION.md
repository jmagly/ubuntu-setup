# Ubuntu Security Toolkit - Installation Guide

This guide provides detailed installation instructions for the Ubuntu Security Toolkit.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Installation Methods](#installation-methods)
4. [Post-Installation Steps](#post-installation-steps)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## System Requirements

### Supported Ubuntu Versions
- Ubuntu 20.04 LTS (Focal Fossa)
- Ubuntu 22.04 LTS (Jammy Jellyfish)  
- Ubuntu 24.04 LTS (Noble Numbat)

### Minimum Requirements
- 2GB RAM (4GB recommended)
- 10GB free disk space
- Active internet connection (for package downloads)
- sudo/root access

### Environment Support
- Bare metal installations
- Virtual machines (VMware, VirtualBox, KVM, etc.)
- Docker containers
- LXC/LXD containers
- Cloud instances (AWS, Azure, GCP, etc.)

## Pre-Installation Checklist

Before installing, ensure:

1. **System is up to date:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Git is installed:**
   ```bash
   sudo apt install -y git
   ```

3. **You have sudo access:**
   ```bash
   sudo -v
   ```

4. **Sufficient disk space:**
   ```bash
   df -h /
   ```

## Installation Methods

### Method 1: Quick Installation (Recommended)

For most users, the master installer provides the best experience:

```bash
# Clone the repository
git clone https://github.com/yourusername/ubuntu-security-toolkit.git
cd ubuntu-security-toolkit

# Run master installer with default settings
sudo ./deploy/install-all.sh
```

### Method 2: Custom Installation

Choose specific components and installation mode:

```bash
# Minimal installation (core security only)
sudo ./deploy/install-all.sh --mode minimal

# Standard installation (recommended)
sudo ./deploy/install-all.sh --mode standard

# Full installation (all features)
sudo ./deploy/install-all.sh --mode full

# Non-interactive installation
sudo ./deploy/install-all.sh --mode standard --non-interactive
```

### Method 3: Component-by-Component Installation

Install specific components individually:

```bash
# 1. Initial system setup (if fresh system)
sudo ./deploy/initial-setup.sh

# 2. Core security tools
sudo ./deploy/install-security-tools.sh

# 3. Docker (if needed)
sudo ./common/docker/install-docker.sh

# 4. SSH hardening
sudo ./deploy/deploy-ssh-hardening.sh

# 5. Configure fail2ban
sudo ./deploy/configure-fail2ban.sh
```

### Method 4: Docker-based Installation

For testing or isolated environments:

```bash
# Build Docker image with toolkit
docker build -t ubuntu-security-toolkit .

# Run container
docker run -it --privileged ubuntu-security-toolkit
```

## Installation Modes Explained

### Minimal Mode
Installs only essential security components:
- UFW (Uncomplicated Firewall)
- Fail2ban (Intrusion Prevention)
- Auditd (System Auditing)
- AppArmor (Access Control)

### Standard Mode (Recommended)
Includes minimal plus:
- ClamAV (Antivirus)
- RKHunter (Rootkit Scanner)
- Chkrootkit (Rootkit Scanner)
- Lynis (Security Auditing)
- Entropy management tools
- Mail utilities for reports

### Full Mode
Includes everything plus optional tools:
- Apache/Nginx (for web server monitoring)
- Enhanced GeoIP support
- Network analysis tools
- Performance monitoring utilities
- Additional security scanners

## Post-Installation Steps

### 1. Verify Installation

Run the verification script:
```bash
sudo ./deploy/verify-installation.sh
```

### 2. Configure Email Reports (Optional)

If you want email notifications:
```bash
# Install mail system if not present
sudo apt install -y mailutils

# Configure postfix for local delivery
sudo dpkg-reconfigure postfix
# Select "Local only" when prompted
```

### 3. Review and Adjust Configurations

**SSH Hardening:**
```bash
# Review SSH configuration
sudo cat /etc/ssh/sshd_config.d/99-hardening.conf

# Adjust allowed users if needed
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```

**Fail2ban Rules:**
```bash
# Check active jails
sudo fail2ban-client status

# Review jail configuration
sudo cat /etc/fail2ban/jail.local
```

### 4. Schedule Regular Updates

The toolkit sets up automatic updates, but you can also run manually:
```bash
# Update virus definitions
sudo ./common/clamav/clamav-manager.sh update

# Update GeoIP databases
sudo ./common/fail2ban/update-geoip.sh
```

### 5. Run Initial Security Scan

Perform a baseline security scan:
```bash
sudo ./common/monitoring/daily-security-scan.sh
```

## Verification

### Check Installed Packages
```bash
# List security packages
dpkg -l | grep -E "(clamav|fail2ban|rkhunter|lynis|auditd)"
```

### Check Running Services
```bash
# Check service status
systemctl status ufw
systemctl status fail2ban
systemctl status clamav-freshclam
systemctl status auditd
```

### Check Scheduled Tasks
```bash
# View cron jobs
sudo cat /etc/cron.d/ubuntu-security-toolkit
```

### Test Security Tools
```bash
# Test ClamAV
sudo clamscan --version

# Test Fail2ban
sudo fail2ban-client ping

# Test RKHunter
sudo rkhunter --version

# Test Lynis
sudo lynis show version
```

## Troubleshooting

### Installation Fails

**Package conflicts:**
```bash
# Fix broken packages
sudo apt --fix-broken install

# Clean package cache
sudo apt clean
sudo apt autoclean
```

**Network issues:**
```bash
# Test connectivity
ping -c 4 8.8.8.8

# Check DNS
nslookup google.com

# Use different mirror
sudo nano /etc/apt/sources.list
```

### ClamAV Issues

**Database download fails:**
```bash
# Stop service
sudo systemctl stop clamav-freshclam

# Manual update
sudo freshclam

# Restart service
sudo systemctl start clamav-freshclam
```

**Daemon won't start:**
```bash
# Check logs
sudo journalctl -u clamav-daemon -n 50

# Check permissions
sudo chown -R clamav:clamav /var/lib/clamav
```

### Low Entropy

**In containers:**
```bash
# Install rng-tools
sudo apt install -y rng-tools

# Configure and start
sudo systemctl enable rng-tools
sudo systemctl start rng-tools
```

**On bare metal:**
```bash
# Install haveged
sudo apt install -y haveged

# Start service
sudo systemctl enable haveged
sudo systemctl start haveged
```

### Verification Failures

If verification shows failures:
```bash
# Re-run installation
sudo ./deploy/install-all.sh

# Check specific component
sudo ./deploy/install-security-tools.sh

# Check logs
sudo tail -f /var/log/ubuntu-security-toolkit/install-*.log
```

## Uninstallation

To remove the toolkit:

```bash
# Remove packages (careful - may affect other software)
sudo apt remove clamav* rkhunter chkrootkit lynis

# Remove configurations
sudo rm -rf /etc/cron.d/ubuntu-security-toolkit
sudo rm -rf /var/log/ubuntu-security-toolkit

# Remove fail2ban rules (if desired)
sudo rm -f /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

## Support

For issues or questions:
1. Check the logs in `/var/log/ubuntu-security-toolkit/`
2. Run `./deploy/verify-installation.sh` to identify problems
3. Consult the README.md for usage instructions
4. Review individual script help with `--help` flag