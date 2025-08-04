# Development Tools

This directory contains development environments and tools, separate from the security toolkit.

## Available Tools

### 1. Node.js LTS
Install Node.js 20.x LTS and npm for JavaScript development.
```bash
cd nodejs/
./install-nodejs.sh
```

### 2. Claude CLI
Install the Claude command-line interface for AI assistance.
```bash
cd claude-cli/
./install-claude.sh
```

## Installation Order

1. **Install Node.js first** (required for Claude CLI)
2. **Then install Claude CLI**

## Quick Install Both

```bash
# Install Node.js
./nodejs/install-nodejs.sh

# Install Claude CLI
./claude-cli/install-claude.sh
```

## Why Separate?

Development tools are kept separate from security tools because:
- Different use cases and audiences
- Independent update cycles
- May introduce additional attack surface
- Not required for security operations

## Security Considerations

- Node.js opens network ports if you run servers
- Keep npm packages updated to avoid vulnerabilities
- Claude CLI requires API key - store it securely
- Review package.json files before npm install