# Standalone Applications

This directory contains standalone installation scripts for applications that are **not** part of the core Ubuntu Security Toolkit. These applications are separated to maintain the security-focused nature of the main toolkit.

## Available Applications

### 1. Docker
Container runtime platform for running applications in isolated environments.
```bash
cd docker/
./install-docker.sh
```

### 2. Tezos Node
Blockchain node for the Tezos network.
```bash
cd tezos/octez/
./node-install.sh
```

### 3. Elasticsearch (Configuration Only)
Configuration script for Elasticsearch (requires manual installation first).
```bash
cd elasticsearch/
# See README.md for installation instructions
```

### 4. Development Tools
Reserved for future development environments.
```bash
cd development/
# Currently empty - reserved for future tools
```

## Why Separate?

These applications are maintained separately from the security toolkit because:

1. **Focus**: The main toolkit focuses exclusively on security hardening and monitoring
2. **Dependencies**: These apps have different dependency requirements
3. **Updates**: Application versions can be updated independently
4. **Optional**: Not everyone needs these applications
5. **Security**: Reduces the attack surface of the security toolkit itself

## Installation Order

If you need multiple applications:

1. **First**: Install the Ubuntu Security Toolkit
   ```bash
   cd ../
   sudo ./deploy/install-all.sh
   ```

2. **Second**: Install Docker (if needed by other apps)
   ```bash
   cd standalone-apps/docker/
   ./install-docker.sh
   ```

3. **Then**: Install specific applications as needed

## Security Considerations

- Each application may have its own security implications
- Review the README in each directory for security notes
- These are not security tools - they are applications that may need securing
- Consider the security toolkit's recommendations when running these services

## Support

These standalone applications are provided as-is. For support:
- Check the README in each application's directory
- Refer to the official documentation for each application
- Security concerns should still follow security toolkit best practices