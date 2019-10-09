alias dco='docker-compose'

# Run docker in interactive mode using (bash)
# defaults to the current directory name as the container name if no argument is passed
function d-interactive() {
    if [[ -z "$1" ]]; then
        shift # discard the argument (the container name)
        command docker exec -it ${PWD##*/} bash
    else
        command docker exec -it "$@" bash
    fi

}