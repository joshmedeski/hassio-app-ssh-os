# Contributing

## Prerequisites

Install the following on your development machine (macOS):

```bash
brew install just docker sshpass mosh
```

| Tool | Purpose |
|------|---------|
| [Docker](https://www.docker.com/) | Builds and runs the add-on container |
| [just](https://github.com/casey/just) | Task runner for build, run, test, and connect commands |
| [sshpass](https://sourceforge.net/projects/sshpass/) | Passes the test password automatically to SSH/mosh |
| [mosh](https://mosh.org/) | Tests mosh connectivity to the container |

## Development workflow

The `justfile` drives all development tasks:

```bash
just build   # Build the Docker image
just run     # Build and start the container
just ssh     # Connect via SSH (password: testpassword)
just mosh    # Connect via mosh (password: testpassword)
just test    # Run the test suite
just logs    # Tail container logs
just stop    # Stop and remove the container
```

A typical cycle:

1. Make your changes
2. `just run` to rebuild and start the container
3. `just ssh` or `just mosh` to verify interactively
4. `just test` to run automated tests
5. `just stop` when done

## Shipped packages

The Dockerfile installs these packages on Alpine 3.21:

| Package | Version | Purpose |
|---------|---------|---------|
| openssh | ~9.9 | SSH server |
| tmux | ~3.5a | Terminal multiplexer |
| fish | ~3.7.1 | Default shell |
| neovim | ~0.11.7 | Editor (from Alpine edge for built-in LSP) |
| git | ~2.47 | Version control |
| curl | ~8.14 | HTTP client |
| ripgrep | ~14.1 | Fast content search |
| fd | ~10.2 | Fast file search |
| fzf | ~0.56 | Fuzzy finder |
| nodejs | ~22.15 | Runtime for HA language server |
| python3 | ~3.12 | Scripting |
| mosh-server | latest | Mobile shell server |
| sqlite | latest | Database CLI |

Additional tools installed from GitHub releases:

| Tool | Purpose |
|------|---------|
| [opencode](https://github.com/sst/opencode) | Terminal AI coding agent |
| [sesh](https://github.com/joshmedeski/sesh) | Smart tmux session manager |
| [starship](https://starship.rs/) | Cross-shell prompt |
| [Home Assistant LSP](https://github.com/keesschollaart81/vscode-home-assistant) | YAML autocompletion for HA configs |

Versions are pinned as `ARG` values at the top of the Dockerfile.

## Config architecture

Default configs live in `rootfs/root/` and are copied into the image at build time. The init scripts in `rootfs/etc/cont-init.d/` handle symlinking and persistence at runtime.

### Config override system

The init scripts follow this pattern:

1. Check if a user override exists in `/data/`
2. If yes, symlink it into place
3. If no, use the shipped default from the image

This lets most users get automatic config updates with new releases while giving power users full control.

### Persistent data paths

Plugin data and state persist in `/data/` across add-on restarts:

| Tool | Config path | Data path |
|------|-------------|-----------|
| tmux | `/data/.config/tmux/tmux.conf` | `/data/.config/tmux/plugins/` |
| Neovim | `/data/.config/nvim/` (override only) | `/data/.local/share/nvim/`, `/data/.local/state/nvim/`, `/data/.cache/nvim/` |
| SSH | -- | `/data/.ssh/` |

### Init script order

| Script | Purpose |
|--------|---------|
| `keygen.sh` | Generates SSH host keys if missing |
| `ssh.sh` | Configures SSH auth from add-on options |
| `tmux.sh` | Sets up tpm-redux and symlinks tmux config |
| `neovim.sh` | Symlinks persistent dirs and installs lazy.nvim plugins |

### Shipped tool configs

| File | Tool | Notes |
|------|------|-------|
| `rootfs/root/.tmux.conf` | tmux | `C-a` prefix, vim nav, sesh integration, catppuccin status |
| `rootfs/root/.config/nvim/init.lua` | Neovim | lazy.nvim, telescope, treesitter, oil, blink.cmp, catppuccin |
| `rootfs/root/.config/nvim/lsp/homeassistant.lua` | Neovim LSP | HA language server config |
| `rootfs/root/.config/fish/config.fish` | fish | Starship init, auto-attach to tmux |
| `rootfs/root/.config/sesh/sesh.toml` | sesh | Pre-configured Home Assistant session |
| `rootfs/root/.config/starship.toml` | starship | Minimal prompt, most modules disabled |
| `rootfs/root/.config/opencode/opencode.json` | opencode | Permissive defaults |
| `rootfs/root/.config/opencode/skills/home-assistant/SKILL.md` | opencode | HA editing skill |
| `rootfs/root/.config/opencode/plugins/ha-validate.js` | opencode | Config validation plugin |
