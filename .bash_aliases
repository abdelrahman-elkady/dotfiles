alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias open=xdg-open

alias gcopy='xclip -selection clipboard'

# localtunnel
alias tunnel=lt

# ssh tunnel
alias socks='ssh -D 2048 -C -q -N main.do'

alias git-clear-tags='git tag -d $(git tag -l)'

alias wifi-restart='killall nm-applet; nohup nm-applet &'


# saving atom package list in pip like way !
apm() {
    if [[ $@ == "freeze" ]]; then
        command apm list --installed --bare
    else
        command apm "$@"
    fi
}

# compiling cpp with openGL linking
function g++gl() {
  command g++ "$@" -lglut -lGL -lGLU
}

# Life is too short to activate virtualenv manually !
function venv() {
  if [ -n "$@" ]; then
    command source venv/bin/activate
  else
    command source "$@"/bin/activate
  fi
}

# Shortcut for pip installation as user
function pip() {
    if [[ $1 == "-u" ]]; then
        shift # discard first arg ( which is -u )
        command pip install --user "$@"
    else
        command pip "$@"
    fi
}

# Shortcut to commit with a version bump in git
function bump() {
    if [[ -z "$1" ]]; then
      # defaults to bump the patch version
      npm version patch -m ":arrow_up: Bump version to %s"
    else
      npm version $1 -m ":arrow_up: Bump version to %s"
    fi
}

source "$HOME/dotfiles/aliases/docker.sh"