#!/usr/bin/with-contenv bashio
# Seed default dotfiles from /etc/skel into /data on first boot.
# Once seeded, users can customize files in /data/.config/ and they persist.

# Seed config directory
if [ ! -d /data/.config ]; then
    bashio::log.info "First boot: seeding default configs into /data/.config/"
    cp -R /etc/skel/.config /data/.config
else
    bashio::log.info "Using existing configs from /data/.config/"
fi

# Seed tmux config
if [ ! -f /data/.config/tmux/tmux.conf ]; then
    mkdir -p /data/.config/tmux
    cp /etc/skel/.tmux.conf /data/.config/tmux/tmux.conf
    bashio::log.info "Seeded default tmux config"
fi

# Ensure persistent data directories exist
mkdir -p /data/.local/share /data/.local/state /data/.cache /data/.ssh

# Set ownership for ha user
chown -R ha:ha /data/.config /data/.local /data/.cache /data/.ssh
