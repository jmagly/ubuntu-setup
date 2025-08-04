# Docker Standalone Installation

This directory contains the standalone Docker installation script, separate from the security toolkit.

## Quick Start

```bash
# Install Docker with standard settings
./install-docker.sh

# Install as root user
sudo ./install-docker.sh

# Install without test container
./install-docker.sh --skip-hello-world
```

## What Gets Installed

- Docker Engine (docker-ce)
- Docker CLI (docker-ce-cli)
- containerd runtime
- Docker Buildx plugin
- Docker Compose plugin

## Features

- Automatic Ubuntu version detection (20.04, 22.04, 24.04)
- Removes old Docker versions before installing
- Configures Docker for non-root usage
- Sets up log rotation and storage driver
- Verifies installation with hello-world container

## Post-Installation

After installation:

1. **For non-root Docker access**, either:
   - Log out and log back in
   - Run: `newgrp docker`

2. **Verify installation:**
   ```bash
   docker --version
   docker compose version
   docker run hello-world
   ```

3. **Check service status:**
   ```bash
   systemctl status docker
   ```

## Configuration

The installer creates `/etc/docker/daemon.json` with:
- JSON file logging with rotation
- Overlay2 storage driver
- Live restore enabled

## Troubleshooting

**Permission denied errors:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Service not starting:**
```bash
# Check logs
sudo journalctl -u docker -n 50

# Restart service
sudo systemctl restart docker
```

**Disk space issues:**
```bash
# Clean up unused resources
docker system prune -a
```

## Security Notes

- Adding users to the docker group grants root-equivalent privileges
- Consider using rootless Docker for enhanced security
- Always pull images from trusted registries
- Regularly update Docker to get security patches

## Uninstallation

To remove Docker:
```bash
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/containerd
sudo rm -rf /etc/docker
sudo groupdel docker
```