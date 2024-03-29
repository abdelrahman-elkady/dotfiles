# ssh tunnel
alias socks='ssh -D $SOCKS_PORT -C -q -N main.do'

alias git-clear-tags='git tag -d $(git tag -l)'

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

source "$HOME/dotfiles/aliases/navigation.sh"
source "$HOME/dotfiles/aliases/docker.sh"
source "$HOME/dotfiles/aliases/k8s.sh"
source "$HOME/dotfiles/aliases/misc.sh"
source "$HOME/dotfiles/aliases/git.sh"
