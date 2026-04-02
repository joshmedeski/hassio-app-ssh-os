# Configuration

## Add-on options

Configure the add-on from the Home Assistant UI under **Settings > Add-ons > SSH OS > Configuration**.

```yaml
authorized_keys:
  - "ssh-ed25519 AAAA... user@host"
password: ""
```

| Option             | Required | Description                                                    |
| ------------------ | -------- | -------------------------------------------------------------- |
| `authorized_keys`  | Yes      | List of SSH public keys allowed to connect                     |
| `password`         | No       | Optional password for the root user. Leave empty to disable    |

At least one of `authorized_keys` or `password` must be set, otherwise the add-on will log a warning and SSH access will be effectively locked out.

## Network ports

Configure ports in the add-on's **Network** section.

| Port              | Protocol | Purpose          |
| ----------------- | -------- | ---------------- |
| `22`              | TCP      | SSH              |
| `60000-60010`     | UDP      | Mosh             |

Set the SSH port to a value (e.g. `22` or `2222`). The Mosh port range is optional and only needed if you use Mosh.

## Connecting

### SSH

```bash
ssh ha@<your-ha-ip> -p <port>
```

### Mosh

[Mosh](https://mosh.org/) provides a resilient connection that handles roaming and intermittent connectivity.

```bash
mosh --ssh="ssh -p <port>" ha@<your-ha-ip>
```

### Tailscale (recommended)

For secure remote access without exposing ports, use the [Tailscale add-on](https://github.com/hassio-addons/addon-tailscale) alongside this add-on:

```bash
ssh ha@<tailscale-ip>
```

## What happens on login

1. Fish shell starts and attaches to (or creates) a tmux session named **Home Assistant**
2. Sesh pre-configures a session pointing at `/homeassistant` with Neovim as the startup command
3. Starship provides the prompt

This means you land in tmux with your Home Assistant config directory ready to edit on every connection.

## Customizing configs

Default configs ship with each release. To override, place your own files in `/data/`:

| Tool   | Override path                  |
| ------ | ------------------------------ |
| tmux   | `/data/.config/tmux/tmux.conf` |
| Neovim | `/data/.config/nvim/`          |

When an override exists, it is used instead of the shipped default. Plugin data persists in `/data/` across restarts regardless of which config is active.

## Mapped directories

The add-on has read/write access to the following Home Assistant directories:

| Mount path          | Purpose                        |
| ------------------- | ------------------------------ |
| `/homeassistant`    | Home Assistant configuration   |
| `/ssl`              | SSL certificates               |
| `/share`            | Shared data between add-ons    |
| `/media`            | Media files                    |
| `/backup`           | Backups                        |

## Home Assistant CLI

The `ha` command is available inside the container:

```bash
ha core check       # Validate configuration
ha core restart     # Restart Home Assistant
ha core info        # Show version and status
ha addons list      # List installed add-ons
ha host info        # Show host system info
```

Always run `ha core check` after editing configuration files before restarting.
