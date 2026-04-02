# XDG directories (persist config in /data, separate from /homeassistant)
set -gx XDG_CONFIG_HOME /data/.config
set -gx XDG_DATA_HOME /data/.local/share
set -gx XDG_STATE_HOME /data/.local/state

starship init fish | source

if status is-interactive; and not set -q TMUX
    tmux new-session -A -s "Home Assistant"
end
