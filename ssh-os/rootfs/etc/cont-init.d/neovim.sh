#!/usr/bin/with-contenv bashio
# Set up neovim with lazy.nvim and persist plugin data

NVIM_DATA=/data/.local/share/nvim
NVIM_STATE=/data/.local/state/nvim
NVIM_CACHE=/data/.cache/nvim

# Create persistent directories
mkdir -p "${NVIM_DATA}" "${NVIM_STATE}" "${NVIM_CACHE}"

# Symlink to persistent storage
mkdir -p /root/.local/share /root/.local/state /root/.cache
ln -sfn "${NVIM_DATA}" /root/.local/share/nvim
ln -sfn "${NVIM_STATE}" /root/.local/state/nvim
ln -sfn "${NVIM_CACHE}" /root/.cache/nvim

# Use user override if present, otherwise use shipped config
if [ -d /data/.config/nvim ]; then
    bashio::log.info "Using custom neovim config from /data/.config/nvim/"
    rm -rf /root/.config/nvim
    ln -sfn /data/.config/nvim /root/.config/nvim
else
    bashio::log.info "Using default neovim config"
fi

# Install lazy.nvim if not present
LAZY_DIR="${NVIM_DATA}/lazy/lazy.nvim"
if [ ! -d "${LAZY_DIR}" ]; then
    bashio::log.info "Installing lazy.nvim..."
    git clone --filter=blob:none --branch=stable \
        https://github.com/folke/lazy.nvim.git "${LAZY_DIR}"
fi

# Run headless plugin install
bashio::log.info "Installing neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
