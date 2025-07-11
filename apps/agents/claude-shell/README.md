# Claude CLI Shell - Docker Runtime Environment

A secure, versioned Docker-based shell environment for running the Claude CLI code agent with enhanced operational freedom and controlled execution boundaries.

## 📋 Overview

This shell provides a containerized runtime environment for the [Claude CLI](https://github.com/danielbodnar/claude-cli), enabling AI agents to execute code, manage files, and interact with system resources within a safe, isolated Docker container. The shell is designed to be consumed by generative agents, providing clear interfaces and predictable behaviors.

## 🎯 Purpose

- **Isolation**: Run Claude CLI operations in a sandboxed Docker environment
- **Versioning**: Maintain consistent runtime environments across different executions
- **Agent-Friendly**: Designed with clear APIs and patterns for AI agent consumption
- **Persistence**: Optional volume mounting for preserving generated outputs
- **Security**: Controlled access to system resources with configurable permissions

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         Host System                     │
│  ┌─────────────────────────────────┐   │
│  │     Claude CLI Shell            │   │
│  │  ┌─────────────────────────┐   │   │
│  │  │   Docker Container      │   │   │
│  │  │  ┌─────────────────┐   │   │   │
│  │  │  │  Claude CLI     │   │   │   │
│  │  │  │  + Node.js      │   │   │   │
│  │  │  │  + Bun.js       │   │   │   │
│  │  │  └─────────────────┘   │   │   │
│  │  │  Volume Mounts      │   │   │   │
│  │  │  Network Config     │   │   │   │
│  │  └─────────────────────────┘   │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose (optional)
- Git

### Installation

```bash
# Clone this repository
git clone <your-repo-url> claude-cli-shell
cd claude-cli-shell

# Build the Docker image
./scripts/build.sh

# Run interactive shell
./scripts/run.sh
```

## 📦 Core Components

### 1. Dockerfile
- Base image with Node.js and Bun.js
- Claude CLI installation
- Security configurations
- Working directory setup

### 2. Shell Scripts
- `build.sh` - Build Docker image with version tagging
- `run.sh` - Launch container with appropriate mounts
- `exec.sh` - Execute commands within running container
- `cleanup.sh` - Remove containers and optionally images

### 3. Configuration
- `config/shell.config.json` - Runtime configuration
- `config/claude-cli.config.ts` - Claude CLI specific settings
- `.env` - Environment variables (API keys, etc.)

## 🔧 Usage Patterns

### For Generative Agents

#### 1. Execute Claude CLI Commands
```bash
# Pattern: ./exec.sh claude-cli [command] [options]
./exec.sh claude-cli chat --template typescript
./exec.sh claude-cli replay abc123
```

#### 2. File Operations
```bash
# Create files in container
./exec.sh echo "content" > /workspace/output.txt

# Copy files from container
./scripts/copy-from.sh /workspace/output.txt ./local-output.txt
```

#### 3. Session Management
```bash
# List sessions
./exec.sh ls /workspace/.claude-sessions

# Export session
./scripts/export-session.sh session-id
```

### Configuration Options

```json
{
  "shell": {
    "version": "1.0.0",
    "container": {
      "name": "claude-cli-agent",
      "image": "claude-cli-shell:latest",
      "volumes": {
        "workspace": "/workspace",
        "sessions": "/workspace/.claude-sessions",
        "output": "/workspace/output"
      }
    },
    "permissions": {
      "network": true,
      "fileWrite": true,
      "maxMemory": "2g",
      "maxCpu": "2"
    }
  }
}
```

## 📁 Directory Structure

```
claude-cli-shell/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── .env.example
├── config/
│   ├── shell.config.json
│   └── claude-cli.config.ts
├── scripts/
│   ├── build.sh
│   ├── run.sh
│   ├── exec.sh
│   ├── cleanup.sh
│   ├── copy-from.sh
│   ├── copy-to.sh
│   └── export-session.sh
├── workspace/          # Mounted as container volume
│   ├── .claude-sessions/
│   ├── output/
│   └── temp/
└── logs/
    └── claude-cli.log
```

## 🛡️ Security Considerations

1. **API Key Management**: Store API keys in `.env` file, never in code
2. **Network Isolation**: Configurable network access
3. **Resource Limits**: CPU and memory constraints
4. **Volume Permissions**: Read-only mounts where appropriate
5. **User Permissions**: Run as non-root user in container

## 🔄 Version Management

```bash
# Tag format: v{major}.{minor}.{patch}
./scripts/build.sh --tag v1.2.3

# Run specific version
./scripts/run.sh --version v1.2.3
```

## 📊 Monitoring & Logs

```bash
# View container logs
./scripts/logs.sh

# Monitor resource usage
./scripts/monitor.sh

# Export logs
./scripts/export-logs.sh --date 2025-07-11
```

## 🤖 Agent Integration Guide

### Input Format
Agents should provide inputs in the following format:
```json
{
  "command": "chat",
  "template": "typescript",
  "message": "Create a REST API",
  "options": {
    "save": true,
    "outputDir": "/workspace/output"
  }
}
```

### Output Format
The shell returns structured outputs:
```json
{
  "status": "success",
  "sessionId": "abc123",
  "files": [
    {
      "path": "/workspace/output/api.ts",
      "language": "typescript",
      "size": 1024
    }
  ],
  "logs": "/logs/session-abc123.log"
}
```

## 🚧 Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   # Check Docker daemon
   docker info
   # Rebuild image
   ./scripts/build.sh --clean
   ```

2. **Permission denied**
   ```bash
   # Fix volume permissions
   ./scripts/fix-permissions.sh
   ```

3. **API key issues**
   ```bash
   # Verify environment
   ./scripts/check-env.sh
   ```

## 🤝 Contributing

This shell is designed to be extended by AI agents. When contributing:

1. Maintain backwards compatibility
2. Document all changes clearly
3. Include examples for agent consumption
4. Test with various Claude CLI commands

## 📄 License

Same as the Claude CLI project - CC0-1.0 license

## 🔗 Related Projects

- [Claude CLI](https://github.com/danielbodnar/claude-cli) - The CLI tool this shell wraps
- [Anthropic API](https://docs.anthropic.com) - Claude API documentation
- [Bun.js](https://bun.sh) - JavaScript runtime used by Claude CLI

---

**Note for AI Agents**: This shell provides a safe execution environment. All file operations are contained within the Docker container unless explicitly exported. Use the provided scripts for predictable operations.