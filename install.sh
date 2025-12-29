#!/usr/bin/env bash

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# symlink dots
ln -sf "$root/.vimrc" ~/.vimrc
ln -sf "$root/.zshrc" ~/.zshrc
ln -sf "$root/.gitconfig" ~/.gitconfig
ln -sf "$root/.globalgitignore" ~/.globalgitignore
ln -sf "$root/.tmux.conf" ~/.tmux.conf

mkdir -p ~/.config
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

ln -sf "$root/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
ln -sf "$root/.config/alacritty/catppuccin-mocha.toml" ~/.config/alacritty/catppuccin-mocha.toml

mkdir -p ~/.config/1Password/ssh
ln -sf "$root/.config/1Password/ssh/agent.toml" ~/.config/1Password/ssh/agent.toml

ln -sf "$root/.config/nvim" ~/.config/nvim

# Starship configuration
ln -sf "$root/.config/starship.toml" ~/.config/starship.toml

# btop theme
mkdir -p ~/.config/btop/themes
ln -sf "$root/.config/btop/themes/catppuccin_mocha.theme" ~/.config/btop/themes/catppuccin_mocha.theme

# global gitignore
git config --global core.excludesfile ~/.globalgitignore
