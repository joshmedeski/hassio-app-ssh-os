# Changelog

## 0.2.4

- Add changelog, bump version

## 0.2.3

- Fix: set ha user home to /data so dotfiles resolve naturally

## 0.2.2

- Fix: debug SSH password auth, unlock account after password set

## 0.2.1

- Fix: use regular user for password auth, resolve git safe.directory errors

## 0.2.0

- Configure SSH for ha user, disable root login
- Create ha user with sudo, remove root shell modification
- Add defaults.sh to seed dotfiles from skel on first boot
- Add XDG environment variables to fish config
- Move dotfiles from rootfs/root to rootfs/etc/skel
- Fix: expand mosh port range and add logo for addon store visibility

## 0.1.0

- Initial Home Assistant SSH add-on
- Auto-start tmux session on SSH login
- Add Home Assistant CLI to SSH environment
- Add sesh config with Home Assistant session
- Configure neovim with built-in LSP and blink.cmp
- Add Home Assistant language server and upgrade neovim to 0.11
- Add mosh support
- Add sqlite
- Add opencode with Home Assistant skill and config validation plugin
- Restructure as HA addon repository with install badge
