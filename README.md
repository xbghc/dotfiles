# dotfiles

Managed by [chezmoi](https://chezmoi.io).

## New machine
```sh
chezmoi init --apply xbghc
```
On Windows a junction `%LOCALAPPDATA%\nvim` → `~/.config/nvim` is created automatically (move the directory away first if it already exists).

## VSCode
The nvim config doubles as the config for the [vscode-neovim](https://github.com/vscode-neovim/vscode-neovim) extension: under VSCode only the editing plugins load, and the LazyVim keys are mapped to VSCode commands (`lua/config/vscode.lua`, `lua/plugins/vscode.lua`). After changing it, run `Neovim: Restart Extension`.

The extensions listed in `.chezmoidata/vscode.toml` are installed on `chezmoi apply` when the `code` CLI is available (missing ones only; nothing is uninstalled, so each machine can have more). Among them [nvim-marks](https://github.com/xbghc/vscode-nvim-marks), which shows the nvim marks in the gutter; `<leader>sm` lists them.

## Karabiner-Elements (macOS)
Windows-style shortcuts on macOS, so both OSes share one muscle memory: Ctrl+C/V/X/Z/A/S/F/T/W/…, Home/End, Ctrl+arrows, Ctrl+Backspace, Alt+Tab, Alt+F4, Ctrl+Shift+C/V in terminals. Terminals, IDEs (VSCode included), VMs and remote desktops are excepted, so Ctrl keys still reach tmux/nvim there.

`~/.config/karabiner/karabiner.json` stays owned by Karabiner-Elements; chezmoi only merges the rules into every profile, prefixed `[chezmoi]` (`dot_config/karabiner/modify_karabiner.json`, which also lists the skipped rules). The rules are vendored from [rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode) at `c5cdcb9`; to update:
```sh
curl -fsSL -o .vendor/karabiner-windows-mode/windows_shortcuts.json https://raw.githubusercontent.com/rux616/karabiner-windows-mode/main/json/windows_shortcuts.json
```

## Daily use
- After editing: `chezmoi re-add` (nvim's lazy-lock.json is not synced; each machine keeps its own) → `chezmoi cd` → git commit/push
- Pull updates: `chezmoi update`

## Codex CLI

`dot_codex/modify_config.toml` merges shared preferences into `~/.codex/config.toml`:

- Model: `gpt-6-astra`, reasoning effort: `xhigh`.
- Workspace-write sandbox with automatic approval review; live web search.
- Catppuccin Latte theme; model + reasoning, remaining context, and weekly limit in the status line.
- Terminal notifications disabled. Resume directory and onboarding tooltips use Codex defaults.

Project trust, integrations, and generated UI state remain local to each machine. Credentials,
session history, and other files under `~/.codex` are not managed.

Edit the modify template to change shared preferences, then apply only this file:

```sh
chezmoi apply ~/.codex/config.toml
```

As with the Claude Code modify template, `chezmoi re-add` does not capture shared preference
changes made in the app; update the template instead.
