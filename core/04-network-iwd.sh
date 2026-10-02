#!/usr/bin/env bash
# ==============================================================================
# Title:           04-network-iwd.sh
# Purpose:         Configures Modern Wireless Stack (iwd + iwgtk) & Credential Migration
# Why This Design: Replaces legacy, high-latency wpa_supplicant and bloated NetworkManager
#                  with Intel Wireless Daemon (iwd). Automatically migrates netinst
#                  Wi-Fi credentials from /etc/network/interfaces into /var/lib/iwd/,
#                  enabling unprivileged user roaming without daemon overhead.
# Privilege:       Root (Requires sudo)
# Subsystems:      iwd (Intel Wireless Daemon), iwgtk, Linux rfkill, network interfaces
# Idempotency:     Migrates credentials safely, creates secure 0600 profiles in /var/lib/iwd/.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

echo "--> [5/8] Configuring modern wireless stack (iwd + iwgtk)..."

# 1. Configure iwd
sudo mkdir -p /etc/iwd /var/lib/iwd
cat << 'EOF' | sudo tee /etc/iwd/main.conf >/dev/null
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=resolvconf
EOF

# 2. Deploy system-wide iwgtk configuration
if [ -f "$SCRIPT_DIR/dotfiles/iwgtk/.config/iwgtk.conf" ]; then
    sudo cp "$SCRIPT_DIR/dotfiles/iwgtk/.config/iwgtk.conf" /etc/iwgtk.conf
fi

# 3. Unblock Wi-Fi hardware/software switches
which rfkill >/dev/null 2>&1 && sudo rfkill unblock wifi 2>/dev/null || true

# 4. Add target user to netdev group for unprivileged network control
sudo usermod -a -G netdev "$TARGET_USER" 2>/dev/null || true

# 5. Migrate existing netinst Wi-Fi credentials into iwd profile
echo "Scanning for netinst Wi-Fi credentials to migrate to iwd..."
python3 - << 'PYEOF'
import os, glob, re

search_files = [
    '/etc/network/interfaces',
    '/etc/network/interfaces.bak',
] + glob.glob('/etc/network/interfaces.d/*') + glob.glob('/etc/wpa_supplicant/*.conf')

found_networks = []

for path in search_files:
    if os.path.isfile(path):
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
                # Check wpa-ssid and wpa-psk/wpa-passphrase
                m_ssid = re.search(r'wpa-ssid\s+["\']?([^"\'\r\n]+)', content)
                m_psk = re.search(r'wpa-(?:psk|passphrase)\s+["\']?([^"\'\r\n]+)', content)
                if m_ssid and m_psk:
                    s = m_ssid.group(1).strip().strip('"\'')
                    p = m_psk.group(1).strip().strip('"\'')
                    if s and p:
                        found_networks.append((s, p))
                
                # Check network={ ssid=".." psk=".." }
                for block in re.finditer(r'network\s*=\s*\{([^}]+)\}', content):
                    b = block.group(1)
                    s = re.search(r'ssid\s*=\s*["\']?([^"\'\r\n]+)', b)
                    p = re.search(r'psk\s*=\s*["\']?([^"\'\r\n]+)', b)
                    if s and p:
                        found_networks.append((s.group(1).strip().strip('"\''), p.group(1).strip().strip('"\'')))
        except Exception:
            pass

def encode_iwd_filename(ssid):
    res = []
    for b in ssid.encode('utf-8'):
        c = chr(b)
        if c.isalnum() or c in ('_', '-', '.'):
            res.append(c)
        else:
            res.append(f"={b:02x}")
    return "".join(res) + ".psk"

migrated = 0
os.makedirs('/var/lib/iwd', exist_ok=True)
for ssid, psk in set(found_networks):
    is_hex = len(psk) == 64 and all(c in '0123456789abcdefABCDEF' for c in psk)
    sec_key = 'PreSharedKey' if is_hex else 'Passphrase'
    target_file = os.path.join('/var/lib/iwd', encode_iwd_filename(ssid))
    try:
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(f'[Security]\n{sec_key}={psk}\n')
        os.chmod(target_file, 0o600)
        print(f"✓ Migrated Wi-Fi credentials for '{ssid}' into {target_file}")
        migrated += 1
    except Exception as e:
        print(f"Notice: Could not write iwd profile for '{ssid}': {e}")

if migrated == 0:
    print("Notice: No saved Wi-Fi credentials found to migrate. Connect via iwgtk on first desktop login.")
PYEOF

# 6. Enable iwd and prepare network configuration for clean handoff
sudo systemctl unmask iwd 2>/dev/null || true
sudo systemctl enable iwd 2>/dev/null || true

if [ -f /etc/network/interfaces ]; then
    if [ ! -f /etc/network/interfaces.bak ]; then
        sudo cp /etc/network/interfaces /etc/network/interfaces.bak
    fi
    sudo sed -i -E 's/^[[:space:]]*(iface|allow-hotplug|auto)[[:space:]]+(wlan|wlp).*/# &/g' /etc/network/interfaces
    sudo sed -i -E 's/^[[:space:]]*wpa-.*/# &/g' /etc/network/interfaces
fi
sudo systemctl disable wpa_supplicant NetworkManager 2>/dev/null || true

echo "✓ Wireless stack configured successfully."
