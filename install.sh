#!/usr/bin/env bash

# Get current dir (so run this script from anywhere)

export DOTFILES_DIR EXTRA_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXTRA_DIR="$HOME/.extra"

mkdir -p "$HOME/.config"

# Install powerline via uv (cross-platform)
if command -v uv >/dev/null 2>&1; then
  echo "Installing powerline-status via uv..."
  uv tool install powerline-status
else
  echo "Warning: uv not found. Install uv first: curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "Then run: uv tool install powerline-status"
fi

# Bash symlinks
ln -sfv "$DOTFILES_DIR/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/.bashrc" ~
ln -sfv "$DOTFILES_DIR/.bash_aliases" ~

# Git symlinks
ln -sfv "$DOTFILES_DIR/git/.gitconfig" ~
ln -sfv "$DOTFILES_DIR/git/.gitignore_global" ~

# Tmux symlinks
ln -sfv "$DOTFILES_DIR/.tmux.conf" ~

# cmux symlinks (tmux-style keybindings for cmux.app)
mkdir -p "$HOME/.config/cmux"
ln -sfv "$DOTFILES_DIR/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"

# cmux terminal appearance (cmux embeds Ghostty; mirrors the iTerm2 theme/font)
# config.ghostty is read by cmux only — standalone Ghostty reads ghostty/config
# Revert: rm ~/.config/ghostty/config.ghostty, then reload cmux config (ctrl+a r)
mkdir -p "$HOME/.config/ghostty"
ln -sfv "$DOTFILES_DIR/cmux/config.ghostty" "$HOME/.config/ghostty/config.ghostty"

# opencode theme + TUI selection (mirrors the iTerm2/cmux Breeze palette)
# breeze.json is a dark theme built from iterm2/com.googlecode.iterm2.plist's
# KDE Breeze scheme (customized reds); tui.json pins /theme to "breeze".
# Revert: rm ~/.config/opencode/themes/breeze.json ~/.config/opencode/tui.json,
# then restart opencode and pick another theme with /theme.
mkdir -p "$HOME/.config/opencode/themes"
ln -sfv "$DOTFILES_DIR/opencode/themes/breeze.json" "$HOME/.config/opencode/themes/breeze.json"
ln -sfv "$DOTFILES_DIR/opencode/tui.json" "$HOME/.config/opencode/tui.json"

# Claude Code global config (portable across machines)
# settings.json holds shared, non-secret config (plugins, effort, statusline, etc.);
# statusline-command.sh is the script settings.json points at to render the status line.
# Machine-specific overrides belong in ~/.claude/settings.local.json (untracked) so
# this shared file stays clean. Note: settings.json references statusline-command.sh
# by absolute path, so this assumes the same $HOME across machines.
# Revert: rm ~/.claude/settings.json ~/.claude/statusline-command.sh (restore from a backup if needed).
mkdir -p "$HOME/.claude"
ln -sfv "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
ln -sfv "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

# VS Code symlinks
# Using settings sync now 🙈
# ln -sfv $DOTFILES_DIR/vscode/settings.json $HOME/.config/Code/User/settings.json
# ln -sfv $DOTFILES_DIR/vscode/keybindings.json $HOME/.config/Code/User/keybindings.json
# ln -sfv $DOTFILES_DIR/vscode/snippets/javascript.json $HOME/.config/Code/User/snippets/javascript.json

# Starship symlinks
ln -sfv "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

if [ "$(uname)" == "Darwin" ]; then
  # only load homebrew if macos
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # iTerm2 - load settings from the repo's iterm2/ folder and save changes back automatically
  # (the plist in iterm2/ is auto-saved by iTerm2 and will often be dirty; commit = checkpoint)
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  # selection: 0 = save on quit, 1 = never, 2 = save automatically
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2

  # install bash completion
  brew install bash-completion

  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash
  chmod +x ~/.git-completion.bash
fi
