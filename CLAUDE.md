# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ubuntu Security Toolkit - A comprehensive security toolkit for Ubuntu systems (20.04, 22.04, 24.04) with automated dependency management, installation verification, and modular architecture. The toolkit provides defensive security capabilities only, with clear separation between shared (common), desktop, and server-specific components.

## Architecture

The codebase is organized around security functions with intelligent dependency management:

- **common/**: Shared scripts for both desktop and server systems
  - `lib/`: Common libraries including dependency-check.sh
  - `clamav/`: Antivirus management with auto-installation support
  - `fail2ban/`: Intrusion prevention with GeoIP integration
  - `docker/`: Container runtime installation
  - `monitoring/`: Comprehensive security scanning and monitoring
- **deploy/**: Master installation and deployment orchestration
  - `requirements/`: Package lists and service definitions
  - `config/`: Configuration templates for all services
  - Master installer: `install-all.sh`
  - Component installers: `install-security-tools.sh`, etc.
  - Verification: `verify-installation.sh`
- **servers/**: Server-specific scripts (blockchain/tezos)
- **apps/**: Application-specific tools including claude-shell
- **tests/**: Bash-based test suite with assertions
- **docs/**: Comprehensive documentation

## Common Development Commands

### Installation & Setup
```bash
# Master installation (recommended)
sudo ./deploy/install-all.sh --mode standard

# Verify installation
sudo ./deploy/verify-installation.sh

# Install specific components
sudo ./deploy/install-security-tools.sh
```

### Testing
```bash
# Run all tests
./tests/run_tests.sh

# Run specific test suites
./tests/unit/test_clamav_scripts.sh
./tests/unit/test_fail2ban_scripts.sh
./tests/unit/test_monitoring_scripts.sh
```

### Key Security Operations
```bash
# Daily security scan (includes all scanners)
sudo ./common/monitoring/daily-security-scan.sh

# ClamAV management
sudo ./common/clamav/clamav-manager.sh help  # Show all commands
sudo ./common/clamav/clamav-manager.sh status
sudo ./common/clamav/clamav-manager.sh scan /path

# Fail2ban with geo-blocking
sudo ./common/fail2ban/f2b-geoban.sh -a -j  # Show all bans with jail info

# SSH hardening deployment
sudo ./deploy/deploy-ssh-hardening.sh
```

## Security Architecture

The toolkit implements defense-in-depth with automated dependency management:

### 1. Dependency Management Layer
- **Pre-flight Checks**: All scripts verify dependencies before execution
- **Auto-installation**: Missing packages can be installed automatically
- **Verification System**: `verify-installation.sh` ensures system integrity
- **Common Library**: `dependency-check.sh` provides reusable functions

### 2. Security Layers
- **Perimeter Defense**: UFW firewall, fail2ban with GeoIP blocking
- **Antivirus**: ClamAV with scheduled scans and real-time protection
- **Intrusion Detection**: RKHunter, Chkrootkit for rootkit detection
- **System Auditing**: Lynis for compliance, Auditd for system calls
- **Access Control**: AppArmor profiles, SSH hardening
- **Entropy Management**: Automatic optimization for crypto operations

### 3. Automation & Scheduling
- **Cron Jobs**: Automated daily scans at 3 AM
- **Update Management**: Weekly GeoIP updates, daily virus definitions
- **Log Rotation**: Centralized logging in `/var/log/ubuntu-security-toolkit/`
- **Email Reports**: Optional email notifications for security events

## Key Files and Configurations

### Installation & Dependencies
- `deploy/install-all.sh`: Master installer with mode selection
- `deploy/requirements/packages.txt`: Core package requirements
- `deploy/requirements/packages-optional.txt`: Optional enhancements
- `deploy/requirements/services.txt`: Service definitions
- `common/lib/dependency-check.sh`: Dependency checking library

### Security Configurations
- `deploy/config/ssh/sshd_config.d/99-hardening.conf`: SSH hardening
- `deploy/config/fail2ban/jail.local`: Fail2ban jail configuration
- `deploy/config/auditd.rules`: System audit rules
- `/etc/cron.d/ubuntu-security-toolkit`: Scheduled security tasks

## Development Guidelines

### Adding New Scripts

1. **Include Dependency Checking**:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Source dependency library
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")"))"
   source "$PROJECT_ROOT/common/lib/dependency-check.sh"
   
   # Check dependencies
   check_dependencies "command1" "command2/package2"
   ```

2. **Follow Error Handling Standards**:
   - Use `set -euo pipefail` for strict error handling
   - Provide clear error messages with recovery suggestions
   - Log operations to `/var/log/ubuntu-security-toolkit/`

3. **Documentation Requirements**:
   - Include help/usage information (`--help`)
   - Add inline comments for complex logic
   - Update README.md with usage examples

### Testing Infrastructure

The test suite uses bash-based testing with:
- Custom assertion functions in `tests/test_helpers.sh`
- Unit tests for individual scripts
- Integration tests for script interactions
- Mock functions for system commands

### Code Style
- Use consistent indentation (4 spaces)
- Include descriptive function names
- Add error handling for all external commands
- Use color output sparingly (RED for errors, GREEN for success, YELLOW for warnings)

## Claude Shell Integration

The `apps/agents/claude-shell/` directory contains a Docker-based environment for running Claude CLI operations in an isolated container. This provides:
- Sandboxed execution environment
- Version management
- Persistence through volume mounts
- Agent-friendly APIs

## Security Considerations

### Defensive Security Only
All scripts in this repository are designed for defensive security purposes:
- System hardening and monitoring
- Threat detection and prevention  
- Security audit and compliance
- Vulnerability assessment (defensive)
- **NO offensive security capabilities**
- **NO exploitation tools or techniques**

### Permission Requirements
- Most scripts require sudo/root access
- Scripts check permissions before executing
- Sensitive operations are logged for audit trails
- Configuration changes create backups

### Production Deployment
1. Review all scripts before execution
2. Test in non-production environment first
3. Customize configurations for your environment
4. Monitor logs after deployment
5. Keep the toolkit updated

### Data Protection
- No telemetry or data collection
- All logs stored locally
- Email reports optional and configurable
- No external services required (except package repos)