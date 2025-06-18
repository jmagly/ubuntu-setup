#!/bin/bash

# Script to install Docker Engine and Docker Compose on Ubuntu 24.04

# Update package index and install prerequisites
echo "Updating package index and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker's GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker's repository
echo "Adding Docker's repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
echo "Updating package index..."
sudo apt-get update

# Install Docker Engine and Docker Compose plugin
echo "Installing Docker Engine and Docker Compose plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify the Docker installation
echo "Verifying Docker installation..."
sudo docker run hello-world

# Post-installation steps to manage Docker as a non-root user
echo "Configuring Docker to be used without sudo..."
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker Compose installation
echo "Verifying Docker Compose plugin installation..."
docker compose version

echo "Docker Engine and Docker Compose have been successfully installed and configured!"