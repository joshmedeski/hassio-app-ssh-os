# Home Assistant Add-on: SSH OS

An opinionated terminal environment for working with Home Assistant. SSH in and land in a ready-to-go tmux + Neovim + opencode environment pointed at your Home Assistant config.

## Features

- **SSH & Mosh** -- remote access with reliable mobile connections
- **tmux** with sesh for smart session management and fzf-powered session switching
- **Neovim 0.11+** with lazy.nvim, telescope, treesitter, catppuccin, oil, blink.cmp, and built-in LSP
- **Home Assistant LSP** -- autocompletion and validation for HA YAML configs out of the box
- **opencode** -- terminal AI coding agent with a Home Assistant skill for editing automations, scripts, and dashboards
- **fish shell** with starship prompt
- **ripgrep, fd, fzf** -- fast file and content searching
- **git, curl, Node.js, Python 3** -- everything you need to work on custom components and scripts
- **Auto-attaches to tmux** on login with a pre-configured Home Assistant session
- **Persistent plugin state** -- tmux and Neovim plugins survive add-on restarts
- **Overridable configs** -- use the shipped defaults or drop your own into `/data/` to fully own your setup

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the **SSH OS** add-on
3. Add your SSH public keys in the add-on configuration
4. Set the SSH port in the network settings
5. Start the add-on

See [DOCS.md](DOCS.md) for detailed configuration options.
