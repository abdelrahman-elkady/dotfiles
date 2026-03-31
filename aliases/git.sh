# Shortcut to commit with a version bump in git
function bump() {
    if [[ -z "$1" ]]; then
      # defaults to bump the patch version
      npm version patch -m "chore: :arrow_up: Bump version to %s"
    else
      npm version $1 -m "chore: :arrow_up: Bump version to %s"
    fi
}

# Create and raise an empty pr
function trigger-ci() {
  timestamp=$(date +"%I-%M-%S")
  branch_name="ci-$timestamp"

  git checkout -b "$branch_name"
  git commit --allow-empty -m "fix: trigger ci"

  git push origin "$branch_name"

  gh pr create
}

delete-branches() {
    echo "this command will delete all branches except (master|main) and the branch you are on"
    if [[ $1 == '-i' ]]; then
        echo "You are running in interactive mode"
    else
        echo "(warning) you are not running in interactive mode"
    fi

    read -p "Are you sure (y/n)? " reply

    if [[ ! $reply =~ ^[Yy]$ ]]; then
        return 0
    fi

    branch=$(git branch | grep '*' | awk '{print $2}')
    branches=($(git branch | grep -v "master\|main\|*"))

    local green='\033[0;32m'
    local red='\033[0;31m'
    local yellow='\033[1;33m'
    local nc='\033[0m'

    for branch in "${branches[@]}"; do
        if [[ $1 == '-i' ]]; then
            echo -ne "Delete ${yellow}${branch}${nc} (y/n)? "
            read -n 1 reply
            echo
            if [[ $reply =~ ^[Yy]$ ]]; then
                git branch -D ${branch}
                echo -e "${green}Deleted ${branch}${nc}"
            else
                echo -e "${red}Skipped ${branch}${nc}"
            fi
        else
            git branch -D ${branch}
        fi
    done
}
