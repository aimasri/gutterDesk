#!/usr/bin/env bash
# ==============================================================================
# Title:           module-media-tailscale.sh
# Purpose:         Provisions Tailscale WireGuard Mesh Networking & Jellyfin Media Server
# Why This Design: Mobile clients and remote development hosts require secure,
#                  encrypted peer-to-peer communication without open public ports.
#                  Optionally provisions Jellyfin with hardware VA-API/QuickSync
#                  GPU transcoding permissions (/dev/dri/renderD128).
# Privilege:       Root (Requires sudo for repository keys, apt-get & systemctl)
# Subsystems:      Tailscale (WireGuard mesh), Jellyfin media daemon, systemd, UFW
# Idempotency:     Validates existing repositories and systemd services prior to installation.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

echo "=== [Tailscale & Media] Installing Mesh Networking & Optional Media Server ==="

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

# 1. Add Tailscale APT Repository
sudo mkdir -p /usr/share/keyrings
if [ ! -f /usr/share/keyrings/tailscale-archive-keyring.gpg ]; then
    echo "Configuring Tailscale repository keyring..."
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
fi

sudo apt-get update
sudo apt-get install -y tailscale

# Enable Tailscale service
sudo systemctl enable --now tailscaled

# Firewall configuration (if UFW is present)
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow in on tailscale0 comment 'Allow Tailscale mesh traffic' 2>/dev/null || true
fi

echo "✓ Tailscale installed and running."
echo "Run 'sudo tailscale up' to authenticate this machine into your Tailnet."

# 2. Optional Jellyfin Server Installation
echo ""
read -p "Do you want to install the Jellyfin Media Server on this machine? (y/N): " install_jf
if [[ "$install_jf" =~ ^[Yy]$ ]]; then
    echo "=== Installing Jellyfin Media Server ==="
    sudo mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/jellyfin.gpg ]; then
        curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg --yes
        cat << 'REPO' | sudo tee /etc/apt/sources.list.d/jellyfin.sources >/dev/null
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
REPO
    fi

    sudo apt-get update
    sudo apt-get install -y jellyfin

    # GPU Hardware Transcoding Permissions (VA-API / QuickSync)
    sudo usermod -aG render,video jellyfin 2>/dev/null || true

    # Enable Service
    sudo systemctl enable --now jellyfin
    echo "✓ Jellyfin media server is running on port 8096."
else
    echo "Skipping Jellyfin server installation (Tailscale-only mesh node)."
fi

echo "=== Tailscale & Media Provisioning Complete ==="
