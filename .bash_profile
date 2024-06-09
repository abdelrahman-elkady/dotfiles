# Load the default .profile, otherwise load .bashrc
if [[ -s "$HOME/.profile" ]]; then
  source "$HOME/.profile"
else
  source "$HOME/.bashrc"
fi

if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
fi

if [ -f /home/linuxbrew/.linuxbrew/etc/bash_completion.d/hub.bash_completion.sh ]; then
  source /home/linuxbrew/.linuxbrew/etc/bash_completion.d/hub.bash_completion.sh
fi
