#!/usr/bin/with-contenv bashio
# Set up neovim with lazy.nvim and persist plugin data

NVIM_DATA=/data/.local/share/nvim
NVIM_STATE=/data/.local/state/nvim
NVIM_CACHE=/data/.cache/nvim

# Create persistent directories
mkdir -p "${NVIM_DATA}" "${NVIM_STATE}" "${NVIM_CACHE}"

# Use user override if present, otherwise use shipped config
if [ -d /data/.config/nvim ]; then
    bashio::log.info "Using neovim config from /data/.config/nvim/"
else
    bashio::log.info "Using default neovim config"
fi

# Install lazy.nvim if not present
LAZY_DIR="${NVIM_DATA}/lazy/lazy.nvim"
git config --global --add safe.directory "${LAZY_DIR}"
if [ ! -d "${LAZY_DIR}" ]; then
    bashio::log.info "Installing lazy.nvim..."
    git clone --filter=blob:none --branch=stable \
        https://github.com/folke/lazy.nvim.git "${LAZY_DIR}"
fi

# Run headless plugin install
bashio::log.info "Installing neovim plugins..."
su -s /bin/sh ha -c "XDG_CONFIG_HOME=/data/.config XDG_DATA_HOME=/data/.local/share XDG_STATE_HOME=/data/.local/state nvim --headless '+Lazy! sync' +qa 2>/dev/null" || true

# Ensure ha owns everything
chown -R ha:ha /data/.local /data/.cache
