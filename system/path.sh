### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# Android platform tools
export PATH=$HOME/Android/Sdk/platform-tools:$PATH

# Android Sdk tools
export PATH=$HOME/Android/Sdk/tools:$PATH

export PATH=$PATH:~/.local/bin
export PATH=$PATH:~/bin

export PATH=$PATH:/usr/local/go/bin

# macos docker user path
if [ "$(uname)" == "Darwin" ]; then
  export PATH=$PATH:$HOME/.docker/bin
fi
