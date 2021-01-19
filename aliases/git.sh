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
