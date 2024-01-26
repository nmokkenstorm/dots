#!/usr/bin/env bash

root=$(pwd)

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# symlink dots
ln -sf  $root/.vimrc ~/.vimrc
ln -sf  $root/.zshrc ~/.zshrc

mkdir -p $root/.config
mkdir -p $root/.config/alacritty

ln -sf  $root/.config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml

# global gitignore
git config --global core.excludesfile ~/.globalgitignore
