#!/usr/bin/env bash

set -e  # Exit on error

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew already installed"
fi

# Install required tools
echo "Installing required tools..."
brew install starship btop tmux alacritty bat jq macmon python glab || true

# Install Nerd Font
echo "Installing Fira Code Nerd Font..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS via Homebrew
    brew install --cask font-fira-code-nerd-font || true
    echo "✓ Fira Code Nerd Font installed"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Git Bash on Windows
    echo "Downloading Fira Code Nerd Font..."
    TEMP_DIR="/c/Users/$USER/AppData/Local/Temp/FiraCodeNF"
    mkdir -p "$TEMP_DIR"
    curl -fLo "$TEMP_DIR/FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
    unzip -o "$TEMP_DIR/FiraCode.zip" -d "$TEMP_DIR"

    # Use PowerShell to install fonts
    echo "Installing fonts (requires admin)..."
    powershell.exe -Command "
        \$fonts = Get-ChildItem -Path '$TEMP_DIR' -Filter '*.ttf'
        \$FONTS = 0x14
        \$objShell = New-Object -ComObject Shell.Application
        \$objFolder = \$objShell.Namespace(\$FONTS)
        foreach (\$font in \$fonts) {
            \$objFolder.CopyHere(\$font.FullName, 0x10)
        }
    "
    rm -rf "$TEMP_DIR"
    echo "✓ Fira Code Nerd Font installed"
elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    # WSL - fonts need to be installed on Windows side
    echo "⚠️  WSL detected: Please install fonts on Windows using Git Bash or manually"
else
    # Linux
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    cd /tmp
    curl -fLo FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
    unzip -o FiraCode.zip -d "$FONT_DIR/FiraCode"
    rm FiraCode.zip
    fc-cache -fv
    cd "$root"
    echo "✓ Fira Code Nerd Font installed"
fi

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "oh-my-zsh already installed"
fi

# Install TPM (Tmux Plugin Manager) if not already installed
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Installing TPM (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    echo "TPM already installed"
fi

# Create necessary directories
echo "Creating config directories..."
mkdir -p ~/.config
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/alacritty/themes
mkdir -p ~/.config/1Password/ssh
mkdir -p ~/.config/btop/themes
mkdir -p ~/.config/jj
mkdir -p ~/.config/tmux
mkdir -p ~/.claude

# Clone alacritty themes if not already present
if [ ! -d "$HOME/.config/alacritty/themes/.git" ]; then
    echo "Cloning alacritty themes..."
    git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
else
    echo "Alacritty themes already installed"
fi

# Create symlinks
echo "Creating symlinks..."
ln -sf "$root/.vimrc" ~/.vimrc
ln -sf "$root/.zshrc" ~/.zshrc
ln -sf "$root/.gitconfig" ~/.gitconfig
ln -sf "$root/.globalgitignore" ~/.globalgitignore
ln -sf "$root/.tmux.conf" ~/.tmux.conf

ln -sf "$root/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
ln -sf "$root/.config/alacritty/catppuccin-mocha.toml" ~/.config/alacritty/catppuccin-mocha.toml
ln -sf "$root/.config/alacritty/rose-pine.toml" ~/.config/alacritty/rose-pine.toml
ln -sf "$root/.config/nvim" ~/.config/nvim
ln -sf "$root/.config/starship.toml" ~/.config/starship.toml
ln -sf "$root/.config/jj/config.toml" ~/.config/jj/config.toml
ln -sfn "$root/.config/tmux/bar" ~/.config/tmux/bar
ln -sf "$root/.config/btop/themes/catppuccin_mocha.theme" ~/.config/btop/themes/catppuccin_mocha.theme
ln -sf "$root/.config/btop/themes/rose-pine.theme" ~/.config/btop/themes/rose-pine.theme
ln -sf "$root/.gitconfig-riotbyte" ~/.gitconfig-riotbyte
ln -sf "$root/.gitconfig-personal" ~/.gitconfig-personal
ln -sf "$root/.claude/statusline.sh" ~/.claude/statusline.sh

mkdir -p ~/.local/bin
ln -sf "$root/bin/bar" ~/.local/bin/bar
ln -sf "$root/bin/bar-lib" ~/.local/bin/bar-lib
ln -sf "$root/bin/bar-sys" ~/.local/bin/bar-sys
ln -sf "$root/bin/bar-pr" ~/.local/bin/bar-pr
ln -sf "$root/bin/bar-reeds" ~/.local/bin/bar-reeds
ln -sf "$root/bin/researchmon" ~/.local/bin/researchmon
ln -sf "$root/bin/statmon" ~/.local/bin/statmon
ln -sf "$root/bin/throb" ~/.local/bin/throb
ln -sf "$root/bin/train" ~/.local/bin/train
ln -sf "$root/bin/glab-merge" ~/.local/bin/glab-merge
ln -sf "$root/bin/codex-wt" ~/.local/bin/codex-wt
ln -sf "$root/bin/zscaler-hold" ~/.local/bin/zscaler-hold
ln -sf "$root/bin/codex-watch" ~/.local/bin/codex-watch
ln -sf "$root/bin/agents-md" ~/.local/bin/agents-md
ln -sf "$root/bin/transcribe-call" ~/.local/bin/transcribe-call
ln -sf "$root/bin/call-devices" ~/.local/bin/call-devices

# Client-specific config lives outside this public repo, in ~/.config/dots-private
private=~/.config/dots-private
if [ -d "$private" ]; then
    echo "Linking private overlay..."
    mkdir -p ~/.config/jj/conf.d
    ln -sf "$private/jj.toml" ~/.config/jj/conf.d/private.toml
    ln -sf "$private/1password-agent.toml" ~/.config/1Password/ssh/agent.toml
    ln -sf "$private/tmux-bar-repos" "$root/.config/tmux/bar/repos"
else
    echo "No $private; skipping client identities, 1Password SSH agent config and PR bar repos"
fi

# Global agent instructions: one generated file shared by Claude Code and Codex
echo "Building global agent instructions..."
mkdir -p ~/.codex
"$root/bin/agents-md"
ln -sfn ~/.config/agents/AGENTS.md ~/.claude/CLAUDE.md
ln -sfn ~/.config/agents/AGENTS.md ~/.codex/AGENTS.md

# peon-ping: config is tracked here; local fixes to the Homebrew peon.sh are re-applied after every upgrade
echo "Configuring peon-ping..."
mkdir -p ~/.claude/hooks/peon-ping
ln -sf "$root/.claude/hooks/peon-ping/config.json" ~/.claude/hooks/peon-ping/config.json
peon_sh="$(brew --prefix 2>/dev/null)/opt/peon-ping/libexec/peon.sh"
if [ -f "$peon_sh" ]; then
    for p in "$root"/patches/peon-ping-*.patch; do
        if patch -s -f -R --dry-run "$peon_sh" "$p" >/dev/null 2>&1; then
            echo "  $(basename "$p") already applied"
        elif patch -s -f --dry-run "$peon_sh" "$p" >/dev/null 2>&1; then
            patch -s -f "$peon_sh" "$p" && echo "  applied $(basename "$p")"
        else
            echo "  $(basename "$p") no longer applies; check whether upstream fixed it" >&2
        fi
    done
fi

# Call audio: setout switches the default output device by UID
if command -v swiftc &> /dev/null; then
    swiftc -O -o ~/.local/bin/setout "$root/audio/setout.swift"
fi

# Configure git
echo "Configuring git..."
git config --global core.excludesfile ~/.globalgitignore

echo "Dotfiles setup complete!"
echo ""
echo "Next steps:"
echo "  1. Set your terminal font to 'FiraCode Nerd Font Mono'"
echo "  2. Open a new terminal to see Starship prompt"
echo "  3. In tmux, press Ctrl+s then Shift+I to install tmux plugins"
echo "  4. In btop, press Esc → Options → Select 'rose-pine' theme"
