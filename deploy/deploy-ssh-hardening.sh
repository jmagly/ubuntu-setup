#!/bin/bash

# deploy-ssh-hardening.sh
# This script deploys SSH hardening configuration and tests the connection
# WARNING: This script changes SSH configuration and may affect your ability to connect

set -e

# Function to print status messages
print_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to print colored output
print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to backup existing configuration
backup_config() {
    local config_file="$1"
    local backup_file="$config_file.backup.$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$config_file" ]; then
        print_status "Backing up existing configuration: $config_file"
        cp "$config_file" "$backup_file"
        print_success "Backup created: $backup_file"
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    local port="$1"
    local user="$2"
    local host="localhost"
    
    print_status "Testing SSH connection on port $port..."
    
    # Wait a moment for SSH to fully restart
    sleep 3
    
    # Test connection with timeout
    if timeout 10 ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$host" "echo 'SSH connection test successful'" 2>/dev/null; then
        print_success "SSH connection test successful on port $port"
        return 0
    else
        print_error "SSH connection test failed on port $port"
        return 1
    fi
}

# Check if running as root
check_root

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config/ssh"

# Configuration files
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
HARDENING_CONFIG="$CONFIG_DIR/sshd_config.d/99-hardening.conf"
BANNER_FILE="$CONFIG_DIR/banner.txt"
SYSTEM_BANNER="/etc/ssh/banner.txt"

# Check if configuration files exist
if [ ! -f "$HARDENING_CONFIG" ]; then
    print_error "Hardening configuration file not found: $HARDENING_CONFIG"
    exit 1
fi

if [ ! -f "$BANNER_FILE" ]; then
    print_error "Banner file not found: $BANNER_FILE"
    exit 1
fi

print_status "Starting SSH hardening deployment..."

# Create sshd_config.d directory if it doesn't exist
if [ ! -d "$SSHD_CONFIG_DIR" ]; then
    print_status "Creating sshd_config.d directory..."
    mkdir -p "$SSHD_CONFIG_DIR"
    chmod 755 "$SSHD_CONFIG_DIR"
fi

# Backup existing configuration
backup_config "$SSHD_CONFIG_DIR/99-hardening.conf"

# Deploy hardening configuration
print_status "Deploying SSH hardening configuration..."
cp "$HARDENING_CONFIG" "$SSHD_CONFIG_DIR/99-hardening.conf"
chmod 644 "$SSHD_CONFIG_DIR/99-hardening.conf"
print_success "Hardening configuration deployed"

# Deploy banner file
print_status "Deploying SSH banner..."
cp "$BANNER_FILE" "$SYSTEM_BANNER"
chmod 644 "$SYSTEM_BANNER"
print_success "Banner file deployed"

# Get the new SSH port from configuration
NEW_PORT=$(grep "^Port " "$SSHD_CONFIG_DIR/99-hardening.conf" | awk '{print $2}')
if [ -z "$NEW_PORT" ]; then
    print_warning "Could not determine new SSH port from configuration, using default 22"
    NEW_PORT=22
else
    print_info "SSH port will be changed to: $NEW_PORT"
fi

# Get allowed users from configuration
ALLOWED_USERS=$(grep "^AllowUsers " "$SSHD_CONFIG_DIR/99-hardening.conf" | awk '{print $2}')
if [ -z "$ALLOWED_USERS" ]; then
    print_warning "No AllowUsers specified in configuration"
    # Use current user as fallback
    ALLOWED_USERS=$(who am i | awk '{print $1}')
    if [ -z "$ALLOWED_USERS" ]; then
        ALLOWED_USERS=$(logname 2>/dev/null || echo "root")
    fi
fi

print_info "Allowed users: $ALLOWED_USERS"

# Check SSH configuration syntax
print_status "Checking SSH configuration syntax..."
if sshd -t; then
    print_success "SSH configuration syntax is valid"
else
    print_error "SSH configuration syntax is invalid. Please check the configuration files."
    exit 1
fi

# Configure firewall for new port
print_status "Configuring firewall for SSH port $NEW_PORT..."
if command -v ufw >/dev/null 2>&1; then
    # Remove old SSH rule if it exists
    ufw delete allow ssh 2>/dev/null || true
    # Add new SSH rule
    ufw allow "$NEW_PORT/tcp"
    print_success "Firewall configured for port $NEW_PORT"
else
    print_warning "UFW not found. Please manually configure firewall for port $NEW_PORT"
fi

# Restart SSH service
print_status "Restarting SSH service..."
if systemctl restart ssh; then
    print_success "SSH service restarted successfully"
else
    print_error "Failed to restart SSH service"
    exit 1
fi

# Test SSH connection
print_status "Testing SSH connection..."
if test_ssh_connection "$NEW_PORT" "$ALLOWED_USERS"; then
    print_success "SSH hardening deployment completed successfully!"
else
    print_warning "SSH connection test failed. This might be normal if you're not connected via SSH."
    print_info "Please test the connection manually from another terminal:"
    print_info "ssh -p $NEW_PORT $ALLOWED_USERS@$(hostname)"
fi

# Display configuration summary
echo
echo "========================================================"
echo "                    SSH HARDENING SUMMARY"
echo "========================================================"
echo "SSH Port: $NEW_PORT"
echo "Allowed Users: $ALLOWED_USERS"
echo "Password Authentication: Disabled"
echo "Root Login: Disabled"
echo "Public Key Authentication: Enabled"
echo "Max Auth Tries: 3"
echo "Max Sessions: 5"
echo "Client Alive Interval: 300 seconds"
echo "Log Level: VERBOSE"
echo "========================================================"
echo
echo "IMPORTANT:"
echo "• SSH is now configured on port $NEW_PORT"
echo "• Only users listed in AllowUsers can connect"
echo "• Password authentication is disabled"
echo "• Make sure you have SSH keys set up before disconnecting"
echo "• Test connection: ssh -p $NEW_PORT $ALLOWED_USERS@$(hostname)"
echo "========================================================"

# Check if current session is via SSH
if [ -n "$SSH_CLIENT" ]; then
    print_warning "You are currently connected via SSH."
    print_warning "The configuration has been applied, but you may need to reconnect using the new port."
    print_info "Current SSH connection: $SSH_CLIENT"
fi 