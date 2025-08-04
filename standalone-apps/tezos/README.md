# Tezos Node Standalone Installation

This directory contains the standalone Tezos/Octez node installation script, separate from the security toolkit.

## Prerequisites

- Docker must be installed first (use `../docker/install-docker.sh`)
- At least 20GB free disk space (more for archive nodes)
- Stable internet connection for blockchain synchronization

## Quick Start

```bash
# Install Tezos node with interactive setup
./octez/node-install.sh

# The script will prompt for:
# - Network selection (mainnet/ghostnet)
# - History mode (rolling/full/archive)
# - Data directory location
```

## What Gets Installed

- Tezos node (via Docker container)
- Node configuration
- Blockchain data
- Systemd service for automatic startup (optional)

## Storage Requirements

- **Rolling mode**: ~10GB (keeps recent history only)
- **Full mode**: ~50GB (keeps full blockchain history)
- **Archive mode**: ~500GB+ (keeps all historical states)

## Features

- Interactive network and mode selection
- Automatic snapshot download for faster sync
- Progress monitoring during sync
- RPC endpoint configuration
- Optional systemd service setup

## Post-Installation

After installation:

1. **Check node status:**
   ```bash
   docker exec -it tezos-node octez-node status
   ```

2. **Monitor synchronization:**
   ```bash
   docker logs -f tezos-node
   ```

3. **Access RPC endpoint:**
   ```bash
   curl http://localhost:8732/chains/main/blocks/head
   ```

## Configuration

The node configuration is stored in the data directory you selected during installation.

**Default ports:**
- P2P: 9732
- RPC: 8732 (localhost only by default)

**To expose RPC externally (security risk):**
Edit the docker run command to bind to all interfaces:
```bash
-p 0.0.0.0:8732:8732
```

## Maintenance

**Update node:**
```bash
docker pull tezos/tezos-bare:latest
docker stop tezos-node
docker rm tezos-node
# Re-run installation script
```

**Backup data:**
```bash
# Stop node first
docker stop tezos-node
# Backup data directory
tar -czf tezos-backup.tar.gz /path/to/data/dir
```

**Check disk usage:**
```bash
du -sh /path/to/data/dir
```

## Troubleshooting

**Node not syncing:**
```bash
# Check logs
docker logs tezos-node --tail 50

# Restart node
docker restart tezos-node
```

**RPC not accessible:**
```bash
# Check if node is running
docker ps | grep tezos-node

# Check if fully synced
docker exec -it tezos-node octez-node status
```

**Disk space issues:**
```bash
# Switch to rolling mode to save space
# Requires reinstallation with rolling mode selected
```

## Security Considerations

- Keep RPC endpoint local unless absolutely necessary
- Use firewall rules to restrict access
- Regularly update the node software
- Monitor logs for suspicious activity
- Consider running behind a reverse proxy with authentication

## Uninstallation

To remove Tezos node:
```bash
# Stop and remove container
docker stop tezos-node
docker rm tezos-node

# Remove image
docker rmi tezos/tezos-bare:latest

# Remove data (WARNING: this deletes blockchain data)
rm -rf /path/to/data/dir
```

## Resources

- [Tezos Documentation](https://tezos.gitlab.io/)
- [Octez Documentation](https://tezos.gitlab.io/introduction/tezos.html)
- [Tezos RPC Reference](https://tezos.gitlab.io/api/rpc.html)