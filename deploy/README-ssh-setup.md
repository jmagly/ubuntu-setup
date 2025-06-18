# SSH Key Setup for GitHub

This directory contains scripts to help set up SSH keys for secure Git operations with GitHub and other Git hosting services.

## generate-ssh-key.sh

A user-friendly script that generates SSH keys and helps you set them up with GitHub.

### Features

- **Interactive passphrase option**: Choose whether to add a passphrase for enhanced security
- **Automatic backup**: Safely handles existing keys by backing them up
- **GitHub integration**: Displays the public key ready for GitHub setup
- **Connection testing**: Optional GitHub connection test
- **Proper permissions**: Sets correct file permissions automatically

### Usage

```bash
# Make the script executable (if not already)
chmod +x deploy/generate-ssh-key.sh

# Run the script
./deploy/generate-ssh-key.sh
```

### What the script does

1. **Checks for existing keys**: If an SSH key already exists, offers options to use it or generate a new one
2. **Creates SSH directory**: Ensures the `~/.ssh` directory exists with proper permissions
3. **Generates key**: Creates an ED25519 SSH key (recommended for security and performance)
4. **Passphrase option**: Asks if you want to add a passphrase for extra security
5. **Sets permissions**: Ensures proper file permissions (600 for private key, 644 for public key)
6. **Starts SSH agent**: Adds the key to your SSH agent for immediate use
7. **Displays public key**: Shows the public key ready to copy to GitHub
8. **Provides instructions**: Gives step-by-step instructions for GitHub setup
9. **Tests connection**: Optionally tests the GitHub SSH connection

### GitHub Setup Steps

After running the script:

1. Copy the displayed public key
2. Go to [GitHub Settings → SSH and GPG keys](https://github.com/settings/keys)
3. Click "New SSH key"
4. Give it a descriptive title (e.g., "Ubuntu Setup - myhostname")
5. Paste the public key
6. Click "Add SSH key"

### Security Considerations

- **Passphrase**: Adding a passphrase provides an extra layer of security
- **Key type**: Uses ED25519, which is more secure and faster than RSA
- **Permissions**: Automatically sets restrictive permissions on private keys
- **Backup**: Existing keys are safely backed up before replacement

### Troubleshooting

**Key not working with GitHub?**
- Ensure you copied the entire public key (starts with `ssh-ed25519`)
- Check that the key was added to your GitHub account
- Test with: `ssh -T git@github.com`

**Passphrase issues?**
- If you forgot your passphrase, you'll need to generate a new key
- To change a passphrase: `ssh-keygen -p -f ~/.ssh/id_ed25519`

**SSH agent not working?**
- Add to your shell startup: `echo 'ssh-add ~/.ssh/id_ed25519' >> ~/.bashrc`
- Or manually add: `ssh-add ~/.ssh/id_ed25519`

### File Locations

- **Private key**: `~/.ssh/id_ed25519`
- **Public key**: `~/.ssh/id_ed25519.pub`
- **Backup keys**: `~/.ssh/id_ed25519.backup.YYYYMMDD-HHMMSS`

### Integration with Ubuntu Setup

This script is part of the Ubuntu security setup repository and works alongside other security tools. It's designed to be run after the initial system setup but before cloning repositories that require SSH authentication. 