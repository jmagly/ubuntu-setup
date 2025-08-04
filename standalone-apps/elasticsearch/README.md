# Elasticsearch Standalone Configuration

This directory contains Elasticsearch configuration scripts, separate from the security toolkit.

## Prerequisites

- Elasticsearch must be installed first (this script only configures it)
- Java runtime environment
- At least 4GB RAM recommended

## Configuration Script

The `configure-elasticsearch.sh` script sets up:
- Single-node configuration
- Security settings
- SSL/TLS configuration  
- Memory limits
- Bind to localhost only

## Installation

1. **Install Elasticsearch first:**
   ```bash
   # Add Elastic repository and install
   wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
   echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
   sudo apt update
   sudo apt install elasticsearch
   ```

2. **Run configuration script:**
   ```bash
   sudo ./configure-elasticsearch.sh
   ```

## Security Notes

- By default, binds to localhost only (127.0.0.1:9200)
- Enable authentication in production
- Use SSL/TLS for external connections
- Regularly update Elasticsearch
- Monitor logs for suspicious activity

## Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Security Best Practices](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-minimal-setup.html)