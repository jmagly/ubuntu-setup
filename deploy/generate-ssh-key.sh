#!/bin/bash

# generate-ssh-key.sh
# This script generates a new SSH key for the current user and displays the public key
# for easy setup with GitHub or other Git hosting services

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

# Get current user
CURRENT_USER=$(whoami)
SSH_DIR="$HOME/.ssh"
KEY_NAME="id_ed25519"
KEY_PATH="$SSH_DIR/$KEY_NAME"

# Check if SSH directory exists, create if not
if [ ! -d "$SSH_DIR" ]; then
    print_status "Creating SSH directory..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    print_success "SSH directory created: $SSH_DIR"
fi

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    print_warning "SSH key already exists at: $KEY_PATH"
    echo
    echo "Options:"
    echo "1. Use existing key (display public key)"
    echo "2. Generate new key (backup existing key)"
    echo "3. Exit"
    echo
    read -p "Choose an option (1-3): " choice
    
    case $choice in
        1)
            print_info "Using existing SSH key..."
            ;;
        2)
            print_status "Backing up existing key..."
            BACKUP_PATH="$KEY_PATH.backup.$(date +%Y%m%d-%H%M%S)"
            cp "$KEY_PATH" "$BACKUP_PATH"
            cp "$KEY_PATH.pub" "$BACKUP_PATH.pub"
            print_success "Existing key backed up to: $BACKUP_PATH"
            rm "$KEY_PATH" "$KEY_PATH.pub"
            print_status "Generating new SSH key..."
            ;;
        3)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option. Exiting..."
            exit 1
            ;;
    esac
fi

# Generate new SSH key if it doesn't exist or user chose to generate new one
if [ ! -f "$KEY_PATH" ]; then
    print_status "Generating new SSH key for user: $CURRENT_USER"
    print_status "Key type: ED25519 (recommended for security and performance)"
    
    # Ask user if they want to add a passphrase
    echo
    echo "========================================================"
    echo "                    SSH KEY SECURITY"
    echo "========================================================"
    echo "Do you want to add a passphrase to your SSH key?"
    echo "• Passphrase: More secure, but you'll need to enter it each time"
    echo "• No passphrase: Less secure, but more convenient for automation"
    echo "========================================================"
    echo
    read -p "Add passphrase to SSH key? (y/N): " add_passphrase
    
    if [[ $add_passphrase =~ ^[Yy]$ ]]; then
        print_info "Generating SSH key with passphrase..."
        print_warning "You will be prompted to enter a passphrase twice."
        print_info "Make sure to remember this passphrase!"
        echo
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$CURRENT_USER@$(hostname)"
    else
        print_info "Generating SSH key without passphrase..."
        ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$CURRENT_USER@$(hostname)"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "SSH key generated successfully!"
    else
        print_error "Failed to generate SSH key"
        exit 1
    fi
fi

# Set proper permissions
print_status "Setting proper permissions..."
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

# Start SSH agent and add key
print_status "Starting SSH agent and adding key..."
eval "$(ssh-agent -s)"

# Check if key has a passphrase by trying to add it
if ssh-add "$KEY_PATH" 2>/dev/null; then
    print_success "SSH key added to agent successfully!"
else
    print_warning "SSH key requires a passphrase or couldn't be added to agent."
    print_info "You may need to run 'ssh-add ~/.ssh/id_ed25519' manually and enter your passphrase."
    print_info "Or add 'ssh-add ~/.ssh/id_ed25519' to your ~/.bashrc for automatic loading."
fi

# Display the public key
echo
echo "========================================================"
echo "                    SSH PUBLIC KEY"
echo "========================================================"
echo "Copy the key below and add it to your GitHub account:"
echo "GitHub → Settings → SSH and GPG keys → New SSH key"
echo "========================================================"
echo
cat "$KEY_PATH.pub"
echo
echo "========================================================"
echo "                    NEXT STEPS"
echo "========================================================"
echo "1. Copy the public key above"
echo "2. Go to GitHub.com → Settings → SSH and GPG keys"
echo "3. Click 'New SSH key'"
echo "4. Give it a title (e.g., 'Ubuntu Setup - $(hostname)')"
echo "5. Paste the key and click 'Add SSH key'"
echo "6. Test the connection with: ssh -T git@github.com"
echo "========================================================"

# Test GitHub connection if requested
echo
read -p "Would you like to test the GitHub connection now? (y/N): " test_connection

if [[ $test_connection =~ ^[Yy]$ ]]; then
    print_status "Testing GitHub SSH connection..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub SSH connection successful!"
    else
        print_warning "GitHub SSH connection test completed. Check the output above."
        print_info "If you see 'Hi username! You've successfully authenticated...', the setup is working."
    fi
fi

print_success "SSH key setup completed!"
echo
echo "========================================================"
echo "                    ADDITIONAL NOTES"
echo "========================================================"
if [[ $add_passphrase =~ ^[Yy]$ ]]; then
    echo "• Your SSH key has a passphrase for enhanced security"
    echo "• You'll need to enter the passphrase when using the key"
    echo "• To avoid entering it repeatedly, use: ssh-add ~/.ssh/id_ed25519"
    echo "• To add to your shell startup: echo 'ssh-add ~/.ssh/id_ed25519' >> ~/.bashrc"
else
    echo "• Your SSH key has no passphrase for convenience"
    echo "• For enhanced security, consider adding a passphrase later"
    echo "• To add a passphrase: ssh-keygen -p -f ~/.ssh/id_ed25519"
fi
echo "• Your public key is ready to add to GitHub"
echo "========================================================" 