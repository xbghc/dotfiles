# Idle Compact

A local Codex plugin that requests one context compaction after a completed
conversation turn has been idle for 25 minutes. Its files are managed by chezmoi.

## Timing

OpenAI documents a minimum 30-minute prompt-cache lifetime for GPT-5.6 and later,
including GPT-6 Astra. Reusing a prefix refreshes its lifetime. This plugin uses
25 minutes after the turn stops, leaving a nominal five-minute margin.

This is a scheduling heuristic, not an exact cache-expiration detector. Codex's
ChatGPT backend does not expose its actual cache lifetime to hooks, and a long
response can make the last cache write older than the end of the turn. Compaction
itself uses inference and changes the cached prefix; it does not guarantee cost
savings or keep a conversation cached indefinitely.

Older or unknown model families are skipped instead of guessing their cache TTL.

Sources:

- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [App-server compaction](https://learn.chatgpt.com/docs/app-server#trigger-thread-compaction)

## Behaviour

- `UserPromptSubmit` starts a new activity generation; `Stop` arms its timer.
- New input, interruption, session start/end, or another compaction cancels it.
- A compaction does not arm another timer. There must be a new user turn first.
- Before requesting compaction, the worker checks that the original thread is
  still loaded and idle, its transcript path matches, no newer activity is
  recorded, and no background terminal is running.
- `PreCompact` checks for input arriving after the final idle check. The public
  compaction RPC has no atomic "only if still idle" option, so an extremely close
  race between user input and compaction submission cannot be eliminated.
- Unloaded conversations, API failures, and unsupported runtimes are skipped;
  the plugin does not resume threads, retry indefinitely, or start a new daemon.
- State contains identifiers, timestamps, paths, and outcomes, not message text.
  With the user-hook registration below, it lives in `~/.codex/idle-compact`.

## Requirements and installation

Use a local Codex runtime with plugin hooks and the shared app-server daemon
(daemon connection verified with Codex 0.163.0 on Windows). This is not a cloud-task plugin or a
standalone `codex exec` integration. The app-server interface is experimental.

Install Python 3.11+ and `websocket-client` in the Python environment used by the
hook (`python` on Windows, `python3` elsewhere). On a new machine:

```sh
chezmoi apply --exclude scripts ~/.codex/local-marketplace
python -m pip install -r ~/.codex/local-marketplace/plugins/idle-compact/requirements.txt
codex plugin marketplace add ~/.codex/local-marketplace
codex plugin add idle-compact@chezmoi-local
chezmoi apply --exclude scripts ~/.codex/hooks.json
```

Use `python3` instead of `python` on macOS/Linux.

The tested 0.163.0 and 0.163.0-alpha.10.2 runtimes install the plugin but do not
expose its bundled hooks. `dot_codex/modify_hooks.json` therefore registers seven
user hooks that call the plugin script in the local marketplace. It preserves
unrelated hooks and does not duplicate its own registrations on repeated apply.
The compatibility manifest explicitly declares no bundled hooks to prevent
duplicate execution if plugin-hook discovery changes in a later runtime.

In Codex CLI, open `/hooks`, review and trust the seven `Idle Compact (chezmoi)` definitions,
then start a new session. Codex requires explicit hook trust; installation alone
does not activate untrusted hooks. Hook changes require review again.

The script finds `codex` through `CODEX_CLI_PATH`, `PATH`, or the managed daemon
package. Set `CODEX_IDLE_COMPACT_CODEX` to an executable path if needed.

## Verification

From the plugin directory:

```sh
python -B -m unittest discover -s tests
python scripts/idle_compact.py check
```

`check` only reads the current daemon's loaded-thread list. It never compacts.
To inspect an armed timer or its result, run:

```sh
python scripts/idle_compact.py status --session THREAD_ID
```

Disable or uninstall the plugin in `/plugins` to prevent new timers. Existing
workers recheck its enabled setting before requesting compaction, so disabling
the plugin also prevents their pending compactions. The workers exit within
25 minutes. The chezmoi template enables this personal plugin again on apply;
remove that preference from the template for a persistent opt-out.
