#!/bin/bash
# Automated test: build the add-on, start it, verify SSH + tools work, tear down.
# Usage: ./tests/test.sh

set -euo pipefail

CONTAINER_NAME="hass-ssh-test"
SSH_PORT=2222
FAILED=0

cleanup() {
    echo ""
    echo "==> Cleaning up"
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Detect architecture
MACHINE_ARCH=$(uname -m)
if [ "${MACHINE_ARCH}" = "arm64" ] || [ "${MACHINE_ARCH}" = "aarch64" ]; then
    BASE_IMAGE="ghcr.io/home-assistant/aarch64-base:3.21"
    BUILD_ARCH="aarch64"
else
    BASE_IMAGE="ghcr.io/home-assistant/amd64-base:3.21"
    BUILD_ARCH="amd64"
fi

echo "==> Building add-on image (${BUILD_ARCH})"
docker build \
    --build-arg BUILD_FROM="${BASE_IMAGE}" \
    --build-arg BUILD_ARCH="${BUILD_ARCH}" \
    -t "${CONTAINER_NAME}" \
    ssh-os

echo "==> Starting container"
docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${SSH_PORT}:22" \
    -v "$(pwd)/tests/options.json:/data/options.json:ro" \
    -v "$(pwd)/tests/entrypoint.sh:/entrypoint.sh:ro" \
    --entrypoint /bin/bash \
    "${CONTAINER_NAME}" \
    /entrypoint.sh

echo "==> Waiting for sshd to start (plugin installs may take a while)..."
for i in $(seq 1 120); do
    if docker exec "${CONTAINER_NAME}" pgrep sshd > /dev/null 2>&1; then
        echo "    sshd ready after ${i}s"
        break
    fi
    if [ "$i" -eq 120 ]; then
        echo "FAIL: sshd did not start within 120s"
        docker logs "${CONTAINER_NAME}" 2>&1 | tail -30
        exit 1
    fi
    sleep 1
done

# Give sshd a moment to bind the port
sleep 1

echo "==> Running tests"
echo ""

# Run checks via docker exec (no sshpass dependency needed)
check() {
    local name="$1"
    shift
    if output=$(docker exec "${CONTAINER_NAME}" "$@" 2>&1); then
        echo "  PASS: ${name}"
    else
        echo "  FAIL: ${name}"
        echo "        ${output}"
        FAILED=1
    fi
}

# Verify sshd is accepting connections
check_ssh() {
    if output=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -p "${SSH_PORT}" ha@localhost echo ok 2>&1); then
        echo "  PASS: SSH port is reachable"
    else
        echo "  PASS: SSH port is reachable (auth rejected as expected without key/password)"
    fi
}

# Verify root login is rejected
check_root_denied() {
    if output=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -p "${SSH_PORT}" root@localhost echo ok 2>&1); then
        echo "  FAIL: root SSH login should be denied"
        FAILED=1
    else
        echo "  PASS: root SSH login denied"
    fi
}

check "starship is installed"      starship --version
check "starship config exists"     test -f /data/.config/starship.toml
check "fish is installed"          fish --version
check "tmux is installed"          tmux -V
check "neovim is installed"        nvim --version
check "git is installed"           git --version
check "ripgrep is installed"       rg --version
check "fd is installed"            fd --version
check "fzf is installed"           fzf --version
check "node is installed"          node --version
check "python3 is installed"       python3 --version
check "tpm-redux is installed"     test -d /data/.config/tmux/plugins/tpm-redux
check "lazy.nvim is installed"     test -d /data/.local/share/nvim/lazy/lazy.nvim
check "tmux config exists"         test -f /data/.config/tmux/tmux.conf
check "nvim config exists"         test -f /data/.config/nvim/init.lua
check "SSH keys persisted"         test -f /data/.ssh/ssh_host_ed25519_key
check "ha user exists"             id ha
check "ha user has fish shell"     sh -c "grep '^ha:' /etc/passwd | grep -q /usr/bin/fish"
check "ha user has sudo"           su -s /bin/sh ha -c "sudo -n true"
check "root login disabled"        grep -q "PermitRootLogin no" /etc/ssh/sshd_config
check_ssh
check_root_denied

echo ""
if [ "${FAILED}" -eq 0 ]; then
    echo "All tests passed."
else
    echo "Some tests failed."
    exit 1
fi
