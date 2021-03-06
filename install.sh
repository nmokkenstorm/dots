#!/usr/bin/env bash

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# symlink dots
ln -sf  $(pwd)/.vimrc ~/.vimrc
ln -sf  $(pwd)/.zshrc ~/.zshrc

# global gitignore
git config --global core.excludesfile ${pwd}/.globalgitignore
