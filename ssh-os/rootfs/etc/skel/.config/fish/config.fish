if status is-interactive
    fish_vi_key_bindings

    if command -q starship
        starship init fish | source
    end

    if not set -q TMUX
        tmux new-session -A -s "Home Assistant"
    end
end
