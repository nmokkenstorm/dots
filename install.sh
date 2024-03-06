#!/usr/bin/env bash

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# symlink dots
ln -sf  ~/.vimrc ~/.vimrc
ln -sf  ~/.zshrc ~/.zshrc

mkdir -p ~.config
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

ln -sf  $root/.config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml

# global gitignore
git config --global core.excludesfile ~/.globalgitignore
