#!/bin/bash
# Test entrypoint that bypasses s6/bashio for local Docker testing.
# Replicates what the cont-init.d scripts do, without needing the HA Supervisor API.

set -euo pipefail

OPTIONS=/data/options.json
SSH_DIR=/data/.ssh

echo "==> Setting up SSH host keys"
mkdir -p "${SSH_DIR}"
if [ -f "${SSH_DIR}/ssh_host_ed25519_key" ]; then
    cp "${SSH_DIR}"/ssh_host_* /etc/ssh/
else
    ssh-keygen -A
    cp /etc/ssh/ssh_host_* "${SSH_DIR}"/
fi

echo "==> Configuring SSH authentication"
chmod 700 "${SSH_DIR}"

# Read password from options.json
PASSWORD=$(jq -r '.password // empty' "${OPTIONS}")
if [ -n "${PASSWORD}" ]; then
    echo "root:${PASSWORD}" | chpasswd
    echo "    Password auth enabled"
fi

# Read authorized_keys from options.json
KEYS=$(jq -r '.authorized_keys[]? // empty' "${OPTIONS}")
if [ -n "${KEYS}" ]; then
    echo "${KEYS}" > "${SSH_DIR}/authorized_keys"
    chmod 600 "${SSH_DIR}/authorized_keys"
    echo "    $(echo "${KEYS}" | wc -l) authorized key(s) configured"
fi

sed -i \
    -e 's|#PermitRootLogin.*|PermitRootLogin yes|' \
    -e 's|#PasswordAuthentication.*|PasswordAuthentication yes|' \
    -e 's|#AuthorizedKeysFile.*|AuthorizedKeysFile /data/.ssh/authorized_keys|' \
    /etc/ssh/sshd_config

echo "==> Setting up tmux"
TPM_DIR=/data/.config/tmux/plugins/tpm-redux
mkdir -p /data/.config/tmux/plugins
ln -sfn /data/.config/tmux /root/.config/tmux

if [ ! -d "${TPM_DIR}" ]; then
    git clone --quiet https://github.com/RyanMacG/tpm-redux "${TPM_DIR}"
else
    git -C "${TPM_DIR}" pull --quiet 2>/dev/null || true
fi

# Copy shipped config if no custom one exists
if [ ! -f /data/.config/tmux/tmux.conf ]; then
    cp /root/.tmux.conf /data/.config/tmux/tmux.conf
fi

"${TPM_DIR}/bin/install_plugins" 2>/dev/null || true

echo "==> Setting up neovim"
NVIM_DATA=/data/.local/share/nvim
NVIM_STATE=/data/.local/state/nvim
NVIM_CACHE=/data/.cache/nvim
mkdir -p "${NVIM_DATA}" "${NVIM_STATE}" "${NVIM_CACHE}"
mkdir -p /root/.local/share /root/.local/state /root/.cache
ln -sfn "${NVIM_DATA}" /root/.local/share/nvim
ln -sfn "${NVIM_STATE}" /root/.local/state/nvim
ln -sfn "${NVIM_CACHE}" /root/.cache/nvim

# Use custom config if present
if [ -d /data/.config/nvim ]; then
    rm -rf /root/.config/nvim
    ln -sfn /data/.config/nvim /root/.config/nvim
fi

LAZY_DIR="${NVIM_DATA}/lazy/lazy.nvim"
if [ ! -d "${LAZY_DIR}" ]; then
    git clone --filter=blob:none --branch=stable --quiet \
        https://github.com/folke/lazy.nvim.git "${LAZY_DIR}"
fi

nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> Starting sshd on port 22"
exec /usr/sbin/sshd -D -e
