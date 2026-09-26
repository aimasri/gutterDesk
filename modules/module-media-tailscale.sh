#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Tailscale and Jellyfin ==="

# 1. Add Tailscale APT Repository
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" | sudo tee /etc/apt/sources.list.d/tailscale.list

# 2. Add Jellyfin APT Repository
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
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/media-tailscale.list" | tr '\n' ' ')

# 3. GPU Transcoding Permissions
sudo usermod -aG render,video jellyfin || true

# 4. Enable Services
sudo systemctl enable --now jellyfin
sudo systemctl enable --now tailscaled

echo "Jellyfin media server and Tailscale daemon are running."
echo "Run 'sudo tailscale up' to connect this machine to your Tailnet."
