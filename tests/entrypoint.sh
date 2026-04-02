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

echo "==> Seeding default configs"
if [ ! -d /data/.config ]; then
    cp -R /etc/skel/.config /data/.config
fi
if [ ! -f /data/.config/tmux/tmux.conf ]; then
    mkdir -p /data/.config/tmux
    cp /etc/skel/.tmux.conf /data/.config/tmux/tmux.conf
fi
mkdir -p /data/.local/share /data/.local/state /data/.cache
chown -R ha:ha /data/.config /data/.local /data/.cache /data/.ssh

echo "==> Configuring SSH authentication"
chmod 700 "${SSH_DIR}"
chown ha:ha "${SSH_DIR}"

# Read password from options.json
PASSWORD=$(jq -r '.password // empty' "${OPTIONS}")
if [ -n "${PASSWORD}" ]; then
    echo "ha:${PASSWORD}" | chpasswd
    echo "    Password auth enabled"
fi

# Read authorized_keys from options.json
KEYS=$(jq -r '.authorized_keys[]? // empty' "${OPTIONS}")
if [ -n "${KEYS}" ]; then
    echo "${KEYS}" > "${SSH_DIR}/authorized_keys"
    chmod 600 "${SSH_DIR}/authorized_keys"
    chown ha:ha "${SSH_DIR}/authorized_keys"
    echo "    $(echo "${KEYS}" | wc -l) authorized key(s) configured"
fi

sed -i \
    -e 's|#\?PermitRootLogin.*|PermitRootLogin no|' \
    -e 's|#\?PasswordAuthentication.*|PasswordAuthentication yes|' \
    -e 's|#\?AuthorizedKeysFile.*|AuthorizedKeysFile /data/.ssh/authorized_keys|' \
    /etc/ssh/sshd_config

if ! grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    echo "AllowUsers ha" >> /etc/ssh/sshd_config
fi

echo "==> Setting up tmux"
TPM_DIR=/data/.config/tmux/plugins/tpm-redux
mkdir -p /data/.config/tmux/plugins
git config --global --add safe.directory "${TPM_DIR}"

if [ ! -d "${TPM_DIR}" ]; then
    git clone --quiet https://github.com/RyanMacG/tpm-redux "${TPM_DIR}"
else
    git -C "${TPM_DIR}" pull --quiet 2>/dev/null || true
fi

"${TPM_DIR}/bin/install_plugins" 2>/dev/null || true

echo "==> Setting up neovim"
NVIM_DATA=/data/.local/share/nvim
NVIM_STATE=/data/.local/state/nvim
NVIM_CACHE=/data/.cache/nvim
mkdir -p "${NVIM_DATA}" "${NVIM_STATE}" "${NVIM_CACHE}"

LAZY_DIR="${NVIM_DATA}/lazy/lazy.nvim"
git config --global --add safe.directory "${LAZY_DIR}"
if [ ! -d "${LAZY_DIR}" ]; then
    git clone --filter=blob:none --branch=stable --quiet \
        https://github.com/folke/lazy.nvim.git "${LAZY_DIR}"
fi

su -s /bin/sh ha -c "XDG_CONFIG_HOME=/data/.config XDG_DATA_HOME=/data/.local/share XDG_STATE_HOME=/data/.local/state nvim --headless '+Lazy! sync' +qa 2>/dev/null" || true

chown -R ha:ha /data/.local /data/.cache

echo "==> Setting up mock Home Assistant environment"
if ! ha core info >/dev/null 2>&1 && [ -f /tests/mock-ha.sh ]; then
    cp /tests/mock-ha.sh /usr/bin/ha
    chmod +x /usr/bin/ha
    echo "    Installed mock ha CLI"
fi

echo "==> Starting sshd on port 22"
exec /usr/sbin/sshd -D -e
