#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Tailscale and Networking ==="

# 1. Add Tailscale APT Repository
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" | sudo tee /etc/apt/sources.list.d/tailscale.list

sudo apt-get update
sudo apt-get install -y tailscale

# Enable Tailscale service
sudo systemctl enable --now tailscaled

# Firewall configuration (if UFW is present)
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow in on tailscale0 comment 'Allow Tailscale mesh traffic' || true
fi

echo "✓ Tailscale installed and running."
echo "Run 'sudo tailscale up' to connect this machine to your Tailnet."

# 2. Optional Jellyfin Server Installation
echo ""
read -p "Do you want to install the Jellyfin Media Server on this machine? (y/N): " install_jf
if [[ "$install_jf" =~ ^[Yy]$ ]]; then
    echo "=== Installing Jellyfin Media Server ==="
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg --yes
    cat << 'REPO' | sudo tee /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
REPO

    sudo apt-get update
    sudo apt-get install -y jellyfin

    # GPU Transcoding Permissions
    sudo usermod -aG render,video jellyfin || true

    # Enable Service
    sudo systemctl enable --now jellyfin
    echo "✓ Jellyfin media server is running on port 8096."
else
    echo "Skipping Jellyfin server installation (Tailscale-only mesh node)."
fi
