#!/bin/bash

# create-user.sh
# This script creates a new user with sudo privileges and sets up SSH access
# It should be run as root after initial-setup.sh

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

# Check if username is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1

# Create user
print_status "Creating user $USERNAME..."
useradd -m -s /bin/bash $USERNAME

# Set password
print_status "Setting password for $USERNAME..."
passwd $USERNAME

# Add user to sudo group
print_status "Adding $USERNAME to sudo group..."
usermod -aG sudo $USERNAME

# Create .ssh directory
print_status "Setting up SSH directory..."
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh

# Create authorized_keys file
touch /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Set ownership
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

print_status "User setup completed successfully!"
print_status "Next steps:"
print_status "1. Add your SSH public key to /home/$USERNAME/.ssh/authorized_keys"
print_status "2. Test SSH login as $USERNAME"
print_status "3. Switch to $USERNAME account"
print_status "4. Run the main deployment script" 