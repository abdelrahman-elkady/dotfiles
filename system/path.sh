# rbenv setup
export PATH="$HOME/.rbenv/bin:$PATH"

# ruby-build plugin for rbenv runy installations
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"

# Rails `gem`
export PATH=$PATH:$HOME/.rbenv/shims/gem

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# Atom beautify beautifiers !
export PATH=$PATH:$HOME/.rbenv/shims/rbeautify
export PATH=$PATH:$HOME/.rbenv/shims/htmlbeautifier

# Android platform tools
export PATH=$HOME/Android/Sdk/platform-tools:$PATH

# Android Sdk tools
export PATH=$HOME/Android/Sdk/tools:$PATH

# Vanilla latex
# Following this installation :
# http://tex.stackexchange.com/questions/1092/
# how-to-install-vanilla-texlive-on-debian-or-ubuntu
export PATH=/opt/texbin:/opt/texbin/tlmgr:$PATH

export PATH=$PATH:~/.local/bin

# Bake paths for ns3
export BAKE_HOME=~/bin/bake
export PATH=$PATH:$BAKE_HOME
export PYTHONPATH=$PYTHONPATH:$BAKE_HOME

# SUMO Installation
export SUMO_HOME=usr/share/sumo/