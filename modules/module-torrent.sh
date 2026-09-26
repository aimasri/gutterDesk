#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Torrent Client & Firewall ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/torrent.list" | tr '\n' ' ')

echo "Configuring UFW firewall rules..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh comment 'Allow SSH'
sudo ufw allow in on tailscale0 comment 'Allow Tailscale mesh traffic' || true
sudo ufw --force enable

echo "Transmission and UFW firewall configured successfully."
