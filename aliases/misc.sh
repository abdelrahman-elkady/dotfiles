alias wifi-restart='killall nm-applet; nohup nm-applet &'

alias audio-restart='alsactl init'

alias open=xdg-open

function clip() {
  if [[ "$(uname)" == "Darwin" ]]; then
    pbcopy
  else
    xclip -selection clipboard
  fi
}

alias gcopy=clip

# https://github.com/localtunnel/localtunnel
alias tunnel=lt

if [[ "$(uname)" != "Darwin" ]]; then
  alias bat=batcat
fi


alias star='eval "$(starship init bash)"'

alias lock-tab='xinput map-to-output "HUION 420 Pen Pen (0)" "DP-1"'
