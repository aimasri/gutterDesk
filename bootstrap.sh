#!/usr/bin/env bash
# ==============================================================================
# Title:           bootstrap.sh
# Purpose:         Universal Base OS Bootstrap Orchestrator for gutterDesk (Debian 13)
# Why This Design: Replaces monolithic procedural scripting with a modular, staged
#                  architecture under core/. Allows executing full end-to-end
#                  provisioning on fresh installs, or running targeted individual
#                  stages (e.g. dotfiles, desktop tools, themes) during cluster sync.
# Privilege:       Root (Requires sudo)
# Subsystems:      Delegates to core/00 through core/07
# Idempotency:     Every underlying core stage is strictly idempotent.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/core"

STAGES=(
    "00-repos.sh:System repositories, online mirrors & GPG keyrings"
    "01-base-packages.sh:Universal Base packages (Openbox, Tint2, Guake, iwd)"
    "02-themes-branding.sh:Wallpapers, Midnight Forest GTK, icons & desktop entries"
    "03-boot-login.sh:Plymouth boot splash, GRUB & LightDM greeter"
    "04-network-iwd.sh:Modern wireless stack (iwd + iwgtk) & credential migration"
    "05-dotfiles.sh:Pure declarative dotfiles atomic symlinking"
    "06-desktop-tools.sh:Distro utilities, gutter family & Antigravity suite"
    "07-hardware-power.sh:Lid switch, battery threshold daemon & permissions"
)

show_help() {
    echo "=========================================================="
    echo "    gutterDesk: Universal Base Bootstrap (Debian 13)       "
    echo "=========================================================="
    echo "Usage: sudo ./bootstrap.sh [OPTIONS] [STAGE]"
    echo ""
    echo "Options:"
    echo "  --list, -l          List all available bootstrap stages"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Selective Stage Execution:"
    echo "  sudo ./bootstrap.sh <stage-name-or-prefix>"
    echo "  Examples:"
    echo "    sudo ./bootstrap.sh 05              (Runs 05-dotfiles.sh)"
    echo "    sudo ./bootstrap.sh dotfiles        (Runs 05-dotfiles.sh)"
    echo "    sudo ./bootstrap.sh themes          (Runs 02-themes-branding.sh)"
    echo "    sudo ./bootstrap.sh tools           (Runs 06-desktop-tools.sh)"
    echo ""
    echo "Default (no arguments): Runs all stages sequentially from 00 to 07."
    echo "=========================================================="
}

list_stages() {
    echo "Available Bootstrap Stages in $CORE_DIR:"
    for item in "${STAGES[@]}"; do
        stage_file="${item%%:*}"
        stage_desc="${item#*:}"
        echo "  - ${stage_file%.sh} : $stage_desc"
    done
}

# Allow unprivileged inspection of stages and help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
    exit 0
fi

if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
    list_stages
    exit 0
fi

# Require administrative privileges for actual execution
if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

run_stage() {
    local script_file="$1"
    local stage_path="$CORE_DIR/$script_file"
    
    if [ ! -f "$stage_path" ]; then
        echo "Error: Stage script not found at $stage_path" >&2
        exit 1
    fi
    
    echo ""
    echo "=========================================================="
    echo "  Running Stage: $script_file"
    echo "=========================================================="
    bash "$stage_path"
}

if [ -n "${1:-}" ]; then
    TARGET_ARG="${1#--stage=}"
    TARGET_ARG="${TARGET_ARG#--stage }"
    
    MATCHED=""
    for item in "${STAGES[@]}"; do
        stage_file="${item%%:*}"
        if [[ "$stage_file" == *"$TARGET_ARG"* ]] || [[ "${stage_file%.sh}" == *"$TARGET_ARG"* ]]; then
            MATCHED="$stage_file"
            break
        fi
    done
    
    if [ -n "$MATCHED" ]; then
        run_stage "$MATCHED"
        echo ""
        echo "✓ Stage '$MATCHED' completed successfully!"
        exit 0
    else
        echo "Error: No stage found matching '$TARGET_ARG'." >&2
        list_stages
        exit 1
    fi
fi

# Default execution: run all stages sequentially
echo "=========================================================="
echo "    gutterDesk: Universal Base Bootstrap (Debian 13)       "
echo "=========================================================="
echo "Target User: $TARGET_USER ($TARGET_HOME)"
echo "Executing all 8 bootstrap stages sequentially..."
echo ""

for item in "${STAGES[@]}"; do
    stage_file="${item%%:*}"
    run_stage "$stage_file"
done

echo ""
echo "=========================================================="
echo "    gutterDesk Base Bootstrap Completed Successfully!     "
echo "=========================================================="
echo "Reboot recommended to initialize display manager and kernel settings:"
echo "  sudo reboot"
echo "=========================================================="
