# Home Assistant Add-on: SSH Workflow

A Home Assistant OS add-on that provides a full terminal workflow via SSH with tmux, neovim, fish shell, and modern CLI tools.

## What's included

- **OpenSSH** server for remote access (with **mosh** support for mobile/unreliable connections)
- **tmux** with TPM (Tmux Plugin Manager)
- **Neovim** with lazy.nvim and a curated plugin set (telescope, treesitter, LSP, catppuccin)
- **fish** shell
- **ripgrep**, **fd**, **fzf** for fast searching
- **git**, **curl**, **nodejs**, **python3**

All plugin state and configuration persists across add-on restarts.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the "SSH Workflow" add-on
3. Configure your SSH authorized keys or password in the add-on options
4. Set the SSH port (e.g., 22) in the network configuration
5. (Optional) Set the mosh UDP port range (e.g., 60000-60010) in the network configuration
6. Start the add-on

## Configuration

```yaml
authorized_keys:
  - "ssh-ed25519 AAAA... user@host"
password: ""  # optional, leave empty to use key-based auth only
```

### Options

| Option | Description |
|--------|-------------|
| `authorized_keys` | List of SSH public keys for authentication |
| `password` | Optional password for root user (leave empty to disable) |

## Connecting

### SSH

```bash
ssh root@<your-ha-ip> -p <configured-port>
```

### Mosh

[Mosh](https://mosh.org/) (mobile shell) provides a more resilient remote connection that handles roaming, intermittent connectivity, and high latency. Install mosh on your Mac and connect:

```bash
brew install mosh
mosh --ssh="ssh -p <configured-port>" root@<your-ha-ip>
```

If you changed the UDP port range from the default, specify it with `--port`:

```bash
mosh --ssh="ssh -p <configured-port>" --port=60000 root@<your-ha-ip>
```

> **Note:** Mosh requires both the SSH port (TCP) and the mosh UDP port range to be configured in the add-on's network settings.

### Recommended: Tailscale

For secure remote access without exposing ports to the internet, use the [Tailscale add-on](https://github.com/hassio-addons/addon-tailscale) alongside this add-on. Once both are running, connect via your Tailscale IP:

```bash
ssh root@<tailscale-ip>
```

## Customization

### How config updates work

Default configs for tmux and neovim are **shipped with each release**. When the add-on updates, you automatically get the latest configs -- new plugins, keybindings, and settings.

To use your own configs instead, drop override files into `/data/`:

| Tool | Override path | What it replaces |
|------|--------------|-----------------|
| tmux | `/data/.tmux.conf` | The shipped `.tmux.conf` |
| neovim | `/data/.config/nvim/` | The shipped `nvim/` config directory |

When an override exists, the init scripts symlink it in place of the default. When it doesn't, the shipped config from the image is used. This means:

- **Most users**: do nothing, get updates automatically with each release
- **Custom users**: place configs in `/data/`, fully own their setup, updates won't overwrite them

Plugin data (TPM plugins, lazy.nvim packages) always persists in `/data/` regardless of which config is active.

### Tmux

The default config uses `C-a` as the prefix key with vim-style navigation. Plugins are managed by TPM and persist in `/data/.tmux/`.

### Neovim

The default config includes catppuccin, telescope, treesitter, oil, gitsigns, lualine, nvim-cmp, and which-key. Plugins are managed by lazy.nvim and persist in `/data/.local/share/nvim/`.

### Adding packages

To install additional Alpine packages, use `apk add <package>` inside the container. Note that manually installed packages won't persist across restarts -- add them to the Dockerfile for persistence.
