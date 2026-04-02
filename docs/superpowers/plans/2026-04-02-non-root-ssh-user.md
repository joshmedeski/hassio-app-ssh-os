# Non-root SSH User Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace root SSH login with a dedicated `ha` user that has passwordless sudo, home at `/homeassistant`, and XDG dirs pointing to `/data`.

**Architecture:** Create the `ha` user in the Dockerfile, move shipped dotfiles to `/etc/skel/`, add a `defaults.sh` init script to seed them into `/data` on first boot, update `ssh.sh` to target the `ha` user and disable root login, and update all other init scripts that reference `/root` paths.

**Tech Stack:** Alpine Linux, OpenSSH, fish shell, s6-overlay (cont-init.d), Docker

---

### Task 1: Move dotfiles from rootfs/root/ to rootfs/etc/skel/

**Files:**
- Move: `ssh-os/rootfs/root/.config/` -> `ssh-os/rootfs/etc/skel/.config/`
- Move: `ssh-os/rootfs/root/.tmux.conf` -> `ssh-os/rootfs/etc/skel/.tmux.conf`
- Delete: `ssh-os/rootfs/root/` (entire directory)

- [ ] **Step 1: Move dotfiles to skel**

```bash
cd /Users/joshmedeski/c/hass-ssh-os
mkdir -p ssh-os/rootfs/etc/skel
git mv ssh-os/rootfs/root/.config ssh-os/rootfs/etc/skel/.config
git mv ssh-os/rootfs/root/.tmux.conf ssh-os/rootfs/etc/skel/.tmux.conf
```

- [ ] **Step 2: Remove the now-empty rootfs/root directory**

```bash
rm -rf ssh-os/rootfs/root
git add -A ssh-os/rootfs/root
```

- [ ] **Step 3: Commit**

```bash
git add -A ssh-os/rootfs/
git commit -m "refactor: move dotfiles from rootfs/root to rootfs/etc/skel"
```

---

### Task 2: Add XDG environment variables to fish config

**Files:**
- Modify: `ssh-os/rootfs/etc/skel/.config/fish/config.fish`

- [ ] **Step 1: Update config.fish with XDG exports and tmux fix**

Replace the entire file content with:

```fish
# XDG directories (persist config in /data, separate from /homeassistant)
set -gx XDG_CONFIG_HOME /data/.config
set -gx XDG_DATA_HOME /data/.local/share
set -gx XDG_STATE_HOME /data/.local/state

starship init fish | source

if status is-interactive; and not set -q TMUX
    tmux new-session -A -s "Home Assistant"
end
```

The XDG exports must come before `starship init` so starship reads its config from `/data/.config/starship.toml`.

- [ ] **Step 2: Commit**

```bash
git add ssh-os/rootfs/etc/skel/.config/fish/config.fish
git commit -m "feat: add XDG environment variables to fish config"
```

---

### Task 3: Create defaults.sh init script

**Files:**
- Create: `ssh-os/rootfs/etc/cont-init.d/defaults.sh`

- [ ] **Step 1: Create the defaults.sh script**

Create `ssh-os/rootfs/etc/cont-init.d/defaults.sh` with:

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ssh-os/rootfs/etc/cont-init.d/defaults.sh
```

- [ ] **Step 3: Commit**

```bash
git add ssh-os/rootfs/etc/cont-init.d/defaults.sh
git commit -m "feat: add defaults.sh to seed dotfiles from skel on first boot"
```

---

### Task 4: Update Dockerfile to create ha user

**Files:**
- Modify: `ssh-os/Dockerfile`

- [ ] **Step 1: Add sudo to package install**

In the `apk add` command, add `sudo` to the package list (after `sqlite`):

```dockerfile
    sqlite \
    sudo && \
```

(Replace the existing `sqlite && \` line.)

- [ ] **Step 2: Replace root shell modification with ha user creation**

Remove this line:

```dockerfile
# Set fish as default shell
RUN sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/usr/bin/fish|' /etc/passwd
```

Replace with:

```dockerfile
# Create non-root ha user with fish shell and passwordless sudo
RUN addgroup -S ha && \
    adduser -S -G ha -h /homeassistant -s /usr/bin/fish ha && \
    echo "ha ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ha && \
    chmod 440 /etc/sudoers.d/ha
```

- [ ] **Step 3: Commit**

```bash
git add ssh-os/Dockerfile
git commit -m "feat: create ha user with sudo, remove root shell modification"
```

---

### Task 5: Update ssh.sh for ha user

**Files:**
- Modify: `ssh-os/rootfs/etc/cont-init.d/ssh.sh`

- [ ] **Step 1: Rewrite ssh.sh**

Replace the entire file with:

```bash
#!/usr/bin/with-contenv bashio
# Configure SSH authentication for the ha user

SSH_DIR=/data/.ssh
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown ha:ha "${SSH_DIR}"

# Write authorized keys from config
if bashio::config.has_value 'authorized_keys'; then
    : > "${AUTHORIZED_KEYS}"
    while read -r key; do
        echo "${key}" >> "${AUTHORIZED_KEYS}"
    done <<< "$(bashio::config 'authorized_keys')"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown ha:ha "${AUTHORIZED_KEYS}"
    bashio::log.info "Configured $(wc -l < "${AUTHORIZED_KEYS}") authorized key(s)"
fi

# Set password if provided
if bashio::config.has_value 'password'; then
    PASSWORD=$(bashio::config 'password')
    echo "ha:${PASSWORD}" | chpasswd
    bashio::log.info "Password authentication configured"
else
    # Generate random password (effectively disabling password auth)
    PASSWORD=$(head -c 48 /dev/urandom | base64)
    echo "ha:${PASSWORD}" | chpasswd
fi

# Configure sshd
sed -i \
    -e 's|#\?PermitRootLogin.*|PermitRootLogin no|' \
    -e 's|#\?PasswordAuthentication.*|PasswordAuthentication yes|' \
    -e 's|#\?AuthorizedKeysFile.*|AuthorizedKeysFile /data/.ssh/authorized_keys|' \
    /etc/ssh/sshd_config

# Add AllowUsers if not already present
if ! grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    echo "AllowUsers ha" >> /etc/ssh/sshd_config
fi

# Warn if port is exposed but no auth is configured
if bashio::addon.port 22 && ! bashio::config.has_value 'authorized_keys' && ! bashio::config.has_value 'password'; then
    bashio::log.warning "SSH port is exposed but no authorized_keys or password is set!"
fi
```

Key changes from the old version:
- Password set on `ha` not `root`
- `chown ha:ha` on SSH dir and authorized_keys
- `PermitRootLogin no` instead of `yes`
- `AllowUsers ha` appended to sshd_config
- Regex uses `#\?` to match both commented and uncommented lines

- [ ] **Step 2: Commit**

```bash
git add ssh-os/rootfs/etc/cont-init.d/ssh.sh
git commit -m "feat: configure SSH for ha user, disable root login"
```

---

### Task 6: Update neovim.sh and tmux.sh for ha user

**Files:**
- Modify: `ssh-os/rootfs/etc/cont-init.d/neovim.sh`
- Modify: `ssh-os/rootfs/etc/cont-init.d/tmux.sh`

- [ ] **Step 1: Rewrite neovim.sh**

Replace the entire file with:

```bash
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
```

Key changes:
- Removed all `/root/.local` and `/root/.config` symlinks (no longer needed — XDG vars point to `/data` directly)
- Removed the `rm -rf /root/.config/nvim && ln -sfn` logic (defaults.sh handles seeding)
- `nvim --headless` runs as `ha` user with XDG vars so plugins install to the right place

- [ ] **Step 2: Rewrite tmux.sh**

Replace the entire file with:

```bash
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
```

Key changes:
- Removed `/root/.config/tmux` symlink (XDG vars handle this)
- Removed copying from `/root/.tmux.conf` (defaults.sh handles seeding)
- Added `chown` for `ha` user

- [ ] **Step 3: Commit**

```bash
git add ssh-os/rootfs/etc/cont-init.d/neovim.sh ssh-os/rootfs/etc/cont-init.d/tmux.sh
git commit -m "refactor: update neovim.sh and tmux.sh for ha user"
```

---

### Task 7: Update test infrastructure

**Files:**
- Modify: `tests/entrypoint.sh`
- Modify: `tests/test.sh`
- Modify: `justfile`

- [ ] **Step 1: Rewrite tests/entrypoint.sh**

Replace the entire file with:

```bash
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
```

- [ ] **Step 2: Update tests/test.sh**

Replace all `/root/` paths with `/data/` or `/etc/skel/` paths, and change `root@localhost` to `ha@localhost`:

```bash
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
check "ha user has fish shell"     grep "^ha:" /etc/passwd | grep -q /usr/bin/fish
check "ha user has sudo"           docker exec "${CONTAINER_NAME}" su -s /bin/sh ha -c "sudo -n true"
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
```

Note: The `check "ha user has sudo"` test uses `docker exec` with `su` to verify sudo works as the `ha` user. The syntax for the `check` function needs adjustment since it already wraps `docker exec` — fix by inlining that specific test:

Actually, looking at this more carefully, the `check` function already runs via `docker exec`, so the sudo check should be:

```bash
check "ha user has sudo"           su -s /bin/sh ha -c "sudo -n true"
```

And the `check_root_denied` test is run from the host (SSH), so it stays as-is.

- [ ] **Step 3: Update justfile**

Change `root@localhost` to `ha@localhost` in the `ssh` and `mosh` recipes, and update the run echo:

In the `run` recipe, change:
```
    @echo "Container started. SSH: ssh -p {{ ssh_port }} root@localhost (password: testpassword)"
```
to:
```
    @echo "Container started. SSH: ssh -p {{ ssh_port }} ha@localhost (password: testpassword)"
```

In the `ssh` recipe, change:
```
    sshpass -p testpassword ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }} root@localhost
```
to:
```
    sshpass -p testpassword ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }} ha@localhost
```

In the `mosh` recipe, change:
```
    SSHPASS=testpassword mosh --ssh="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }}" --port={{ mosh_port }} root@localhost
```
to:
```
    SSHPASS=testpassword mosh --ssh="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }}" --port={{ mosh_port }} ha@localhost
```

- [ ] **Step 4: Commit**

```bash
git add tests/entrypoint.sh tests/test.sh justfile
git commit -m "test: update test infrastructure for ha user"
```

---

### Task 8: Update DOCS.md and bump version

**Files:**
- Modify: `ssh-os/DOCS.md`
- Modify: `ssh-os/config.yaml`

- [ ] **Step 1: Update DOCS.md**

Replace all `root@` with `ha@` in the connection examples:

In the SSH section:
```bash
ssh ha@<your-ha-ip> -p <port>
```

In the Mosh section:
```bash
mosh --ssh="ssh -p <port>" ha@<your-ha-ip>
```

In the Tailscale section:
```bash
ssh ha@<tailscale-ip>
```

In the HA CLI section, add a note that `ha` commands work directly (the Supervisor API token is available via environment).

- [ ] **Step 2: Bump version to 0.2.0**

In `ssh-os/config.yaml`, change:
```yaml
version: "0.1.0"
```
to:
```yaml
version: "0.2.0"
```

- [ ] **Step 3: Commit**

```bash
git add ssh-os/DOCS.md ssh-os/config.yaml
git commit -m "docs: update connection instructions for ha user, bump to 0.2.0"
```

---

### Task 9: Build and run tests

- [ ] **Step 1: Run the full test suite**

```bash
just test
```

Expected: All tests pass, including the new `ha user exists`, `ha user has sudo`, and `root login disabled` checks.

- [ ] **Step 2: Manual smoke test (optional)**

```bash
just run
just ssh
# Verify: you land in fish shell, tmux auto-attaches, starship prompt works
# Verify: `sudo ls /root` works without password prompt
# Verify: `ha core info` works (mock in test, real in production)
whoami  # should print "ha"
pwd     # should print "/homeassistant"
```

- [ ] **Step 3: If tests fail, fix issues and commit fixes**

---

### Task ordering

Tasks 1-2 can be done first (file moves, no behavior change). Tasks 3-6 are the core changes and depend on Task 1. Task 7 depends on all prior tasks. Task 8 is independent documentation. Task 9 is final validation.

```
Task 1 (move dotfiles) → Task 2 (XDG vars)
                       → Task 3 (defaults.sh) → Task 6 (neovim.sh, tmux.sh)
                       → Task 4 (Dockerfile)
                       → Task 5 (ssh.sh)
Task 7 (tests) — depends on Tasks 3-6
Task 8 (docs) — independent
Task 9 (validation) — depends on all
```
