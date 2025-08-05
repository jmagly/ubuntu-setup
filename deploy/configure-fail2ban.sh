#!/bin/bash

# configure-fail2ban.sh
# This script configures fail2ban with custom settings

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

# Create fail2ban configuration directory if it doesn't exist
print_status "Creating fail2ban configuration directory..."
mkdir -p /etc/fail2ban/jail.d

# Create main jail configuration
print_status "Creating main jail configuration..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban hosts for 24 hours
bantime = 86400
# Retry window of 10 minutes
findtime = 600
# Allow 3 retries before banning
maxretry = 3
# Ban both IPv4 and IPv6
banaction = iptables-multiport
# Send email notifications
destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mwl)s

# SSH protection
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 300
bantime = 3600

# Protect against repeated failed login attempts
[sshd-ddos]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 2
findtime = 300
bantime = 3600

# Protect against brute force attacks
[sshd-strong]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 1
findtime = 300
bantime = 86400
EOF

# Create custom filter for strong SSH protection
print_status "Creating custom SSH filter..."
cat > /etc/fail2ban/filter.d/sshd-strong.conf << EOF
[Definition]
failregex = ^%(__prefix_line)s(?:error: PAM: )?Authentication failure for .* from <HOST>( via \S+)?\s*$
            ^%(__prefix_line)s(?:error: PAM: )?User not known to the underlying authentication module for .* from <HOST>\s*$
            ^%(__prefix_line)sFailed (?:password|publickey) for .* from <HOST>(?: port \d+)?(?: ssh\d*)?\s*$
            ^%(__prefix_line)sConnection closed by authenticating user .* <HOST>(?: port \d+)?(?: ssh\d*)?\s*$
            ^%(__prefix_line)sReceived disconnect from <HOST>(?: port \d+)?(?: ssh\d*)?\s*$
            ^%(__prefix_line)sUser .+ from <HOST> not allowed because not listed in AllowUsers\s*$
            ^%(__prefix_line)sUser .+ from <HOST> not allowed because none of user's groups are listed in AllowGroups\s*$
ignoreregex =
EOF

# Create fail2ban.d configuration
print_status "Creating fail2ban.d configuration..."
cat > /etc/fail2ban/fail2ban.d/sshd-common.conf << EOF
[Definition]
allowipv6 = true
EOF

# Ensure fail2ban is enabled and started
print_status "Enabling and starting fail2ban service..."
systemctl enable fail2ban
systemctl start fail2ban

# Wait for the service to fully start
print_status "Waiting for fail2ban service to start..."
sleep 5

# Check if the service is running
if ! systemctl is-active --quiet fail2ban; then
    print_status "Fail2ban service failed to start. Checking status..."
    systemctl status fail2ban
    exit 1
fi

# Restart fail2ban to apply changes
print_status "Restarting fail2ban service to apply changes..."
systemctl restart fail2ban

# Wait for the service to fully restart
sleep 5

# Verify fail2ban status
print_status "Verifying fail2ban status..."
if ! fail2ban-client status; then
    print_status "Failed to get fail2ban status. Checking service status..."
    systemctl status fail2ban
    exit 1
fi

print_status "Fail2ban configuration completed successfully!" 