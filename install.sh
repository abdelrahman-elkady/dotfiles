#!/usr/bin/env bash

# Get current dir (so run this script from anywhere)

export DOTFILES_DIR EXTRA_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXTRA_DIR="$HOME/.extra"

mkdir -p "$HOME/.config"

# Bash symlinks
ln -sfv "$DOTFILES_DIR/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/.bashrc" ~
ln -sfv "$DOTFILES_DIR/.bash_aliases" ~

# Git symlinks
ln -sfv "$DOTFILES_DIR/git/.gitconfig" ~

# Tmux symlinks
ln -sfv "$DOTFILES_DIR/.tmux.conf" ~

# Atom symlinks
ln -sfv $DOTFILES_DIR/atom/config.cson $HOME/.atom/config.cson
ln -sfv $DOTFILES_DIR/atom/keymap.cson $HOME/.atom/keymap.cson
ln -sfv $DOTFILES_DIR/atom/packages.txt $HOME/.atom/packages.txt
ln -sfv $DOTFILES_DIR/atom/styles.less $HOME/.atom/styles.less

# VS Code symlinks
ln -sfv $DOTFILES_DIR/vscode/settings.json $HOME/.config/Code/User/settings.json
ln -sfv $DOTFILES_DIR/vscode/keybindings.json $HOME/.config/Code/User/keybindings.json
ln -sfv $DOTFILES_DIR/vscode/snippets/javascript.json $HOME/.config/Code/User/snippets/javascript.json

# Starship symlinks
ln -sfv "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml
