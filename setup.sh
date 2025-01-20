#! /bin/bash

DOTFILES_DIR=~/.config
ln -sf ~/.config/zsh/zshrc ~/.zshrc
ln -sf ~/.config/bash/bashrc ~/.bashrc
ln -sf ~/.config/git/gitconfig ~/.gitconfig

echo "Dotfiles have been successfully linked from ~/.config!"

