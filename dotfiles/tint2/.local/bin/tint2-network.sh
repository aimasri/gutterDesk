#!/usr/bin/env bash
# ==============================================================================
# tint2-network.sh: Lightweight Network & Wi-Fi Tray Indicator for Tint2
# ------------------------------------------------------------------------------
# Queries iwd (Intel Wireless Daemon) and sysfs to display connection status
# and signal strength in Tint2's executor plugin without external daemons.
# ==============================================================================

ICON_DIR="/usr/share/icons/Papirus-Dark/24x24/panel"

# 1. Check Wired interfaces first (carrier up and operstate up)
for eth in /sys/class/net/en* /sys/class/net/eth*; do
    if [ -d "$eth" ] && [ "$(cat "$eth/carrier" 2>/dev/null)" = "1" ] && [ "$(cat "$eth/operstate" 2>/dev/null)" = "up" ]; then
        iface=$(basename "$eth")
        ip_addr=$(ip -4 -br addr show "$iface" 2>/dev/null | awk '{print $3}')
        echo "$ICON_DIR/network-wired-activated.svg"
        echo ""
        echo "Wired Network: $iface ($ip_addr)" >&2
        exit 0
    fi
done

# 2. Check Wireless via iwd (iwctl)
wlan=$(ls /sys/class/net 2>/dev/null | grep -E '^wl' | head -n1)

if [ -n "$wlan" ]; then
    show_out=$(iwctl station "$wlan" show 2>/dev/null)
    state=$(echo "$show_out" | grep -m1 "State" | awk '{print $2}')
    
    if [ "$state" = "connected" ]; then
        ssid=$(echo "$show_out" | grep -m1 "Connected network" | sed 's/.*Connected network *//; s/ *$//')
        rssi=$(echo "$show_out" | grep -m1 "RSSI" | awk '{print $2}')
        
        # Select icon based on signal level (RSSI in dBm)
        icon="$ICON_DIR/network-wireless-connected-100.svg"
        if [ -n "$rssi" ]; then
            if [ "$rssi" -ge -50 ] 2>/dev/null; then
                icon="$ICON_DIR/network-wireless-connected-100.svg"
            elif [ "$rssi" -ge -65 ] 2>/dev/null; then
                icon="$ICON_DIR/network-wireless-connected-75.svg"
            elif [ "$rssi" -ge -75 ] 2>/dev/null; then
                icon="$ICON_DIR/network-wireless-connected-50.svg"
            elif [ "$rssi" -ge -85 ] 2>/dev/null; then
                icon="$ICON_DIR/network-wireless-connected-25.svg"
            else
                icon="$ICON_DIR/network-wireless-connected-00.svg"
            fi
        fi
        
        echo "$icon"
        echo ""
        echo "Wi-Fi: $ssid ($rssi dBm)" >&2
        exit 0
    elif [ "$state" = "connecting" ]; then
        echo "$ICON_DIR/network-wireless-acquiring.svg"
        echo ""
        echo "Wi-Fi: Connecting..." >&2
        exit 0
    fi
fi

# 3. Disconnected / Offline
echo "$ICON_DIR/network-wireless-disconnected.svg"
echo ""
echo "Network: Disconnected" >&2
