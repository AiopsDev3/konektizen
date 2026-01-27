#!/bin/bash
set -e

echo "🐳 Installing Docker Engine for WSL2 (Native Ubuntu)..."

# 1. Clean up old versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# 2. Update and Install Prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Start Docker Service (WSL2 specific)
echo "🚀 Starting Docker Service..."
sudo service docker start

# 7. Add current user to docker group (avoids sudo usage)
sudo usermod -aG docker $USER

echo "--------------------------------------------------------"
echo "✅ Docker installed successfully inside WSL2!"
echo "⚠️  CRITICAL: You must close this terminal and open a NEW one"
echo "    for the group changes to take effect."
echo "--------------------------------------------------------"
echo "To verify after restart, run: docker ps"
