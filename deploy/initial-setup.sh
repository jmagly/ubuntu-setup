#!/bin/bash

# initial-setup.sh
# This script handles the initial setup of a fresh Ubuntu 24.04.2 system
# It should be run as root before creating the main user account

set -e

# Function to print status messages
print_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Check if running as root
check_root

# Update system packages
print_status "Updating system packages..."
apt update
apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    ufw \
    git \
    vim \
    htop \
    net-tools \
    fail2ban \
    auditd \
    apparmor \
    apparmor-utils

# Configure basic firewall
print_status "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# Configure basic system security
print_status "Configuring basic system security..."

# Disable root login via SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Configure SSH to use key-based authentication only
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH service
systemctl restart ssh

# Configure basic audit rules
print_status "Configuring basic audit rules..."
cat > /etc/audit/rules.d/audit.rules << EOF
# Delete all existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Monitor file access
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor system calls
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod

# Monitor login/logout events
-w /var/log/auth.log -p wa -k auth
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Monitor sudo usage
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Monitor system time changes
-w /etc/localtime -p wa -k time-change
-w /etc/timezone -p wa -k time-change
EOF

# Restart auditd
systemctl restart auditd

print_status "Initial system setup completed successfully!"
print_status "Next steps:"
print_status "1. Create a new user account with sudo privileges"
print_status "2. Set up SSH keys for the new user"
print_status "3. Switch to the new user account"
print_status "4. Run the master installer: sudo ./deploy/install-all.sh"
print_status "5. Verify installation: sudo ./deploy/verify-installation.sh" 