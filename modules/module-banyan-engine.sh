#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Setting up Banyan Trading Engine ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-engine.list" | tr '\n' ' ')

mkdir -p "$HOME/projects" "$HOME/.config/gutterdesk"
[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

BANYAN_REPO_URL="${BANYAN_REPO_URL:-git@github.com:aimasri/Banyan.git}"

check_and_configure_github_ssh() {
    local target_account="aimasri"
    echo "Checking GitHub SSH authentication for '$target_account'..."

    while true; do
        local gh_msg
        gh_msg=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
        local auth_user
        auth_user=$(echo "$gh_msg" | grep -oP 'Hi \K[^!]+' || true)

        if [ "$auth_user" = "$target_account" ]; then
            echo "✓ GitHub SSH verified (authenticated as $auth_user)."
            return 0
        fi

        echo ""
        echo "=========================================================="
        if [ -n "$auth_user" ]; then
            echo "  Warning: Authenticated as '$auth_user', expected '$target_account'!"
        else
            echo "  GitHub SSH key not recognized or not configured.         "
        fi
        echo "=========================================================="
        echo ""
        echo "The Banyan repository is private and requires '$target_account' access."
        echo ""
        echo "1) Display / generate local SSH key to add to GitHub"
        echo "2) Authenticate via GitHub CLI (gh auth login)"
        echo "3) Enter a GitHub Personal Access Token (PAT)"
        echo "4) Retry SSH check"
        echo "5) Skip clone (repository must be cloned manually)"
        echo ""
        read -p "Select option [1-5]: " auth_choice

        case "$auth_choice" in
            1)
                mkdir -p "$HOME/.ssh"
                chmod 700 "$HOME/.ssh"
                local key_file="$HOME/.ssh/id_ed25519"
                if [ ! -f "$key_file" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
                    echo "Generating new Ed25519 SSH key..."
                    ssh-keygen -t ed25519 -f "$key_file" -N "" -C "$target_account@gutterdesk"
                fi
                local pubkey
                pubkey=$(ls -1 "$HOME/.ssh/"*.pub 2>/dev/null | head -n 1)
                echo ""
                echo "----------------------------------------------------------"
                echo "Public Key ($pubkey):"
                echo "----------------------------------------------------------"
                cat "$pubkey"
                echo "----------------------------------------------------------"
                echo "1. Go to: https://github.com/settings/keys"
                echo "2. Click 'New SSH key', paste the above key, and save."
                echo "----------------------------------------------------------"
                read -p "Press Enter once you have added the key to GitHub to verify..."
                ;;
            2)
                if command -v gh >/dev/null 2>&1; then
                    gh auth login
                else
                    echo "gh CLI not found."
                fi
                ;;
            3)
                read -sp "Enter GitHub PAT: " GH_PAT
                echo ""
                if [ -n "$GH_PAT" ]; then
                    BANYAN_REPO_URL="https://${GH_PAT}@github.com/${target_account}/Banyan.git"
                    return 0
                fi
                ;;
            4)
                echo "Retrying SSH connection..."
                ;;
            5)
                echo "Skipping repository clone."
                return 1
                ;;
            *)
                echo "Invalid selection. Please choose 1, 2, 3, 4, or 5."
                ;;
        esac
    done
}

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    if check_and_configure_github_ssh; then
        echo "Cloning Banyan repository from $BANYAN_REPO_URL..."
        git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"
    else
        echo "Warning: Banyan repository was not cloned. Please clone manually into $HOME/projects/Banyan."
    fi
else
    echo "Banyan repository already present at $HOME/projects/Banyan"
fi

cd "$HOME/projects/Banyan"
if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
fi

echo "Installing Python dependencies..."
.venv/bin/pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    .venv/bin/pip install -r requirements.txt
fi

echo "Banyan Engine configuration complete."
