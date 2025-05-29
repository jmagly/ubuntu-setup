# Ubuntu Security Toolkit

A comprehensive security toolkit for Ubuntu systems, supporting both desktop and server environments. This toolkit is modular, with clear separation between scripts for desktop, server, and shared (common) use cases.

## Project Structure

```
common/                  # Shared scripts for both desktop and server
│   ├── clamav/          # ClamAV related scripts
│   ├── fail2ban/        # Fail2ban and geoip management
│   ├── audit/           # Auditd configuration and management
│   └── monitoring/      # System and container monitoring, entropy, rootkit, and hardening scripts

desktop/                 # Desktop-specific scripts
│   └── gnome/           # GNOME-specific security settings and scripts

server/                  # Server-specific scripts

deploy/                  # Deployment and configuration templates
│   └── config/          # Example configuration files for auditd, fail2ban, etc.

docs/                    # Documentation
│   ├── desktop/         # Desktop setup and usage guides
│   └── server/          # Server setup and usage guides
```

## Directory Guidelines
- **common/**: Place scripts used by both desktop and server systems here. Organize by function (clamav, fail2ban, audit, monitoring).
- **desktop/**: Place scripts specific to desktop environments here. Use the `gnome/` subdirectory for GNOME-related scripts.
- **server/**: Place scripts specific to server environments here.
- **deploy/**: Contains deployment scripts and configuration templates for easy setup.
- **docs/**: All documentation, including setup guides for desktop and server.

## Features
- Automated security scanning and monitoring
- ClamAV antivirus management
- Fail2ban with geoip-based blocking and dynamic nation blacklisting
- Auditd system auditing
- Container and entropy monitoring
- System hardening checks
- Performance-optimized scheduling (off-hours by default)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ubuntu-security-toolkit.git
cd ubuntu-security-toolkit
# Review and use the deployment scripts in deploy/ for setup
```

## Usage

- **Daily Security Scan:**
  ```bash
  sudo ./common/monitoring/daily-security-scan.sh
  ```
- **ClamAV Management:**
  ```bash
  sudo ./common/clamav/clamav-manager.sh [update|status|scan|enable-daemon]
  ```
- **Fail2ban Management:**
  ```bash
  sudo ./common/fail2ban/f2b-manager.sh [status|ban|unban|update-geoip]
  ```
- **Desktop/Server Scripts:**
  - See `desktop/` and `server/` directories for environment-specific tools.

## Contributing
- Place new scripts in the appropriate directory (see above).
- Add documentation for new scripts in the relevant `docs/` subdirectory.
- See CONTRIBUTING.md for more details.

## License
This project is licensed under the MIT License - see the LICENSE file for details. 