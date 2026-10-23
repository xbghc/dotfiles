# dotfiles

Managed by [chezmoi](https://chezmoi.io).

## New machine
```sh
chezmoi init --apply xbghc
```
On Windows a junction `%LOCALAPPDATA%\nvim` → `~/.config/nvim` is created automatically (move the directory away first if it already exists).

Claude Code (`~/.claude`) and Codex CLI (`~/.codex`) settings share one optional sync choice during initialization: both are enabled or both are skipped. The existing `[data]` key `syncClaude` controls both directories, preserving each machine's saved choice. Set `syncClaude = false` in the local chezmoi config to skip both; `true` enables both. Skipping leaves any existing local files in place.

## Packages

`.chezmoidata/packages.toml` lists tools to download and install automatically:
Windows uses WinGet package IDs; macOS uses Homebrew formula names. Both lists
initially contain `ffmpeg`. Install WinGet (App Installer) or Homebrew first if
the machine needs packages.

Following [chezmoi's package installation pattern](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/),
the scripts run before other changes on the first `chezmoi apply` and whenever
the platform's package list or installer script changes. They skip packages
already installed, including tools found on `PATH` via the optional `command`
field. Existing packages are not explicitly upgraded or removed; installing a
missing Homebrew formula can update its dependencies. A failed install is
retried on the next apply. Linux package installation is not configured.

To add a tool, add its entry to the appropriate list, for example:

```toml
# Inside packages.windows:
{ id = "BurntSushi.ripgrep.MSVC", command = "rg" },
# Inside packages.darwin:
{ id = "ripgrep", command = "rg" },
```

Then run `chezmoi apply`. On a new machine, `chezmoi init --apply xbghc` also
installs these packages. Windows installs run silently and accept package/source
agreements; an installer may still require administrator approval. Open a new
terminal after installing tools so it picks up any `PATH` changes.

## VSCode
The nvim config doubles as the config for the [vscode-neovim](https://github.com/vscode-neovim/vscode-neovim) extension: under VSCode only the editing plugins load, and the LazyVim keys are mapped to VSCode commands (`lua/config/vscode.lua`, `lua/plugins/vscode.lua`). After changing it, run `Neovim: Restart Extension`.

In VSCode normal mode, `/` opens VSCode's Find widget and `*` finds the next occurrence of the word under the cursor using VSCode's current search options. `n` / `N` move to the next / previous VSCode match. While the Find input is focused, use Enter / Shift+Enter to navigate, then Esc to return to the editor and continue with `n` / `N`. These mappings only apply inside VSCode; terminal Neovim retains its native search.

The extensions listed in `.chezmoidata/vscode.toml` are installed on `chezmoi apply` when the `code` CLI is available (missing ones only; nothing is uninstalled, so each machine can have more). Among them [nvim-marks](https://github.com/xbghc/vscode-nvim-marks), which shows the nvim marks in the gutter; `<leader>sm` lists them.

## Ghostty + zsh (macOS)
On every `chezmoi apply`, `modify_dot_zshrc` preserves the machine's existing `~/.zshrc` and appends Ghostty's shell integration if no uncommented `source` or `.` command already loads it. A missing `~/.zshrc` is created. The integration reports the working directory from zsh inside tmux; it only loads when `GHOSTTY_RESOURCES_DIR` is set and the integration file is readable.

Preview with `chezmoi diff ~/.zshrc`, then apply with `chezmoi apply ~/.zshrc`. Open a new zsh pane or run `source ~/.zshrc`; after the next prompt, check `tmux display-message -p '#{pane_path}'`. Other contents stay local to each machine, and `.zshrc` is ignored on other operating systems.

The tmux config declares `osc7` support for `xterm-ghostty` and enables `set-titles`, so tmux 3.3+ forwards the active pane's reported directory to Ghostty. After syncing this setting, run `tmux source-file ~/.tmux.conf`, detach, and reattach the session so terminal capabilities are refreshed. `tmux display-message -p '#{client_termfeatures}'` should then include `osc7`. Relative file links also require Ghostty 1.3+; click paths in the active pane, where the reported directory applies.

## Daily use
- After editing: `chezmoi re-add` (nvim's lazy-lock.json is not synced; each machine keeps its own) → `chezmoi cd` → git commit/push
- Pull updates: `chezmoi update`

## Codex CLI

`dot_codex/modify_config.toml` merges shared preferences into `~/.codex/config.toml`:

- Model: `gpt-6-astra`, reasoning effort: `max`.
- Context window: `500000` tokens. Auto-compaction uses the model default; applying removes manual overrides for `model_auto_compact_token_limit` ([reference](https://learn.chatgpt.com/docs/config-file/config-sample)).
- Workspace-write sandbox with automatic approval review; live web search.
- Catppuccin Latte theme; a compact, colored status line showing context capacity, percentage used, and the weekly limit.
- Terminal notifications disabled. Resume directory and onboarding tooltips use Codex defaults.

Project trust, other integrations, and generated UI state remain local to each machine.
Credentials, session history, and plugin runtime state are not managed.

The status line uses Codex's built-in fields and colors (`tui.status_line_use_colors`,
supported by Codex CLI 0.153.4). Its weekly-limit field shows remaining capacity;
Claude's custom icons, separators, usage colors, and reset countdowns cannot be configured
through Codex's status-line item list.
`context-window-size` adds the total context capacity next to `context-used`'s percentage.
Codex CLI 0.153.4 has no built-in current-context token-count item for Claude's
`used / capacity` display; `used-tokens` is cumulative session consumption and is deliberately omitted.

Edit the modify template to change shared preferences, then apply only this file:

```sh
chezmoi apply ~/.codex/config.toml
```

As with the Claude Code modify template, `chezmoi re-add` does not capture shared preference
changes made in the app; update the template instead.
