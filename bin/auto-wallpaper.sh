#!/usr/bin/env bash
# ==============================================================================
# Title:           auto-wallpaper.sh
# Purpose:         Multi-Head Dynamic Orientation-Matched Wallpaper Engine
# Why This Design: Heterogeneous multi-monitor setups (e.g., multi-head workstations
#                  with a landscape primary and portrait secondary) look distorted
#                  if a single wallpaper is stretched across all heads. This engine
#                  inspects each connected xrandr head geometry and sets the
#                  orientation-matched wallpaper independently per head via nitrogen.
# Privilege:       Target User (X11 session context)
# Subsystems:      X11 (xrandr), nitrogen (or feh fallback)
# Idempotency:     Re-running reapplies current geometry configurations and exits cleanly.
# ==============================================================================

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_WALLPAPERS="$(cd "$SCRIPT_DIR/../wallpapers" 2>/dev/null && pwd || echo "")"

# Candidate search paths for landscape and portrait wallpapers
find_wallpaper() {
    local name="$1"
    local candidates=(
        "$TARGET_HOME/.local/share/backgrounds/$name"
        "/usr/share/backgrounds/gutterdesk/$name"
        "$REPO_WALLPAPERS/$name"
        "/usr/share/backgrounds/default.png"
    )
    for c in "${candidates[@]}"; do
        if [ -n "$c" ] && [ -f "$c" ]; then
            echo "$c"
            return 0
        fi
    done
    echo ""
}

LANDSCAPE=$(find_wallpaper "landscape.png")
PORTRAIT=$(find_wallpaper "portrait.png")

# Fallback portrait to landscape if portrait is missing
[ -z "$PORTRAIT" ] && PORTRAIT="$LANDSCAPE"

if [ -z "$LANDSCAPE" ]; then
    echo "Notice: No wallpaper images found." >&2
    exit 0
fi

# If user already has a saved wallpaper configuration in nitrogen, preserve it
if [ "${1:-}" != "--force" ] && [ -f "$TARGET_HOME/.config/nitrogen/bg-saved.cfg" ]; then
    if command -v nitrogen >/dev/null 2>&1; then
        nitrogen --restore 2>/dev/null || true
        exit 0
    fi
fi

if command -v nitrogen >/dev/null 2>&1 && command -v xrandr >/dev/null 2>&1; then
    xrandr --listmonitors 2>/dev/null | awk 'NR>1 {
        idx = substr($1, 1, length($1)-1);
        split($3, geom, "+");
        split(geom[1], dims, "x");
        split(dims[1], w, "/");
        split(dims[2], h, "/");
        print idx, w[1], h[1];
    }' | while read -r idx width height; do
        if [ -n "$idx" ] && [ -n "$width" ] && [ -n "$height" ]; then
            if [ "$height" -gt "$width" ] && [ -n "$PORTRAIT" ]; then
                nitrogen --head="$idx" --set-zoom-fill "$PORTRAIT" --save 2>/dev/null || true
            else
                nitrogen --head="$idx" --set-zoom-fill "$LANDSCAPE" --save 2>/dev/null || true
            fi
        fi
    done
    nitrogen --restore 2>/dev/null || true
elif command -v feh >/dev/null 2>&1; then
    feh --bg-fill "$LANDSCAPE" 2>/dev/null || true
fi
