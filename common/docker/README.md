# Docker Installation Has Moved

Docker installation has been moved to maintain the security-focused nature of the Ubuntu Security Toolkit.

## New Location

Docker installation is now available in:
```
standalone-apps/docker/install-docker.sh
```

## Installation

```bash
cd ../../standalone-apps/docker/
./install-docker.sh
```

## Why This Change?

- The main toolkit focuses exclusively on security hardening and monitoring
- Docker is an application platform, not a security tool
- Separation allows independent updates and maintenance
- Reduces the attack surface of the security toolkit

## See Also

- `standalone-apps/README.md` - Overview of all standalone applications
- `standalone-apps/docker/README.md` - Docker-specific documentation