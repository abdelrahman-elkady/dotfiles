#!/usr/bin/env bash

export DOTFILES_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/.config"

# Powerline
if command -v uv >/dev/null 2>&1; then
  echo "Installing powerline-status via uv..."
  uv tool install powerline-status
else
  echo "Warning: uv not found. Install uv first: curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "Then run: uv tool install powerline-status"
fi

# Bash
ln -sfv "$DOTFILES_DIR/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/.bashrc" ~
ln -sfv "$DOTFILES_DIR/.bash_aliases" ~

# Git
ln -sfv "$DOTFILES_DIR/git/.gitconfig" ~
ln -sfv "$DOTFILES_DIR/git/.gitignore_global" ~

# Tmux
ln -sfv "$DOTFILES_DIR/.tmux.conf" ~

# cmux
mkdir -p "$HOME/.config/cmux"
ln -sfv "$DOTFILES_DIR/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"

mkdir -p "$HOME/.config/ghostty"
ln -sfv "$DOTFILES_DIR/cmux/config.ghostty" "$HOME/.config/ghostty/config.ghostty"

# OpenCode
mkdir -p "$HOME/.config/opencode/themes"
ln -sfv "$DOTFILES_DIR/opencode/themes/breeze.json" "$HOME/.config/opencode/themes/breeze.json"
ln -sfv "$DOTFILES_DIR/opencode/tui.json" "$HOME/.config/opencode/tui.json"

# Pi
mkdir -p "$HOME/.pi/agent"
ln -sfv "$DOTFILES_DIR/pi/agent/settings.json" "$HOME/.pi/agent/settings.json"

rm -rf "$HOME/.pi/agent/extensions"
ln -sv "$DOTFILES_DIR/pi/agent/extensions" "$HOME/.pi/agent/extensions"

if command -v pi >/dev/null 2>&1; then
  echo "Installing Pi extension packages..."
  pi update --extensions
else
  echo "Warning: pi not found; skipping Pi extension package installation."
fi

# Claude Code
mkdir -p "$HOME/.claude"
ln -sfv "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
ln -sfv "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
ln -sfv "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# GitHub CLI
mkdir -p "$HOME/.config/gh"
ln -sfv "$DOTFILES_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"

# VS Code symlinks
# Using settings sync now 🙈
# ln -sfv $DOTFILES_DIR/vscode/settings.json $HOME/.config/Code/User/settings.json
# ln -sfv $DOTFILES_DIR/vscode/keybindings.json $HOME/.config/Code/User/keybindings.json
# ln -sfv $DOTFILES_DIR/vscode/snippets/javascript.json $HOME/.config/Code/User/snippets/javascript.json

# Starship
ln -sfv "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

if [ "$(uname)" == "Darwin" ]; then
  # only load homebrew if macos
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # iTerm2
  if pgrep -xq iTerm2; then
    echo "⚠️  iTerm2 is running — it will overwrite the prefs set below when it quits."
    echo "   Quit iTerm2 and re-run ./install.sh from Terminal.app."
  fi
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2

  # Rectangle
  defaults import com.knollsoft.Rectangle "$DOTFILES_DIR/rectangle/com.knollsoft.Rectangle.plist"

  # Shell completion
  brew install bash-completion

  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash
  chmod +x ~/.git-completion.bash
fi
