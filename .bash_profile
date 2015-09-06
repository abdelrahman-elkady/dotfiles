# Exporting dotfiles path
export DOTFILES="$HOME/dotfiles/"

# Loading env and path
[[ -s "$DOTFILES/system/env" ]] && source "$DOTFILES/system/env"
[[ -s "$DOTFILES/system/path" ]] && source "$DOTFILES/system/path"

# Load the default .profile
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

# rbenv
eval "$(rbenv init -)"
