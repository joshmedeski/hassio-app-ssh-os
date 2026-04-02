#!/usr/bin/with-contenv bashio
# Set up tmux plugin manager and plugins

TPM_DIR=/data/.config/tmux/plugins/tpm-redux

# Install tpm-redux if not present
if [ ! -d "${TPM_DIR}" ]; then
    bashio::log.info "Installing tpm-redux..."
    mkdir -p "$(dirname "${TPM_DIR}")"
    git clone https://github.com/RyanMacG/tpm-redux "${TPM_DIR}"
else
    bashio::log.info "Updating tpm-redux..."
    git -C "${TPM_DIR}" pull --quiet
fi

# Symlink persistent plugin/config directory
mkdir -p /data/.config/tmux/plugins
ln -sfn /data/.config/tmux /root/.config/tmux

# Use user override if present, otherwise copy shipped config
if [ -f /data/.config/tmux/tmux.conf ]; then
    bashio::log.info "Using custom tmux config from /data/.config/tmux/tmux.conf"
else
    bashio::log.info "Using default tmux config"
    cp /root/.tmux.conf /data/.config/tmux/tmux.conf
fi

# Install plugins headlessly
bashio::log.info "Installing tmux plugins..."
"${TPM_DIR}/bin/install_plugins" || true
