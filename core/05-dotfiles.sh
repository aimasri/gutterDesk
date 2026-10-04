#!/usr/bin/env bash
# ==============================================================================
# Title:           05-dotfiles.sh
# Purpose:         Deploys repo-owned dotfiles via atomic symlinks and seeds app-owned
#                  settings once (seeds/), never overwriting user state.
# Why This Design: Eliminates third-party package manager overhead (Chezmoi, GNU Stow)
#                  while preventing configuration drift. Repo-owned files are symlinks,
#                  so edits are tracked by git. App-owned files (rewritten by their
#                  applications) are copied only when absent, because symlinking them
#                  either breaks on atomic save or leaks local edits into the checkout.
# Privilege:       Dual (Ensures user ownership of all created links in $TARGET_HOME)
# Subsystems:      Openbox, Tint2, PCManFM, GTK, Guake, Volumeicon, Gsimplecal, Antigravity
# Idempotency:     `ln -sfn` re-links safely; diverged real files are moved to
#                  ~/.local/state/gutterdesk/dotfile-backups/<ts>/ instead of being
#                  clobbered; seeds use copy-if-absent; dangling links into dotfiles/
#                  are pruned.
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

echo "--> [6/8] Deploying declarative dotfiles into $TARGET_HOME..."

DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
SEEDS_DIR="$SCRIPT_DIR/seeds"
STOW_PKGS="openbox tint2 themes ssh gemini guake gtk volumeicon gsimplecal iwgtk"
BACKUP_ROOT="$TARGET_HOME/.local/state/gutterdesk/dotfile-backups/$(date +%Y%m%d-%H%M%S)"

# Ensure target home base directories exist with proper user ownership
if [ "$EUID" -eq 0 ]; then
    mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/applications" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh" 2>/dev/null || true
else
    mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/applications" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh"
fi

# 1. Repo-owned configuration: symlinked into the checkout.
#    These files are authored in git and never written by their applications.
#    A real file found at a link destination is only replaced if identical;
#    otherwise it is moved to $BACKUP_ROOT so no local data is ever lost.
for pkg in $STOW_PKGS; do
    pkg_dir="$DOTFILES_DIR/$pkg"
    if [ -d "$pkg_dir" ]; then
        (
            cd "$pkg_dir"
            find . -type f -o -type l | while read -r f; do
                rel="${f#./}"
                src="$pkg_dir/$rel"
                dst="$TARGET_HOME/$rel"

                run_as_target mkdir -p "$(dirname "$dst")"
                if [ -d "$dst" ] && [ ! -L "$dst" ]; then
                    run_as_target mkdir -p "$(dirname "$BACKUP_ROOT/$rel")"
                    run_as_target mv "$dst" "$BACKUP_ROOT/$rel"
                    echo "  ⚠ Moved conflicting directory ~/$rel to $BACKUP_ROOT/"
                elif [ -f "$dst" ] && [ ! -L "$dst" ] && ! cmp -s "$src" "$dst"; then
                    run_as_target mkdir -p "$(dirname "$BACKUP_ROOT/$rel")"
                    run_as_target mv "$dst" "$BACKUP_ROOT/$rel"
                    echo "  ⚠ Backed up locally modified ~/$rel to $BACKUP_ROOT/"
                fi
                run_as_target ln -sfn "$src" "$dst"
            done
        )
    fi
done

# 2. App-owned state: seeded once, never overwritten.
#    Applications such as PCManFM and the Antigravity editors rewrite their own
#    settings. Symlinking them would either break the link (atomic saves) or
#    write user changes into the git checkout, so they are copied only when absent.
if [ -d "$SEEDS_DIR" ]; then
    (
        cd "$SEEDS_DIR"
        find . -type f | while read -r f; do
            rel="${f#./}"
            dst="$TARGET_HOME/$rel"
            # Replace a legacy symlink into the repo (pre-seed layout) with a real copy
            if [ -L "$dst" ] && [[ "$(readlink "$dst")" == "$SCRIPT_DIR/"* ]]; then
                rm -f "$dst"
            fi
            if [ ! -e "$dst" ]; then
                run_as_target mkdir -p "$(dirname "$dst")"
                run_as_target cp "$SEEDS_DIR/$rel" "$dst"
                echo "  ✓ Seeded ~/$rel"
            fi
        done
    )
fi

# 3. Prune dangling symlinks that point into the dotfiles tree (files removed or
#    renamed upstream), so retired configuration never lingers on a node.
for scan_dir in "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh" "$TARGET_HOME/.gemini"; do
    [ -d "$scan_dir" ] || continue
    find "$scan_dir" -xtype l -lname "$DOTFILES_DIR/*" -print -delete 2>/dev/null | sed 's/^/  ✓ Pruned retired dotfile link: /' || true
done
find "$TARGET_HOME" -maxdepth 1 -xtype l -lname "$DOTFILES_DIR/*" -print -delete 2>/dev/null | sed 's/^/  ✓ Pruned retired dotfile link: /' || true

# Restore Guake terminal styling & Twilight palette
if [ -f "$TARGET_HOME/.config/guake/guake-preferences.ini" ]; then
    echo "Restoring Guake terminal styling & Twilight palette..."
    which dconf >/dev/null 2>&1 && run_as_target dconf load /org/guake/ < "$TARGET_HOME/.config/guake/guake-preferences.ini" 2>/dev/null || true
fi

# Set default application associations
echo "Configuring default desktop associations..."
run_as_target xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# Ensure all deployed dotfiles are owned by TARGET_USER (targeted only to managed dotfiles, never traversing network mounts)
if [ "$EUID" -eq 0 ]; then
    for scan_dir in "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh" "$TARGET_HOME/.gemini"; do
        [ -d "$scan_dir" ] && chown -R "$TARGET_USER:$TARGET_USER" "$scan_dir" 2>/dev/null || true
    done
    find "$TARGET_HOME" -maxdepth 1 -lname "$DOTFILES_DIR/*" -exec chown -h "$TARGET_USER:$TARGET_USER" {} + 2>/dev/null || true
fi

echo "✓ Dotfiles deployed successfully via atomic symlinks."
