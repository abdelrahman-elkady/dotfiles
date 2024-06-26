# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
# force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# enable bash completion on macos
if [ "$(uname)" == "Darwin" ]; then
  if [ -f /opt/homebrew/etc/bash_completion ]; then
    . /opt/homebrew/etc/bash_completion
  fi
fi


# Exporting dotfiles path
export DOTFILES="$HOME/dotfiles"

# Loading config files
[[ -s "$DOTFILES/system/env.sh" ]] && source "$DOTFILES/system/env.sh"
[[ -s "$DOTFILES/system/path.sh" ]] && source "$DOTFILES/system/path.sh"
[[ -s "$DOTFILES/completions/npm-completion.sh" ]] && source "$DOTFILES/completions/npm-completion.sh"
[[ -s "$DOTFILES/completions/heroku.sh" ]] && source "$DOTFILES/completions/heroku.sh"
[[ -s "$DOTFILES/completions/hub-completion.sh" ]] && source "$DOTFILES/completions/hub-completion.sh"
[[ -s "$DOTFILES/completions/gh-completion.sh" ]] && source "$DOTFILES/completions/gh-completion.sh"
[[ -s "$DOTFILES/completions/kubectl.sh" ]] && source "$DOTFILES/completions/kubectl.sh"
[[ -s ~/.git-completion.bash ]] && source ~/.git-completion.bash

if [ ! -z "$(ls -A "$DOTFILES/.no-check")" ]; then
   for file in $DOTFILES/.no-check/*; do
     source $file;
   done
fi

# modified version of https://github.com/xvoland/Extract/blob/master/extract.sh
# Extracting different archives with one function !
function extract {
 if [ -z "$1" ]; then
    # display usage if no parameters given
    echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
 else
    if [ -f "$1" ] ; then

        # I hate scattering files around !, make a directory to extract files in if needed
        name=${2}
        archive_dir=.
        if [ -n "$name" ]; then
          mkdir $name && cd $name
          archive_dir=$archive_dir/..
        fi

        case "$1" in
          *.tar.bz2)   tar xvjf $archive_dir/"$1"    ;;
          *.tar.gz)    tar xvzf $archive_dir/"$1"    ;;
          *.tar.xz)    tar xvJf $archive_dir/"$1"    ;;
          *.lzma)      unlzma $archive_dir/"$1"      ;;
          *.bz2)       bunzip2 $archive_dir/"$1"     ;;
          *.rar)       unrar x -ad $archive_dir/"$1" ;;
          *.gz)        gunzip $archive_dir/"$1"      ;;
          *.tar)       tar xvf $archive_dir/"$1"     ;;
          *.tbz2)      tar xvjf $archive_dir/"$1"    ;;
          *.tgz)       tar xvzf $archive_dir/"$1"    ;;
          *.zip)       unzip $archive_dir/"$1"       ;;
          *.Z)         uncompress $archive_dir/"$1"  ;;
          *.7z)        7z x $archive_dir/"$1"        ;;
          *.xz)        unxz $archive_dir/"$1"        ;;
          *.exe)       cabextract $archive_dir/"$1"  ;;
          *)           echo "extract: '$1' - unknown archive method" ;;
        esac
    else
        echo "'$1' - file does not exist"
    fi
fi
}

# Let's add some colors ! and git branch too
function color_my_prompt {
    local __user_and_host="\[\033[01;32m\]\u@\h"
    local __cur_location="\[\033[01;34m\]\w"
    local __git_branch_color="\[\033[31m\]"
    local __git_branch='`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\(\\\\\1\)\ /`'
    local __prompt_tail="\[\033[01;34m\]$"
    local __last_color="\[\033[00m\]"
    export PS1="$__user_and_host $__cur_location $__git_branch_color$__git_branch$__prompt_tail$__last_color "
}

color_my_prompt

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# GVM
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"


if [ "$(uname)" == "Darwin" ]; then
  # only load homebrew if macos
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# run starship's alias, enable/disable by commenting
star
