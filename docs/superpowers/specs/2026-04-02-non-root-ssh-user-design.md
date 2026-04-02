# Non-root SSH User Design

## Overview

Replace root SSH login with a dedicated `ha` user. Home directory is `/homeassistant` for convenience (users land in the HA config directory), but XDG directories point to `/data` to keep dotfiles separate from HA config files. Root SSH login is fully disabled.

## User: `ha`

- **Username:** `ha` (hardcoded, not configurable)
- **Home directory:** `/homeassistant`
- **Shell:** `/usr/bin/fish`
- **Sudo:** passwordless (`NOPASSWD: ALL`)
- **UID/GID:** 0 is not used; create with a standard UID (e.g., 1000). File access to `/homeassistant` and other mapped volumes is handled by HA Supervisor running the container with appropriate permissions.

## Dockerfile Changes

- Create the `ha` user and group:
  ```dockerfile
  RUN addgroup -S ha && adduser -S -G ha -h /homeassistant -s /usr/bin/fish ha
  ```
- Install `sudo` package and configure passwordless sudo:
  ```dockerfile
  RUN apk add --no-cache sudo && \
      echo "ha ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ha && \
      chmod 440 /etc/sudoers.d/ha
  ```
- Remove the root shell modification (`sed` on `/etc/passwd` for root)
- Move shipped dotfiles from `rootfs/root/.config/` to `rootfs/etc/skel/.config/`
- Move `rootfs/root/.tmux.conf` to `rootfs/etc/skel/.tmux.conf`

## SSH Configuration (ssh.sh)

Update `ssh.sh` to configure for the `ha` user:

- Set password on `ha` (not root): `echo "ha:${PASSWORD}" | chpasswd`
- Set ownership of `/data/.ssh` and authorized_keys to `ha`
- `sshd_config` settings:
  - `PermitRootLogin no`
  - `AllowUsers ha`
  - `PasswordAuthentication yes` (when password is configured)
  - `AuthorizedKeysFile /data/.ssh/authorized_keys`

## XDG Environment

Set via fish config or a cont-init.d script so all tools (nvim, sesh, starship, opencode) use `/data` for persistent config:

| Variable           | Value               |
| ------------------ | ------------------- |
| `XDG_CONFIG_HOME`  | `/data/.config`     |
| `XDG_DATA_HOME`    | `/data/.local/share` |
| `XDG_STATE_HOME`   | `/data/.local/state` |

These are set in the fish config (`config.fish`) so they apply to every interactive session.

## Dotfile Default Seeding

A new `cont-init.d` script (`defaults.sh`) runs on startup:

1. Check if `/data/.config` exists
2. If not (first boot), copy shipped defaults from `/etc/skel/.config/` to `/data/.config/`
3. Similarly for `/data/.tmux.conf` from `/etc/skel/.tmux.conf`
4. Ensure ownership of `/data/.config`, `/data/.local`, `/data/.ssh` is set to `ha`

This replaces the current approach of dotfiles living in `/root/`.

## HA CLI Access

The `ha` binary communicates with the Supervisor API via HTTP using environment variables (`SUPERVISOR_TOKEN`), not unix permissions. It should work for the `ha` user without changes. If the `with-contenv` wrapper is needed, the `ha` user can invoke it via sudo or the env vars can be exported in the fish config.

## Config Schema (config.yaml)

No schema changes. `authorized_keys` and `password` remain as-is. The username is hardcoded to `ha` and not exposed as a config option.

## Files Changed

| File | Change |
| --- | --- |
| `ssh-os/Dockerfile` | Create `ha` user, install sudo, remove root shell change, move skel |
| `ssh-os/config.yaml` | Version bump to `0.2.0` |
| `ssh-os/rootfs/etc/cont-init.d/ssh.sh` | Target `ha` user, disable root login |
| `ssh-os/rootfs/etc/cont-init.d/defaults.sh` | New: seed dotfiles from skel to /data on first boot |
| `ssh-os/rootfs/etc/skel/.config/` | Moved from `rootfs/root/.config/` |
| `ssh-os/rootfs/etc/skel/.tmux.conf` | Moved from `rootfs/root/.tmux.conf` |
| `ssh-os/rootfs/root/` | Deleted |
| `ssh-os/rootfs/root/.config/fish/config.fish` | Moved to skel, add XDG exports |
| `ssh-os/DOCS.md` | Update connection instructions (`ha@` instead of `root@`) |

## Breaking Change

Users connecting as `root@` must switch to `ha@`. Document in DOCS.md and bump version to `0.2.0`.
