alias python=python2.7

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
