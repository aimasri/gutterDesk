#!/usr/bin/env bash
# ==============================================================================
# Title:           06-desktop-tools.sh
# Purpose:         Deploys Utilities, Builds gutter Family & Installs Antigravity Suite
# Why This Design: Integrates native tactile tools (gutterDeck, gutterTab, gutterdesk-menu,
#                  gutterdesk-rotator) and the Google Antigravity developer suite
#                  into the desktop environment with desktop entries, MIME associations,
#                  and terminal emulators.
# Privilege:       Dual (Requires sudo for /usr/local/bin; builds tools as target user)
# Subsystems:      CMake, C++, Antigravity IDE, Antigravity 2.0, Openbox menu
# Idempotency:     Caches downloaded archives in /var/cache/gutterdesk/. gutter tools are
#                  rebuilt only when upstream HEAD differs from the revision stamp
#                  /var/cache/gutterdesk/<tool>.rev written at install time.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

run_as_target() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

echo "--> [7/8] Deploying system utilities, building gutter tools & Antigravity suite..."

# 1. Deploy custom binaries from bin/ to /usr/local/bin and ~/.local/bin
echo "Deploying gutterDesk system and user utilities from bin/..."
sudo mkdir -p /usr/local/bin "$TARGET_HOME/.local/bin"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local" 2>/dev/null || true

for tool in "$SCRIPT_DIR/bin/"*; do
    if [ -f "$tool" ]; then
        bname=$(basename "$tool")
        sudo install -m 755 "$tool" "/usr/local/bin/$bname"
        run_as_target install -m 755 "$tool" "$TARGET_HOME/.local/bin/$bname"
    fi
done

# Compatibility aliases
sudo ln -sf /usr/local/bin/auto-wallpaper.sh /usr/local/bin/auto-wallpaper 2>/dev/null || true
run_as_target ln -sf "$TARGET_HOME/.local/bin/auto-wallpaper.sh" "$TARGET_HOME/.local/bin/auto-wallpaper" 2>/dev/null || true
sudo ln -sf /usr/local/bin/tint2-network.sh /usr/local/bin/tint2-network 2>/dev/null || true
run_as_target ln -sf "$TARGET_HOME/.local/bin/tint2-network.sh" "$TARGET_HOME/.local/bin/tint2-network" 2>/dev/null || true

# 2. Compile staged Openbox menu
[ -L "$TARGET_HOME/.config/openbox/menu.xml" ] && rm -f "$TARGET_HOME/.config/openbox/menu.xml"
if [ -x "/usr/local/bin/gutterdesk-menu" ]; then
    echo "Compiling staged Openbox menu..."
    run_as_target /usr/local/bin/gutterdesk-menu init
fi

# 3. Build gutterDeck and gutterTab
# Staleness is decided by comparing the upstream HEAD commit against a revision
# stamp written at install time (/var/cache/gutterdesk/<name>.rev). Merely
# checking for an existing binary would make re-running bootstrap unable to ever
# upgrade the tools. Offline runs with an existing binary skip gracefully.
TOOL_REV_DIR="/var/cache/gutterdesk"
sudo mkdir -p "$TOOL_REV_DIR"

build_tool() {
    local name="$1"
    local repo="$2"
    local build_root="/tmp/gutterdesk-build"
    local dir="$build_root/$name"
    local lname
    lname="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    local stamp="$TOOL_REV_DIR/$lname.rev"

    local installed=0
    if [ -x "/usr/local/bin/$name" ] || [ -x "/usr/local/bin/$lname" ]; then
        installed=1
    fi

    local remote_rev=""
    remote_rev="$(run_as_target git ls-remote "$repo" HEAD 2>/dev/null | cut -f1)" || remote_rev=""
    local local_rev=""
    [ -f "$stamp" ] && local_rev="$(cat "$stamp")"

    if [ "$installed" -eq 1 ]; then
        if [ -z "$remote_rev" ]; then
            echo "⚠ $name: upstream unreachable; keeping installed binary (rev ${local_rev:-unknown})."
            return 0
        fi
        if [ "$remote_rev" = "$local_rev" ]; then
            echo "✓ $name is up to date (${local_rev:0:7})."
            return 0
        fi
        local shown_rev="${local_rev:0:7}"
        echo "↻ $name is stale (installed ${shown_rev:-unstamped}, upstream ${remote_rev:0:7}); rebuilding..."
    fi

    run_as_target mkdir -p "$build_root"
    echo "Cloning $name into temporary build directory $dir..."
    rm -rf "$dir"
    if ! run_as_target git clone --depth 1 "$repo" "$dir"; then
        echo "ERROR: Failed to clone $name from $repo" >&2
        exit 1
    fi
    local built_rev
    built_rev="$(run_as_target git -C "$dir" rev-parse HEAD)"

    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "Building $name as $TARGET_USER..."
        run_as_target mkdir -p "$dir/build"
        if ! run_as_target bash -c "cd '$dir/build' && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j\$(nproc)"; then
            echo "ERROR: Compilation of $name failed!" >&2
            exit 1
        fi

        local bin_source=""
        if [ -f "$dir/build/$name" ]; then
            bin_source="$dir/build/$name"
        elif [ -f "$dir/build/$lname" ]; then
            bin_source="$dir/build/$lname"
        fi

        if [ -n "$bin_source" ] && [ -x "$bin_source" ]; then
            local bin_basename="$(basename "$bin_source")"
            echo "Installing $bin_basename to /usr/local/bin and $TARGET_HOME/.local/bin..."
            sudo install -m 755 "$bin_source" "/usr/local/bin/$bin_basename"
            run_as_target install -m 755 "$bin_source" "$TARGET_HOME/.local/bin/$bin_basename"
            echo "$built_rev" | sudo tee "$stamp" >/dev/null
            echo "✓ $name installed at ${built_rev:0:7}."
        fi
    fi
}

build_tool "gutterDeck" "https://github.com/aimasri/gutterDeck.git"
build_tool "gutterTab" "https://github.com/aimasri/gutterTab.git"
rm -rf "/tmp/gutterdesk-build"

# Casing compatibility symlinks
[ -f /usr/local/bin/gutterdeck ] && sudo ln -sf /usr/local/bin/gutterdeck /usr/local/bin/gutterDeck || true
[ -f /usr/local/bin/guttertab ] && sudo ln -sf /usr/local/bin/guttertab /usr/local/bin/gutterTab || true
[ -f "$TARGET_HOME/.local/bin/gutterdeck" ] && run_as_target ln -sf "$TARGET_HOME/.local/bin/gutterdeck" "$TARGET_HOME/.local/bin/gutterDeck" || true
[ -f "$TARGET_HOME/.local/bin/guttertab" ] && run_as_target ln -sf "$TARGET_HOME/.local/bin/guttertab" "$TARGET_HOME/.local/bin/gutterTab" || true

# 4. Install Google Antigravity Suite
CACHE_DIR="/var/cache/gutterdesk"
sudo mkdir -p "$CACHE_DIR" /usr/share/antigravity /opt/Antigravity2 /usr/local/bin

download_archive() {
    local url="$1"
    local dest="$2"
    local label="$3"
    
    if [ -f "$dest" ] && [ -s "$dest" ]; then
        echo "✓ $label archive cached ($dest)."
        return 0
    fi
    
    echo "Downloading $label from official Google repository..."
    if command -v curl >/dev/null 2>&1; then
        sudo curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$dest.tmp"
    elif command -v wget >/dev/null 2>&1; then
        sudo wget -q --show-progress "$url" -O "$dest.tmp"
    fi
    sudo mv "$dest.tmp" "$dest"
    echo "✓ $label download complete."
}

# A. Antigravity IDE
IDE_URL="https://dl.google.com/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"
IDE_TAR="$CACHE_DIR/Antigravity_IDE.tar.gz"
download_archive "$IDE_URL" "$IDE_TAR" "Antigravity IDE"

if [ ! -f /usr/share/antigravity/antigravity-ide ]; then
    echo "Installing Antigravity IDE into /usr/share/antigravity..."
    sudo rm -rf /usr/share/antigravity/* 2>/dev/null || true
    sudo tar -xzf "$IDE_TAR" -C /usr/share/antigravity --strip-components=1
    sudo chown root:root /usr/share/antigravity/chrome-sandbox 2>/dev/null || true
    sudo chmod 4755 /usr/share/antigravity/chrome-sandbox 2>/dev/null || true
fi
sudo ln -sf /usr/share/antigravity/bin/antigravity-ide /usr/bin/antigravity
sudo ln -sf /usr/share/antigravity/bin/antigravity-ide /usr/local/bin/antigravity
run_as_target ln -sf /usr/bin/antigravity "$TARGET_HOME/.local/bin/antigravity"

# B. Antigravity 2.0 (Agents Manager)
HUB_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.17.0-5217732355031040/linux-x64/Antigravity.tar.gz"
HUB_TAR="$CACHE_DIR/Antigravity_Hub.tar.gz"
download_archive "$HUB_URL" "$HUB_TAR" "Antigravity Agents Manager"

if [ ! -f /opt/Antigravity2/antigravity ]; then
    echo "Installing Antigravity 2.0 Agents Manager into /opt/Antigravity2..."
    sudo rm -rf /opt/Antigravity2/* 2>/dev/null || true
    sudo tar -xzf "$HUB_TAR" -C /opt/Antigravity2 --strip-components=1
    sudo chown root:root /opt/Antigravity2/chrome-sandbox 2>/dev/null || true
    sudo chmod 4755 /opt/Antigravity2/chrome-sandbox 2>/dev/null || true
fi
sudo ln -sf /opt/Antigravity2/antigravity /usr/local/bin/antigravity2
run_as_target ln -sf /usr/local/bin/antigravity2 "$TARGET_HOME/.local/bin/antigravity2"

# C. Desktop Applications & Pixmaps
sudo mkdir -p /usr/share/applications /usr/share/pixmaps
if [ -f "$SCRIPT_DIR/assets/icons/antigravity.png" ]; then
    sudo cp "$SCRIPT_DIR/assets/icons/antigravity.png" /usr/share/pixmaps/antigravity.png
fi

sudo tee /usr/share/applications/antigravity.desktop >/dev/null << 'EOF_DESK'
[Desktop Entry]
Name=Antigravity IDE
Comment=Experience liftoff - AI-First Code Editor
GenericName=Text Editor
Exec=/usr/bin/antigravity %F
Icon=antigravity
Type=Application
StartupNotify=true
StartupWMClass=Antigravity
Categories=TextEditor;Development;IDE;
MimeType=application/x-antigravity-workspace;
EOF_DESK

sudo tee /usr/share/applications/antigravity2.desktop >/dev/null << 'EOF_DESK2'
[Desktop Entry]
Name=Antigravity Agents Manager
Comment=Google Antigravity 2.0 Multi-Agent Orchestration Platform
GenericName=Agent Workspace Manager
Exec=/usr/local/bin/antigravity2 %U
Icon=antigravity
Type=Application
StartupNotify=true
StartupWMClass=Antigravity
Categories=Development;Utility;
EOF_DESK2
sudo update-desktop-database /usr/share/applications 2>/dev/null || true

# 5. Guake x-terminal-emulator wrapper
sudo tee /usr/local/bin/x-terminal-emulator >/dev/null << 'EOF'
#!/bin/bash
if [ -n "$1" ]; then
    guake "$@"
else
    guake-toggle
fi
EOF
sudo chmod 755 /usr/local/bin/x-terminal-emulator
run_as_target ln -sf /usr/local/bin/x-terminal-emulator "$TARGET_HOME/.local/bin/x-terminal-emulator"

# 6. Global PATH configuration in /etc/profile.d/gutterdesk.sh
sudo tee /etc/profile.d/gutterdesk.sh >/dev/null << 'EOF'
# gutterDesk system-wide PATH configuration
if [ -n "$PATH" ]; then
    case ":$PATH:" in
        *:/usr/local/bin:*) ;;
        *) export PATH="/usr/local/bin:$PATH" ;;
    esac
    case ":$PATH:" in
        *:"$HOME/.local/bin":*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
else
    export PATH="/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin"
fi
export GTK_USE_PORTAL=0
EOF
sudo chmod 644 /etc/profile.d/gutterdesk.sh

echo "✓ Desktop tools and Antigravity suite deployed successfully."
