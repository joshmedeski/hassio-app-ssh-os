#!/usr/bin/with-contenv bashio
# Set up tmux plugin manager and plugins

TPM_DIR=/data/.config/tmux/plugins/tpm-redux

# Allow git operations on persistent /data directories owned by different users
git config --global --add safe.directory "${TPM_DIR}"

# Install tpm-redux if not present
if [ ! -d "${TPM_DIR}" ]; then
    bashio::log.info "Installing tpm-redux..."
    mkdir -p "$(dirname "${TPM_DIR}")"
    git clone https://github.com/RyanMacG/tpm-redux "${TPM_DIR}"
else
    bashio::log.info "Updating tpm-redux..."
    git -C "${TPM_DIR}" pull --quiet
fi

# Use user override if present, otherwise default was already seeded by defaults.sh
if [ -f /data/.config/tmux/tmux.conf ]; then
    bashio::log.info "Using tmux config from /data/.config/tmux/tmux.conf"
else
    bashio::log.info "Using default tmux config (seeded by defaults.sh)"
fi

# Install plugins headlessly
bashio::log.info "Installing tmux plugins..."
"${TPM_DIR}/bin/install_plugins" || true

# Ensure ha owns tmux config
chown -R ha:ha /data/.config/tmux
