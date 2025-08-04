# Ubuntu Security Toolkit

**A security-focused hardening and monitoring toolkit for Ubuntu systems (20.04, 22.04, 24.04).**

This toolkit provides automated installation and management of security hardening tools, intrusion detection, antivirus, and system monitoring. It focuses exclusively on defensive security measures and system hardening.

> **Note**: Non-security applications (Docker, Tezos, etc.) have been moved to the `standalone-apps/` directory to maintain the security-focused nature of this toolkit.

## Project Structure

```
common/                  # Security scripts for both desktop and server
│   ├── clamav/          # Antivirus management
│   ├── fail2ban/        # Intrusion prevention with GeoIP
│   ├── monitoring/      # Security scanning and monitoring
│   └── lib/             # Shared libraries (dependency checking)

deploy/                  # Installation and deployment
│   ├── requirements/    # Package and service definitions
│   ├── config/          # Security tool configurations
│   ├── install-all.sh   # Master installer
│   └── verify-installation.sh  # Installation verification

standalone-apps/         # Non-security applications (separate)
│   ├── docker/          # Docker installation
│   ├── tezos/           # Tezos node installation
│   └── README.md        # Standalone apps documentation

docs/                    # Documentation
tests/                   # Test suites
```

## Directory Guidelines
- **common/**: Place scripts used by both desktop and server systems here. Organize by function (clamav, fail2ban, audit, monitoring).
- **desktop/**: Place scripts specific to desktop environments here. Use the `gnome/` subdirectory for GNOME-related scripts.
- **server/**: Place scripts specific to server environments here.
- **deploy/**: Contains deployment scripts and configuration templates for easy setup.
- **docs/**: All documentation, including setup guides for desktop and server.

## Features

### Core Security Components
- **Automated Dependency Management**: Intelligent package installation and verification
- **Multi-Environment Support**: Optimized for containers, VMs, and bare metal
- **Comprehensive Security Scanning**: Integrated antivirus, rootkit detection, and security auditing
- **Real-time Protection**: Fail2ban with GeoIP-based blocking and dynamic nation blacklisting
- **System Hardening**: SSH hardening, firewall configuration, and audit rules
- **Entropy Management**: Automatic entropy optimization for containers and hosts
- **Performance Optimization**: Off-hours scheduling to minimize system impact

### Security Tools Only

This toolkit includes ONLY security-focused tools:

- **ClamAV**: Open-source antivirus with automated updates
- **Fail2ban**: Intrusion prevention with geographic IP analysis
- **RKHunter**: Rootkit detection and system scanning
- **Chkrootkit**: Alternative rootkit scanner
- **Lynis**: Security auditing and compliance checking
- **Auditd**: System call auditing and monitoring
- **AppArmor**: Mandatory access control framework
- **UFW**: Uncomplicated firewall management
- **Entropy Management**: Haveged/rng-tools for cryptographic operations
- **SSH Hardening**: Automated SSH security configuration

**Not Included** (moved to `standalone-apps/`):
- Docker
- Tezos/blockchain nodes  
- Web servers
- Development environments

### Dependency Management
- Automatic detection of missing packages
- Pre-flight checks in all scripts
- Centralized dependency library
- Installation verification system

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/ubuntu-security-toolkit.git
cd ubuntu-security-toolkit

# Run the master installer (recommended)
sudo ./deploy/install-all.sh

# Or install security tools only
sudo ./deploy/install-security-tools.sh

# Verify installation
sudo ./deploy/verify-installation.sh
```

## Installation Options

The toolkit provides multiple installation modes:

### 1. Master Installer (Recommended)
```bash
sudo ./deploy/install-all.sh [OPTIONS]

Options:
  -m, --mode MODE      Installation mode: minimal, standard, full (default: standard)
  -n, --non-interactive Run without prompts
  -d, --dry-run        Show what would be installed without making changes
  -f, --force          Force installation on unsupported versions
  -h, --help           Display help message
```

**Installation Modes:**
- **minimal**: Core security tools only (fail2ban, ufw, auditd)
- **standard**: Core + antivirus + monitoring tools (recommended)
- **full**: All tools including optional enhancements

### 2. Component-Specific Installation
```bash
# Initial system setup (run first on fresh systems)
sudo ./deploy/initial-setup.sh

# Security tools only (ClamAV, rkhunter, lynis, etc.)
sudo ./deploy/install-security-tools.sh

# Docker installation
sudo ./common/docker/install-docker.sh

# SSH hardening
sudo ./deploy/deploy-ssh-hardening.sh
```

## Usage

### Daily Security Operations

**Automated Daily Security Scan:**
```bash
# Run comprehensive security scan
sudo ./common/monitoring/daily-security-scan.sh

# Scans include: RKHunter, ClamAV, Chkrootkit, Lynis, failed logins, network connections
# Reports saved to: /var/log/ubuntu-security-toolkit/security-scans/
```

**ClamAV Antivirus Management:**
```bash
# Check status
sudo ./common/clamav/clamav-manager.sh status

# Update virus definitions
sudo ./common/clamav/clamav-manager.sh update

# Scan directories
sudo ./common/clamav/clamav-manager.sh scan /home
sudo ./common/clamav/clamav-manager.sh scan / --exclude=/mnt

# Enable/disable real-time scanning
sudo ./common/clamav/clamav-manager.sh enable-daemon
sudo ./common/clamav/clamav-manager.sh disable-daemon
```

**Fail2ban Intrusion Prevention:**
```bash
# View fail2ban summary with geo-location
sudo ./common/fail2ban/f2b-geoban.sh

# Show all bans including archives
sudo ./common/fail2ban/f2b-geoban.sh -a -j

# Export ban data as CSV
sudo ./common/fail2ban/f2b-geoban.sh -f csv > bans.csv
```

**System Monitoring:**
```bash
# Check entropy levels (important for cryptographic operations)
sudo ./common/monitoring/check-entropy-sufficiency.sh

# Container-specific entropy health
sudo ./common/monitoring/container-entropy-health.sh

# Security hardening verification
sudo ./common/monitoring/security-hardening-check.sh
```

### Scheduled Tasks

The installer automatically configures these cron jobs:
- **3:00 AM**: Daily security scan
- **2:00 AM**: ClamAV virus scan
- **Sundays 4:00 AM**: GeoIP database updates

Logs are stored in `/var/log/ubuntu-security-toolkit/`

## Troubleshooting

### Common Issues

**Missing dependencies:**
```bash
# Run verification to identify issues
sudo ./deploy/verify-installation.sh

# Install missing components
sudo ./deploy/install-all.sh
```

**ClamAV database errors:**
```bash
# Stop service and manually update
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
```

**Low entropy warnings:**
```bash
# Check entropy status
cat /proc/sys/kernel/random/entropy_avail

# Fix container entropy
sudo ./common/monitoring/fix-container-entropy.sh
```

**Mail delivery failures:**
```bash
# Install mail system
sudo apt-get install mailutils

# Configure local delivery
sudo dpkg-reconfigure postfix  # Choose "Local only"
```

### Getting Help

1. Check logs in `/var/log/ubuntu-security-toolkit/`
2. Run verification: `sudo ./deploy/verify-installation.sh`
3. Review script help: `./script-name.sh --help`
4. Check service status: `sudo systemctl status <service-name>`

## Development

### Adding New Scripts

1. Place scripts in appropriate directories:
   - `common/` - Shared between desktop and server
   - `desktop/` - Desktop-specific tools
   - `server/` - Server-specific tools

2. Include dependency checking:
   ```bash
   source "$(dirname "$0")/../lib/dependency-check.sh"
   check_dependencies "command1" "command2/package2"
   ```

3. Follow naming conventions:
   - Use descriptive names with hyphens
   - Include help/usage information
   - Add proper error handling

4. Update documentation:
   - Add usage examples to README
   - Document in relevant `docs/` subdirectory
   - Update CLAUDE.md if needed

### Testing

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test suite
./tests/unit/test_clamav_scripts.sh
./tests/unit/test_fail2ban_scripts.sh
./tests/unit/test_monitoring_scripts.sh
```

## Security Philosophy

This toolkit adheres to strict security principles:

1. **Defensive Only**: No offensive security tools or exploits
2. **Minimal Attack Surface**: Only essential security tools included
3. **Separation of Concerns**: Non-security apps isolated in `standalone-apps/`
4. **Audit Trail**: All operations logged for accountability
5. **Least Privilege**: Scripts request only necessary permissions

## Using Non-Security Applications

If you need Docker, Tezos, or other applications:

```bash
# First: Install security toolkit
sudo ./deploy/install-all.sh

# Then: Install standalone apps as needed
cd standalone-apps/docker/
./install-docker.sh

# Or install Tezos node
cd standalone-apps/tezos/octez/
./node-install.sh
```

See `standalone-apps/README.md` for more information.

## License
This project is licensed under the MIT License - see the LICENSE file for details. 