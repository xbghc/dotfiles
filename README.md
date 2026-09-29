# dotfiles

Managed by [chezmoi](https://chezmoi.io).

## New machine
```sh
chezmoi init --apply xbghc
```
On Windows a junction `%LOCALAPPDATA%\nvim` → `~/.config/nvim` is created automatically (move the directory away first if it already exists).

## Daily use
- After editing: `chezmoi re-add` (nvim's lazy-lock.json is not synced; each machine keeps its own) → `chezmoi cd` → git commit/push
- Pull updates: `chezmoi update`
