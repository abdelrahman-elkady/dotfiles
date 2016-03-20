alias ..="cd .."

alias python=python2.7

alias open=xdg-open

# localtunnel
alias tunnel=lt

# saving atom package list in pip like way !
apm() {
    if [[ $@ == "freeze" ]]; then
        command apm list --installed --bare
    else
        command apm "$@"
    fi
}

# compiling cpp with openGL linking
function g++gl(){
  command g++ "$@" -lglut -lGL -lGLU
}

# Life is too short to activate virtualenv manually !
function venv(){
  if [ -n "$@" ]; then
    command source venv/bin/activate
  else
    command source "$@"/bin/activate
  fi
}
