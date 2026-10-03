#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "    gutterDesk: Modular System Installer                 "
echo "=========================================================="

# Check if base OS is bootstrapped
if ! command -v openbox >/dev/null || ! command -v tint2 >/dev/null; then
    echo "gutterDesk Base OS does not appear to be bootstrapped."
    read -p "Would you like to run bootstrap.sh now? (y/N): " run_base
    if [[ "$run_base" =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/bootstrap.sh"
    fi
fi

# Optional notice: connect.sh only if a previous private backup was made
BACKUP_DIR="$SCRIPT_DIR/backup"
[ ! -d "$BACKUP_DIR" ] && [ -d "$HOME/gutterDesk/backup" ] && BACKUP_DIR="$HOME/gutterDesk/backup"
[ ! -d "$BACKUP_DIR" ] && [ -d "$HOME/projects/gutterdesk-private-backup" ] && BACKUP_DIR="$HOME/projects/gutterdesk-private-backup"

if [ -f "$BACKUP_DIR/connect.sh" ] && [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "------------------------------------------------------------------"
    echo "Notice: Detected private backup at $BACKUP_DIR."
    echo "If you made a previous backup, you can connect your identity and"
    echo "profiles first by running: cd $BACKUP_DIR && ./connect.sh"
    echo "------------------------------------------------------------------"
    echo ""
fi

# ------------------------------------------------------------------
# Step 1: Architectural Role Selection (Client vs Server vs Standalone)
# ------------------------------------------------------------------
ROLE=""
EXISTING_SERVER=$(grep -oP '^[a-zA-Z0-9._-]+(?=:/)' /etc/fstab 2>/dev/null | head -n 1)
DEFAULT_SERVER="${EXISTING_SERVER:-gutterdesk-server}"
SERVER_HOST="$DEFAULT_SERVER"
SERVER_EXPORT_DIR="$HOME/projects"

# Parse CLI flags
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --client)
            ROLE="client"
            [ -n "$2" ] && [[ "$2" != --* ]] && { SERVER_HOST="$2"; shift; }
            ;;
        --server)
            ROLE="server"
            [ -n "$2" ] && [[ "$2" != --* ]] && { SERVER_EXPORT_DIR="$2"; shift; }
            ;;
        --standalone)
            ROLE="standalone"
            ;;
        --skip-role)
            ROLE="skip"
            ;;
        *)
            ;;
    esac
    shift
done

if [ -z "$ROLE" ]; then
    if command -v whiptail >/dev/null; then
        ROLE_CHOICE=$(whiptail --title "gutterDesk Architecture Role" \
            --menu "Select the architectural role for this machine:\n\nCentralizes projects on the server and mounts them on-demand via resilient NFSv4 on clients." 17 76 4 \
            "1" "Client Workstation (Mounts remote projects from central server)" \
            "2" "Central Server (Exports projects to LAN & Tailscale via NFSv4)" \
            "3" "Standalone Machine (Local projects only; no network storage)" \
            "4" "Skip Role Setup (Keep existing storage configuration)" \
            3>&1 1>&2 2>&3) || true
        case "$ROLE_CHOICE" in
            "1")
                ROLE="client"
                SERVER_INPUT=$(whiptail --title "NFS Server Hostname" \
                    --inputbox "Enter hostname or IP of the central development server:" 10 60 "$DEFAULT_SERVER" \
                    3>&1 1>&2 2>&3) || SERVER_INPUT="$DEFAULT_SERVER"
                [ -n "$SERVER_INPUT" ] && SERVER_HOST="$SERVER_INPUT"
                ;;
            "2")
                ROLE="server"
                EXPORT_CHOICE=$(whiptail --title "NFS Server Export Scope" \
                    --menu "Select the directory scope to export via NFSv4:\n\nNote: Exporting user root (~) includes ~/.ssh, browser tokens, and dotfiles." 16 76 3 \
                    "1" "Dedicated Projects Workspace (~/projects) [Recommended]" \
                    "2" "User Home Directory (~) [Full access, credential exposure]" \
                    "3" "Custom Directory Path" \
                    3>&1 1>&2 2>&3) || EXPORT_CHOICE="1"
                case "$EXPORT_CHOICE" in
                    "1") SERVER_EXPORT_DIR="$HOME/projects" ;;
                    "2") SERVER_EXPORT_DIR="$HOME" ;;
                    "3")
                        SERVER_EXPORT_DIR=$(whiptail --title "Custom Export Directory" \
                            --inputbox "Enter absolute directory path to export:" 10 60 "$HOME/projects" \
                            3>&1 1>&2 2>&3) || SERVER_EXPORT_DIR="$HOME/projects"
                        ;;
                esac
                ;;
            "3")
                ROLE="standalone"
                ;;
            *)
                ROLE="skip"
                ;;
        esac
    else
        echo "Select Machine Architectural Role:"
        echo "  1) Client Workstation (resilient NFSv4 automount to central server)"
        echo "  2) Central Server (exports projects via NFSv4)"
        echo "  3) Standalone Machine (local storage only)"
        echo "  4) Skip Role Setup"
        read -p "Role [1-4] (default 1): " ROLE_INPUT
        case "${ROLE_INPUT:-1}" in
            1)
                ROLE="client"
                read -p "Server hostname [$DEFAULT_SERVER]: " SERVER_INPUT
                [ -n "$SERVER_INPUT" ] && SERVER_HOST="$SERVER_INPUT"
                ;;
            2)
                ROLE="server"
                echo "Select export directory scope:"
                echo "  1) Dedicated Projects Workspace (~/projects) [Recommended]"
                echo "  2) User Home Directory (~) [Full root access, exposes ~/.ssh]"
                echo "  3) Custom Directory Path"
                read -p "Scope [1-3] (default 1): " EXPORT_CHOICE
                case "${EXPORT_CHOICE:-1}" in
                    1) SERVER_EXPORT_DIR="$HOME/projects" ;;
                    2) SERVER_EXPORT_DIR="$HOME" ;;
                    3)
                        read -p "Enter path [$HOME/projects]: " CUSTOM_PATH
                        SERVER_EXPORT_DIR="${CUSTOM_PATH:-$HOME/projects}"
                        ;;
                esac
                ;;
            3)
                ROLE="standalone"
                ;;
            *)
                ROLE="skip"
                ;;
        esac
    fi
fi

# Execute role configuration
case "$ROLE" in
    client)
        echo ""
        echo "==> Configuring Machine as Client Workstation (Target Server: $SERVER_HOST)..."
        "$SCRIPT_DIR/modules/module-nfs-client.sh" "$SERVER_HOST"
        ;;
    server)
        echo ""
        echo "==> Configuring Machine as Central Development Server (Export: $SERVER_EXPORT_DIR)..."
        "$SCRIPT_DIR/modules/module-nfs-server.sh" "$SERVER_EXPORT_DIR"
        if command -v whiptail >/dev/null && [ -t 1 ]; then
            DEFAULT_ROUTE=$(ip -4 route show default 2>/dev/null | head -n 1 || true)
            if [ -n "$DEFAULT_ROUTE" ]; then
                GW=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')
                DEV=$(echo "$DEFAULT_ROUTE" | awk '{print $5}')
                SIP=$(ip -4 addr show dev "$DEV" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || echo "")
                SMAC=$(cat "/sys/class/net/$DEV/address" 2>/dev/null || echo "Unknown")
                whiptail --title "Server Fixed IP Reservation Advisory" \
                    --msgbox "IMPORTANT SERVER NETWORKING REQUIREMENT:\n\nTo ensure client workstations (AiM-Home, aim-book) never suffer disconnected NFS automounts, ensure a static DHCP reservation is configured on your router:\n\n• Router Admin URL: http://$GW\n• Hostname: $(hostname)\n• Active Interface: $DEV\n• MAC Address: $SMAC\n• Reserved IP: $SIP\n\nPlease configure this reservation in your broadband router." 16 74 3>&1 1>&2 2>&3 || true
            fi
        fi
        ;;
    standalone)
        echo "==> Machine configured as Standalone."
        ;;
    skip)
        echo "==> Skipping role configuration."
        ;;
esac

# ------------------------------------------------------------------
# Step 2: Specialized Capability Modules (Checkbox Menu)
# ------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------"
echo "  Step 2: Specialized Capability Modules                  "
echo "----------------------------------------------------------"

if command -v whiptail >/dev/null; then
    CHOICES=$(whiptail --title "gutterDesk Module Selector" \
        --checklist "Select additional capability modules to activate on this machine:\n(Use Space to select, Enter to confirm)" 21 76 6 \
        "1" "Creative Suite (GIMP, Krita, Inkscape, Blender, etc.)" OFF \
        "2" "Banyan Trading Engine (Wine64, Python venv, MT5 daemon)" OFF \
        "3" "Banyan Trading Dashboard (C++ desktop monitoring UI)" OFF \
        "4" "Jellyfin Media Server & Tailscale Mesh Node" OFF \
        "5" "Web Development Stack (Apache2, Postgres, Redis, repos)" OFF \
        "6" "Torrent Machine (Transmission-gtk, UFW)" OFF \
        3>&1 1>&2 2>&3) || true
else
    # Simple CLI fallback
    echo "Select modules to install (comma-separated, e.g. 1,4,5 or press Enter to skip):"
    echo "  1) Creative Suite"
    echo "  2) Banyan Trading Engine"
    echo "  3) Banyan Trading Dashboard"
    echo "  4) Jellyfin & Tailscale"
    echo "  5) Web Development Stack"
    echo "  6) Torrent Machine"
    read -p "Selection: " CHOICES
    CHOICES=$(echo "$CHOICES" | tr ',' ' ')
fi

# Execute selected functional modules
if [ -n "$(echo "$CHOICES" | tr -d '[:space:]\"')" ]; then
    echo ""
    echo "=== Executing Selected Modules ==="

    for choice in $CHOICES; do
        clean_choice=$(echo "$choice" | tr -d '"')
        case "$clean_choice" in
            1)
                "$SCRIPT_DIR/modules/module-creative.sh"
                ;;
            2)
                "$SCRIPT_DIR/modules/module-banyan-engine.sh"
                ;;
            3)
                "$SCRIPT_DIR/modules/module-banyan-dashboard.sh"
                ;;
            4)
                "$SCRIPT_DIR/modules/module-media-tailscale.sh"
                ;;
            5)
                "$SCRIPT_DIR/modules/module-webstack.sh"
                ;;
            6)
                "$SCRIPT_DIR/modules/module-torrent.sh"
                ;;
        esac
    done
else
    echo "No additional capability modules selected."
fi

echo ""
echo "=========================================================="
echo "    gutterDesk installation & provisioning complete!      "
echo "=========================================================="
