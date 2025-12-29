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
brew install starship btop tmux alacritty bat || true

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
ln -sf "$root/.config/1Password/ssh/agent.toml" ~/.config/1Password/ssh/agent.toml
ln -sf "$root/.config/nvim" ~/.config/nvim
ln -sf "$root/.config/starship.toml" ~/.config/starship.toml
ln -sf "$root/.config/btop/themes/catppuccin_mocha.theme" ~/.config/btop/themes/catppuccin_mocha.theme

# Configure git
echo "Configuring git..."
git config --global core.excludesfile ~/.globalgitignore

echo "Dotfiles setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal to see Starship prompt"
echo "  2. In tmux, press Ctrl+b then Shift+I to install Catppuccin theme"
echo "  3. In btop, press Esc → Options → Select 'catppuccin_mocha' theme"
