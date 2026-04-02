#!/usr/bin/with-contenv bashio
# Configure SSH authentication

SSH_DIR=/data/.ssh
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Write authorized keys from config
if bashio::config.has_value 'authorized_keys'; then
    : > "${AUTHORIZED_KEYS}"
    while read -r key; do
        echo "${key}" >> "${AUTHORIZED_KEYS}"
    done <<< "$(bashio::config 'authorized_keys')"
    chmod 600 "${AUTHORIZED_KEYS}"
    bashio::log.info "Configured $(wc -l < "${AUTHORIZED_KEYS}") authorized key(s)"
fi

# Set password if provided
if bashio::config.has_value 'password'; then
    PASSWORD=$(bashio::config 'password')
    echo "root:${PASSWORD}" | chpasswd
    passwd -u root 2>/dev/null || true
    bashio::log.info "Password authentication configured"
else
    # Generate random password (effectively disabling password auth if no keys either)
    PASSWORD=$(head -c 48 /dev/urandom | base64)
    echo "root:${PASSWORD}" | chpasswd
fi

# Configure sshd
sed -i \
    -e 's|#PermitRootLogin.*|PermitRootLogin yes|' \
    -e 's|#PasswordAuthentication.*|PasswordAuthentication yes|' \
    -e 's|#AuthorizedKeysFile.*|AuthorizedKeysFile /data/.ssh/authorized_keys|' \
    /etc/ssh/sshd_config

# Warn if port is exposed but no auth is configured
if bashio::addon.port 22 && ! bashio::config.has_value 'authorized_keys' && ! bashio::config.has_value 'password'; then
    bashio::log.warning "SSH port is exposed but no authorized_keys or password is set!"
fi
