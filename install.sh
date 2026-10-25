#!/usr/bin/env bash

set -e  # Exit on error

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin*) os=mac ;;
  Linux*) grep -qi microsoft /proc/version 2>/dev/null && os=wsl || os=linux ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) os=unknown ;;
esac

# Headless Linux boxes skip the terminal emulator, fonts and 1Password agent
desktop=false
{ [ "$os" = mac ] || [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; } && desktop=true

echo "Setting up dotfiles ($os, desktop=$desktop)..."

install_starship_release() {
  local arch target url dir
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) target=aarch64-unknown-linux-musl ;;
    x86_64) target=x86_64-unknown-linux-musl ;;
    *) echo "No starship release for $arch"; return 1 ;;
  esac
  url="https://github.com/starship/starship/releases/latest/download/starship-$target.tar.gz"
  dir="$(mktemp -d)"
  curl -fsSL -o "$dir/starship.tar.gz" "$url"
  curl -fsSL -o "$dir/starship.tar.gz.sha256" "$url.sha256"
  echo "$(cat "$dir/starship.tar.gz.sha256")  $dir/starship.tar.gz" | sha256sum -c -
  tar -xzf "$dir/starship.tar.gz" -C "$dir"
  install -m 755 "$dir/starship" "$HOME/.local/bin/starship"
  rm -rf "$dir"
}

mkdir -p ~/.local/bin

if [ "$os" = mac ]; then
  if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Homebrew already installed"
  fi

  echo "Installing required tools..."
  brew install starship btop tmux alacritty bat jq macmon python glab || true

  echo "Installing Fira Code Nerd Font..."
  brew install --cask font-fira-code-nerd-font || true
elif [ "$os" = linux ] && command -v dnf &> /dev/null; then
  echo "Installing required tools..."
  sudo dnf install -y zsh tmux git bat jq btop python3 neovim glab gh fastfetch zsh-syntax-highlighting unzip

  if ! command -v starship &> /dev/null; then
    echo "Installing starship from its GitHub release..."
    install_starship_release
  fi

  if [ "$desktop" = true ]; then
    echo "Installing Fira Code Nerd Font..."
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    curl -fLo /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
    unzip -o /tmp/FiraCode.zip -d "$FONT_DIR/FiraCode"
    rm /tmp/FiraCode.zip
    fc-cache -f
  fi
elif [ "$os" = windows ]; then
  echo "Downloading Fira Code Nerd Font..."
  TEMP_DIR="/c/Users/$USER/AppData/Local/Temp/FiraCodeNF"
  mkdir -p "$TEMP_DIR"
  curl -fLo "$TEMP_DIR/FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
  unzip -o "$TEMP_DIR/FiraCode.zip" -d "$TEMP_DIR"

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
elif [ "$os" = wsl ]; then
  echo "WSL detected: install fonts on the Windows side"
else
  echo "No package manager setup for $os: install zsh, tmux, starship and friends by hand"
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
else
  echo "oh-my-zsh already installed"
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing TPM (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo "TPM already installed"
fi

echo "Creating config directories..."
mkdir -p ~/.config ~/.config/btop/themes ~/.config/jj ~/.config/tmux ~/.claude

echo "Creating symlinks..."
ln -sf "$root/.vimrc" ~/.vimrc
ln -sf "$root/.zshrc" ~/.zshrc
ln -sf "$root/.gitconfig" ~/.gitconfig
ln -sf "$root/.globalgitignore" ~/.globalgitignore
ln -sf "$root/.tmux.conf" ~/.tmux.conf
[ "$os" = mac ] && gitconfig_os=.gitconfig-macos || gitconfig_os=.gitconfig-linux
ln -sf "$root/$gitconfig_os" ~/.gitconfig-os

ln -sfn "$root/.config/nvim" ~/.config/nvim
ln -sf "$root/.config/starship.toml" ~/.config/starship.toml
ln -sf "$root/.config/jj/config.toml" ~/.config/jj/config.toml
mkdir -p ~/.config/zscaler-schedule
ln -sf "$root/.config/zscaler-schedule/schedule" ~/.config/zscaler-schedule/schedule
ln -sfn "$root/.config/tmux/bar" ~/.config/tmux/bar
ln -sf "$root/.config/btop/themes/catppuccin_mocha.theme" ~/.config/btop/themes/catppuccin_mocha.theme
ln -sf "$root/.config/btop/themes/rose-pine.theme" ~/.config/btop/themes/rose-pine.theme
ln -sf "$root/.gitconfig-riotbyte" ~/.gitconfig-riotbyte
ln -sf "$root/.gitconfig-personal" ~/.gitconfig-personal
ln -sf "$root/.claude/statusline.sh" ~/.claude/statusline.sh

if [ "$desktop" = true ]; then
  mkdir -p ~/.config/alacritty/themes ~/.config/1Password/ssh
  if [ ! -d "$HOME/.config/alacritty/themes/.git" ]; then
    echo "Cloning alacritty themes..."
    git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
  fi
  ln -sf "$root/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
  ln -sf "$root/.config/alacritty/catppuccin-mocha.toml" ~/.config/alacritty/catppuccin-mocha.toml
  ln -sf "$root/.config/alacritty/rose-pine.toml" ~/.config/alacritty/rose-pine.toml
  fi

# Client-specific config lives outside this public repo, in ~/.config/dots-private
private=~/.config/dots-private
if [ -d "$private" ]; then
    echo "Linking private overlay..."
    mkdir -p ~/.config/jj/conf.d ~/.config/1Password/ssh
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

for tool in bar bar-lib bar-sys bar-pr bar-reeds bar-music teal-now researchmon statmon throb train glab-merge codex-wt zscaler-hold codex-watch agents-md transcribe-call call-devices; do
  ln -sf "$root/bin/$tool" ~/.local/bin/"$tool"
done

if [ "$os" = linux ] && [ "$(basename "$(getent passwd "$USER" | cut -d: -f7)")" != zsh ]; then
  echo "Switching login shell to zsh..."
  sudo usermod -s "$(command -v zsh)" "$USER"
fi

echo "Dotfiles setup complete!"
echo ""
echo "Next steps:"
[ "$desktop" = true ] && echo "  - Set your terminal font to 'FiraCode Nerd Font Mono'"
echo "  - Open a new shell to see the Starship prompt"
echo "  - In tmux, press Ctrl+s then Shift+I to install tmux plugins"
echo "  - In btop, press Esc, Options, select the 'rose-pine' theme"
