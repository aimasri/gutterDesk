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

# Whiptail checkbox menu if available
if command -v whiptail >/dev/null; then
    CHOICES=$(whiptail --title "gutterDesk Module Selector" \
        --checklist "Select the modules to activate on this machine:\n(Use Space to select, Enter to confirm)" 20 75 6 \
        "1" "Creative Suite (GIMP, Krita, Inkscape, Blender, etc.)" OFF \
        "2" "Banyan Trading Engine (Wine64, Python venv, MT5 daemon)" OFF \
        "3" "Banyan Trading Dashboard (C++ desktop monitoring UI)" OFF \
        "4" "Jellyfin Media Server & Tailscale Mesh Node" OFF \
        "5" "Web Development Stack (Apache2, Postgres, Redis, repos)" OFF \
        "6" "Torrent Machine (Transmission-gtk, UFW)" OFF \
        3>&1 1>&2 2>&3)
else
    # Simple CLI fallback
    echo "Select modules to install (comma-separated, e.g. 1,4,5):"
    echo "  1) Creative Suite"
    echo "  2) Banyan Trading Engine"
    echo "  3) Banyan Trading Dashboard"
    echo "  4) Jellyfin & Tailscale"
    echo "  5) Web Development Stack"
    echo "  6) Torrent Machine"
    read -p "Selection: " CHOICES
fi

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

echo ""
echo "=========================================================="
echo "    All selected modules have been installed!             "
echo "=========================================================="
