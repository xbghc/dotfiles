# dotfiles

Managed by [chezmoi](https://chezmoi.io).

## New machine
```sh
chezmoi init --apply xbghc
```
On Windows a junction `%LOCALAPPDATA%\nvim` → `~/.config/nvim` is created automatically (move the directory away first if it already exists).

## VSCode
The nvim config doubles as the config for the [vscode-neovim](https://github.com/vscode-neovim/vscode-neovim) extension: under VSCode only the editing plugins load, and the LazyVim keys are mapped to VSCode commands (`lua/config/vscode.lua`, `lua/plugins/vscode.lua`). After changing it, run `Neovim: Restart Extension`.

## Karabiner-Elements (macOS)
`~/.config/karabiner/karabiner.json` stays owned by Karabiner-Elements; chezmoi only merges the shared rules into every profile (`dot_config/karabiner/modify_karabiner.json`):
- Ctrl+C copies (⌘C) in GUI apps; terminals and VSCode are excluded so it still interrupts there.

## Daily use
- After editing: `chezmoi re-add` (nvim's lazy-lock.json is not synced; each machine keeps its own) → `chezmoi cd` → git commit/push
- Pull updates: `chezmoi update`
