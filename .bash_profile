# Load the default .profile
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

if [ -f /home/linuxbrew/.linuxbrew/etc/bash_completion.d/hub.bash_completion.sh ]; then
  source /home/linuxbrew/.linuxbrew/etc/bash_completion.d/hub.bash_completion.sh
fi