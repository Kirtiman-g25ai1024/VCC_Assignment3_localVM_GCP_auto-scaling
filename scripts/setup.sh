#!/bin/bash
# setup.sh — One-time setup for the local VM
# Run with: sudo bash scripts/setup.sh

set -e

echo "=========================================="
echo "  Auto-Scale Demo — Local VM Setup"
echo "=========================================="

# Update system
echo "[1/5] Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
echo "[2/5] Installing dependencies..."
apt install -y \
    python3 python3-pip \
    docker.io docker-compose \
    curl wget git htop sysstat net-tools

# Configure Docker
echo "[3/5] Configuring Docker..."
systemctl enable docker && systemctl start docker
usermod -aG docker $SUDO_USER

# Create project directory
echo "[4/5] Setting up project directory..."
mkdir -p /opt/autoscale-demo
cp -r "$(dirname "$0")/../"* /opt/autoscale-demo/

# Create log file
echo "[5/5] Creating log file..."
touch /var/log/autoscale.log
chmod 666 /var/log/autoscale.log

echo ""
echo "=========================================="
echo "  Setup complete!"
echo "  Next steps:"
echo "    1. cd /opt/autoscale-demo"
echo "    2. docker-compose up -d --build"
echo "    3. cd monitoring && docker-compose -f docker-compose.monitoring.yml up -d"
echo "    4. nohup bash scripts/monitor.sh &"
echo "=========================================="
