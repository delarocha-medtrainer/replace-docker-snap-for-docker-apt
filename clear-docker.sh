#!/bin/bash

# Script title
echo "========================================================================="
echo "   Completely uninstalling Docker (including Snap) and reinstalling"
echo "   Configuring Docker detection to prevent automatic Snap installations"
echo "   Executing 'docker compose build --no-cache && up -d --force-recreate'"
echo "========================================================================="

# 1. Stop and remove containers, images, networks, and volumes
echo "Stopping and removing containers, images, networks, and volumes..."
if command -v docker &> /dev/null; then
  sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "No containers to stop."
  sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "No containers to remove."
  sudo docker rmi $(sudo docker images -q) 2>/dev/null || echo "No images to remove."
  sudo docker network rm $(sudo docker network ls -q) 2>/dev/null || echo "No networks to remove."
  sudo docker volume rm $(sudo docker volume ls -q) 2>/dev/null || echo "No volumes to remove."
else
  echo "Docker is not installed. Skipping removal of containers, images, etc."
fi

# 2. Uninstall Docker if installed via Snap
echo "Checking if Docker was installed via Snap..."
if snap list | grep -q 'docker'; then
  echo "Docker installed via Snap detected. Uninstalling..."
  sudo snap remove docker
else
  echo "No Docker installation found via Snap."
fi

# 3. Uninstall APT packages for Docker
echo "Uninstalling Docker APT packages..."
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || echo "No Docker APT packages to uninstall."

# 4. Remove Docker files and directories
echo "Removing Docker files and directories..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg

# 5. Update system and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# 6. Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 7. Add Docker repository
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 8. Update package index
echo "Updating package index..."
sudo apt update

# 9. Install Docker Engine and plugins
echo "Installing Docker Engine and plugins..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 10. Verify installation
echo "Verifying installation..."
sudo docker --version
sudo docker compose version

# 11. Automatically add user to 'docker' group
echo "Adding user '$USER' to 'docker' group..."
sudo usermod -aG docker $USER

# Apply group changes without restarting session
echo "Applying group changes..."
newgrp docker <<< ""

# 12. Configure Docker detection to prevent automatic Snap installations
echo "Configuring Docker detection to prevent automatic Snap installations..."
echo "This creates environment variables and fake Snap structure so applications"
echo "detect Docker as already installed and don't try to install it via Snap."
sudo tee /etc/profile.d/docker-detection.sh > /dev/null << 'EOF'
# Docker detection for applications - prevents Snap installation
export DOCKER_BINARY=$(which docker)
export DOCKER_SOCKET=/var/run/docker.sock
export PATH="/snap/docker/current/bin:$PATH"
export DOCKER_INSTALLED=true
export DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
EOF

sudo chmod +x /etc/profile.d/docker-detection.sh

# Create fake Snap structure to fool dependency detection
echo "Creating fake Snap structure to prevent dependency installations..."
sudo mkdir -p /snap/docker/current/bin
sudo mkdir -p /snap/docker/current/meta

# Create symlink to real Docker binary
sudo ln -sf /usr/bin/docker /snap/docker/current/bin/docker

# Create fake metadata file
sudo tee /snap/docker/current/meta/snap.yaml > /dev/null << 'EOF'
name: docker
version: system-redirect
summary: Docker (system installation)
description: Redirected to system Docker installation
architectures: [amd64]
EOF

# Load the configuration
source /etc/profile.d/docker-detection.sh

# 13. Log in to private registry
echo "Logging in to medtrainer.azurecr.io..."
echo "<Token>" | docker login medtrainer.azurecr.io -u developers -p <password>

# 14. Bring down current project (if any) and remove its volumes and orphans
echo "Running 'docker compose down --volumes --remove-orphans' to clean current project..."
docker compose down --volumes --remove-orphans 2>/dev/null || echo "No active project to bring down."

# 15. Prune unused data (containers, networks, build cache)
echo "Running 'docker system prune -f' to clean unused data..."
docker system prune -f

# 16. Full system prune (remove everything: images, containers, volumes, cache)
echo "Running 'docker system prune -a -f' for full cleanup..."
docker system prune -a -f

# 17. Check if docker-compose.yml exists
if [ -f "docker-compose.yml" ]; then
  echo "Found 'docker-compose.yml'. Executing 'docker compose build --no-cache && up -d --force-recreate'..."
  docker compose build --no-cache
  docker compose up -d --force-recreate
else
  echo "No 'docker-compose.yml' found. Skipping build and up."
fi

echo "========================================================================="
echo "✅ Docker has been completely uninstalled (including Snap) and reinstalled successfully."
echo "✅ User '$USER' has been added to the 'docker' group."
echo "✅ Docker detection configured to prevent automatic Snap installations."
echo "✅ Logged in to medtrainer.azurecr.io."
echo "✅ Project cleaned with 'docker compose down --volumes --remove-orphans'."
echo "✅ System cleaned with 'docker system prune -f' and 'docker system prune -a -f'."
echo "✅ Executed 'docker compose build --no-cache && up -d --force-recreate' (if docker-compose.yml exists)."
echo "========================================================================="
