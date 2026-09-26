#!/bin/bash
# Auto-detects monitor orientation and applies matching wallpaper per display head

WALLPAPER_DIR="$HOME/.local/share/backgrounds"
LANDSCAPE="$WALLPAPER_DIR/landscape.png"
PORTRAIT="$WALLPAPER_DIR/portrait.png"

# Fallbacks if custom images not in place
[ ! -f "$LANDSCAPE" ] && LANDSCAPE="/usr/share/backgrounds/default.png"
[ ! -f "$PORTRAIT" ] && PORTRAIT="$LANDSCAPE"

if ! command -v xrandr >/dev/null || ! command -v nitrogen >/dev/null; then
    exit 0
fi

# Iterate over active monitors
xrandr --listmonitors | awk 'NR>1 {
    idx = substr($1, 1, length($1)-1);
    split($3, geom, "+");
    split(geom[1], dims, "x");
    split(dims[1], w, "/");
    split(dims[2], h, "/");
    print idx, w[1], h[1];
}' | while read -r idx width height; do
    if [ -n "$idx" ] && [ -n "$width" ] && [ -n "$height" ]; then
        if [ "$height" -gt "$width" ] && [ -f "$PORTRAIT" ]; then
            nitrogen --head="$idx" --set-zoom-fill "$PORTRAIT" --save
        elif [ -f "$LANDSCAPE" ]; then
            nitrogen --head="$idx" --set-zoom-fill "$LANDSCAPE" --save
        fi
    fi
done

# Apply final saved state
nitrogen --restore
