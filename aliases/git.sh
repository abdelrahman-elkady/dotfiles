# Shortcut to commit with a version bump in git
function bump() {
    if [[ -z "$1" ]]; then
      # defaults to bump the patch version
      npm version patch -m ":arrow_up: Bump version to %s"
    else
      npm version $1 -m ":arrow_up: Bump version to %s"
    fi
}
