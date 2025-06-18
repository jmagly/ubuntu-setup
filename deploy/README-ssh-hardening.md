# SSH Hardening Deployment

This script deploys comprehensive SSH hardening configurations to enhance system security.

## deploy-ssh-hardening.sh

A comprehensive script that deploys SSH hardening configurations, restarts the SSH service, and tests the connection.

### ⚠️ IMPORTANT WARNINGS

- **This script changes SSH configuration and may affect your ability to connect**
- **Password authentication will be disabled**
- **SSH port will be changed to 2424**
- **Only specified users will be allowed to connect**
- **Make sure you have SSH keys set up before running this script**

### Features

- **Automatic backup**: Backs up existing SSH configurations before deployment
- **Configuration validation**: Checks SSH configuration syntax before applying
- **Firewall configuration**: Automatically configures UFW for the new SSH port
- **Connection testing**: Tests SSH connection after deployment
- **Comprehensive logging**: Provides detailed status messages throughout the process
- **Safety checks**: Validates configuration and warns about potential issues

### Security Hardening Applied

Based on the `99-hardening.conf` configuration:

- **Port change**: SSH moved from port 22 to port 2424
- **Password authentication**: Disabled
- **Root login**: Disabled
- **Public key authentication**: Enabled
- **User restrictions**: Only specified users can connect
- **Session limits**: Max 3 auth tries, 5 sessions per connection
- **Connection timeouts**: 300-second client alive interval
- **Banner**: Custom security banner displayed on login
- **Logging**: Verbose logging enabled
- **Protocol**: SSH protocol 2 only
- **Forwarding**: Agent and TCP forwarding disabled

### Prerequisites

1. **SSH keys must be set up** before running this script
2. **Root access** required (run with sudo)
3. **UFW firewall** (optional, for automatic firewall configuration)
4. **Valid SSH configuration** files in the config directory

### Usage

```bash
# Make the script executable
chmod +x deploy/deploy-ssh-hardening.sh

# Run the script (requires root privileges)
sudo ./deploy/deploy-ssh-hardening.sh
```

### What the script does

1. **Validates prerequisites**: Checks for required files and permissions
2. **Backs up existing config**: Creates timestamped backups of current SSH configuration
3. **Deploys configuration**: Copies hardening config and banner files to system locations
4. **Validates syntax**: Checks SSH configuration syntax before applying
5. **Configures firewall**: Updates UFW rules for the new SSH port
6. **Restarts SSH service**: Applies the new configuration
7. **Tests connection**: Verifies SSH is working on the new port
8. **Provides summary**: Shows configuration details and next steps

### Configuration Files

- **Hardening config**: `deploy/config/ssh/sshd_config.d/99-hardening.conf`
- **Banner file**: `deploy/config/ssh/banner.txt`
- **System locations**:
  - `/etc/ssh/sshd_config.d/99-hardening.conf`
  - `/etc/ssh/banner.txt`

### Backup Files

The script creates timestamped backups of existing configurations:
- `/etc/ssh/sshd_config.d/99-hardening.conf.backup.YYYYMMDD-HHMMSS`

### Testing the Deployment

After running the script, test the SSH connection:

```bash
# Test from another machine
ssh -p 2424 username@hostname

# Test locally
ssh -p 2424 username@localhost
```

### Troubleshooting

**SSH connection fails after deployment:**
1. Check if you're using the correct port (2424)
2. Verify your SSH key is properly set up
3. Ensure your username is in the AllowUsers list
4. Check SSH service status: `systemctl status ssh`
5. View SSH logs: `journalctl -u ssh`

**Firewall issues:**
- If UFW is not available, manually configure your firewall for port 2424
- For iptables: `iptables -A INPUT -p tcp --dport 2424 -j ACCEPT`

**Configuration syntax errors:**
- Check the configuration file: `cat /etc/ssh/sshd_config.d/99-hardening.conf`
- Test syntax manually: `sshd -t`
- Restore from backup if needed

**Reverting changes:**
```bash
# Stop SSH service
sudo systemctl stop ssh

# Restore backup (replace with actual backup filename)
sudo cp /etc/ssh/sshd_config.d/99-hardening.conf.backup.YYYYMMDD-HHMMSS /etc/ssh/sshd_config.d/99-hardening.conf

# Restart SSH service
sudo systemctl start ssh
```

### Integration with Ubuntu Setup

This script is part of the Ubuntu security setup repository and should be run after:
1. Initial system setup (`initial-setup.sh`)
2. User creation (`create-user.sh`)
3. SSH key generation (`generate-ssh-key.sh`)

### Security Benefits

- **Reduced attack surface**: Non-standard port and disabled password auth
- **Access control**: Only specified users can connect
- **Session management**: Limits on authentication attempts and sessions
- **Audit trail**: Verbose logging for security monitoring
- **Legal protection**: Security banner establishes monitoring consent

### Monitoring

After deployment, monitor SSH access:
```bash
# View SSH logs
journalctl -u ssh -f

# Check failed login attempts
grep "Failed password" /var/log/auth.log

# Monitor SSH connections
ss -tulpn | grep :2424
``` 