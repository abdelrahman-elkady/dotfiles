alias compose-up='docker-compose up'
alias cup="docker-compose up -d --build && dinteractive"

alias cdown='docker-compose down'
alias cdown-f='docker-compose down --rmi local -v'

alias dpsname='docker ps --format "{{.Names}}"'
alias dpspretty='docker ps --format "table {{.Image}} \t| {{.Names}} \t| {{.Status}}"'

# TODO: should be a function instead
alias dpsname-a='docker ps --format "{{.Names}}" -a'
alias dpspretty-a='docker ps --format "table {{.Image}} \t| {{.Names}} \t| {{.Status}}" -a'

# Run docker in interactive mode using (bash)
# defaults to the current directory name as the container name if no argument is passed
function dinteractive() {
    if [[ -z "$1" ]]; then
        shift # discard the argument (the container name)
        command docker exec -it ${PWD##*/} bash
    else
        command docker exec -it "$@" bash
    fi

}
