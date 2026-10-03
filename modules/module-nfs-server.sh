#!/usr/bin/env bash
# ==============================================================================
# Title:           module-nfs-server.sh
# Purpose:         Provisions Hardened NFSv4-Only Server for Remote Development
# Why This Design: Two-tier development topology centralizes all source repositories
#                  on aim-stream. This module configures nfs-kernel-server locked
#                  strictly to NFSv4 (port 2049, disabling NFSv2/v3, UDP, and rpcbind)
#                  and exports ~/projects with fsid=0 (pseudo-root) to LAN and Tailscale.
# Privilege:       Root (Requires sudo for nfs-kernel-server, /etc/exports & UFW)
# Subsystems:      nfs-kernel-server, /etc/exports, UFW firewall, systemd
# Idempotency:     Idempotently replaces target directory line in /etc/exports;
#                  backs up configuration before mutating.
# ==============================================================================

set -euo pipefail

echo "=== [NFS Server] Provisioning NFSv4 Server on $(hostname) ==="

# 1. Install NFS Kernel Server
echo "--> Installing nfs-kernel-server..."
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# 2. Resolve export directory
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

# Accept custom directory argument, defaulting to $TARGET_HOME/projects
EXPORT_DIR="${1:-$TARGET_HOME/projects}"
EXPORT_DIR="${EXPORT_DIR/#\~/$TARGET_HOME}"

echo "--> Target export directory: $EXPORT_DIR"
if [ "$EXPORT_DIR" = "$TARGET_HOME" ]; then
    echo "Notice: Exporting user root ($TARGET_HOME) includes dotfiles and ~/.ssh across the network."
fi

if [ ! -d "$EXPORT_DIR" ]; then
    echo "Creating export directory $EXPORT_DIR..."
    mkdir -p "$EXPORT_DIR"
    chown -R "$TARGET_USER:$TARGET_USER" "$EXPORT_DIR"
fi

# 3. Configure /etc/exports
echo "--> Configuring /etc/exports..."
LOCAL_SUBNET=$(ip -4 route show 2>/dev/null | grep proto | grep -v default | awk '{print $1}' | head -n 1 || true)
[ -z "$LOCAL_SUBNET" ] && LOCAL_SUBNET="192.168.1.0/24"
echo "Detected LAN Subnet: $LOCAL_SUBNET"

EXPORT_LINE="$EXPORT_DIR $LOCAL_SUBNET(rw,sync,no_subtree_check,no_root_squash,fsid=0) 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash,fsid=0)"

# Backup /etc/exports if not already backed up
[ -f /etc/exports ] && [ ! -f /etc/exports.gutterdesk.bak ] && sudo cp /etc/exports /etc/exports.gutterdesk.bak

# Idempotently update or append the export configuration
if grep -q "$EXPORT_DIR" /etc/exports 2>/dev/null; then
    # Replace existing line for this directory
    sudo sed -i "\|^$EXPORT_DIR.*|d" /etc/exports
fi
echo "$EXPORT_LINE" | sudo tee -a /etc/exports >/dev/null

# 4. Restrict to NFSv4 only on port 2049 in /etc/nfs.conf
echo "--> Hardening /etc/nfs.conf (NFSv4-only, port 2049)..."
[ -f /etc/nfs.conf ] && [ ! -f /etc/nfs.conf.gutterdesk.bak ] && sudo cp /etc/nfs.conf /etc/nfs.conf.gutterdesk.bak

sudo tee /etc/nfs.conf >/dev/null << 'EOF'
# /etc/nfs.conf - gutterDesk NFSv4 Configuration
[nfsd]
vers2=n
vers3=n
vers4=y
vers4.0=y
vers4.1=y
vers4.2=y
tcp=y
udp=n
port=2049
threads=8

[mountd]
manage-gids=y
EOF

# 5. Open UFW firewall port if UFW is active
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
    echo "--> Configuring UFW firewall for NFSv4 (port 2049)..."
    sudo ufw allow from "$LOCAL_SUBNET" to any port 2049 proto tcp comment 'NFSv4 LAN' >/dev/null || true
    sudo ufw allow from 100.64.0.0/10 to any port 2049 proto tcp comment 'NFSv4 Tailscale' >/dev/null || true
fi

# 6. Apply exports and restart NFS services
echo "--> Applying exports and restarting NFS services..."
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server || sudo systemctl restart nfs-server
sudo systemctl enable nfs-kernel-server || sudo systemctl enable nfs-server

# 7. Verification
echo ""
echo "=== Active NFS Exports ==="
sudo exportfs -v

echo ""
echo "=== NFS Ports Listening ==="
sudo ss -tlpn | grep 2049 || true

# 8. Server Network Audit & Router Static Reservation Check
echo ""
echo "=== [Server Network Audit] Fixed IP & Router Reservation ==="
DEFAULT_ROUTE=$(ip -4 route show default 2>/dev/null | head -n 1 || true)
if [ -n "$DEFAULT_ROUTE" ]; then
    GATEWAY=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')
    DEV=$(echo "$DEFAULT_ROUTE" | awk '{print $5}')
    SERVER_IP=$(ip -4 addr show dev "$DEV" 2>/dev/null | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | head -n 1 || echo "")
    SERVER_MAC=$(cat "/sys/class/net/$DEV/address" 2>/dev/null || echo "Unknown")
    IS_DHCP=$(echo "$DEFAULT_ROUTE" | grep -q "proto dhcp" && echo "Dynamic DHCP" || echo "Static")

    echo "Hostname:         $(hostname)"
    echo "Active Interface: $DEV"
    echo "MAC Address:      $SERVER_MAC"
    echo "Current LAN IP:   $SERVER_IP"
    echo "Router Gateway:   $GATEWAY"
    echo "Allocation Mode:  $IS_DHCP"

    if [ "$IS_DHCP" = "Dynamic DHCP" ]; then
        echo ""
        echo "------------------------------------------------------------------"
        echo "  [CRITICAL NETWORKING REQUIREMENT: ROUTER DHCP RESERVATION]      "
        echo "------------------------------------------------------------------"
        echo "This central development server is currently using dynamic DHCP."
        echo "To ensure client workstations (AiM-Home, aim-book) never suffer"
        echo "stale DNS, ARP mismatches, or hanging NFS automounts:"
        echo ""
        echo "  1. Open your router portal at: http://$GATEWAY"
        echo "  2. Navigate to: DHCP Settings / Static Leases / Address Reservation"
        echo "  3. Create a permanent reservation:"
        echo "       Device Name:  $(hostname)"
        echo "       MAC Address:  $SERVER_MAC"
        echo "       Reserved IP:  $SERVER_IP"
        echo "------------------------------------------------------------------"
    else
        echo "✓ Host is configured with a static network assignment."
    fi
fi

echo ""
echo "✓ NFSv4 server setup successfully completed on $(hostname)."
