#!/usr/bin/with-contenv bashio
# Generate or restore SSH host keys

SSH_DIR=/data/.ssh

if [ ! -d "${SSH_DIR}" ]; then
    mkdir -p "${SSH_DIR}"
fi

# Restore host keys if they exist, otherwise generate new ones
if [ -f "${SSH_DIR}/ssh_host_ed25519_key" ]; then
    bashio::log.info "Restoring SSH host keys..."
    cp "${SSH_DIR}"/ssh_host_* /etc/ssh/
else
    bashio::log.info "Generating new SSH host keys..."
    ssh-keygen -A
    cp /etc/ssh/ssh_host_* "${SSH_DIR}"/
fi
