starship init fish | source

if status is-interactive; and not set -q TMUX
    tmux new-session -A -s "Home Assistant"
end
