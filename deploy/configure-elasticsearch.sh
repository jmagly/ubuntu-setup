#!/bin/bash

# configure-elasticsearch.sh
# This script configures Elasticsearch with proper system settings

set -e

# Function to print status messages
print_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Check if running as root
check_root

# Configure system limits
print_status "Configuring system limits for Elasticsearch..."
cat > /etc/security/limits.d/elasticsearch.conf << EOF
elasticsearch soft nofile 65535
elasticsearch hard nofile 65535
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch soft nproc 4096
elasticsearch hard nproc 4096
EOF

# Configure system settings
print_status "Configuring system settings..."
cat > /etc/sysctl.d/elasticsearch.conf << EOF
vm.max_map_count=262144
fs.file-max=65535
EOF

# Apply system settings
print_status "Applying system settings..."
sysctl -p /etc/sysctl.d/elasticsearch.conf

# Configure Elasticsearch
print_status "Configuring Elasticsearch..."
cat > /etc/elasticsearch/elasticsearch.yml << EOF
cluster.name: my-application
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
xpack.security.http.ssl.enabled: true
xpack.security.transport.ssl.enabled: true
EOF

# Set proper permissions
print_status "Setting proper permissions..."
chown -R elasticsearch:elasticsearch /etc/elasticsearch
chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
chown -R elasticsearch:elasticsearch /var/log/elasticsearch

# Generate SSL certificates if they don't exist
print_status "Generating SSL certificates..."
if [ ! -f /etc/elasticsearch/certs/http_ca.crt ]; then
    /usr/share/elasticsearch/bin/elasticsearch-certutil http
fi

# Restart Elasticsearch
print_status "Restarting Elasticsearch service..."
systemctl daemon-reload
systemctl restart elasticsearch

# Wait for Elasticsearch to start
print_status "Waiting for Elasticsearch to start..."
sleep 10

# Check Elasticsearch status
print_status "Checking Elasticsearch status..."
if systemctl is-active --quiet elasticsearch; then
    print_status "Elasticsearch is running successfully!"
    print_status "You can access it at: https://localhost:9200"
    print_status "Note: You'll need to use the generated certificates for secure access"
else
    print_status "Elasticsearch failed to start. Checking logs..."
    journalctl -u elasticsearch -n 50
    exit 1
fi 