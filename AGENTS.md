# Repository Guidelines

## Project Structure

- `bin/repobar`: Ruby entrypoint.
- `lib/repobar/core`: config, GitHub.com/Forgejo REST, local git, formatting, and process helpers.
- `lib/repobar/runtime`: daemon, cached state, presenter, QuickShell, and Waybar output.
- `frontend/quickshell/shell.qml`: the only human-facing UI.
- `test`: built-in Ruby test suite.

## Build, Test, Run

- Syntax check: `ruby -wc $(rg --files bin lib test)`
- Test suite: `ruby -Itest test/run.rb`
- CLI smoke: `bin/repobar config validate`, `bin/repobar waybar render`, `bin/repobar ui status --format json --pretty`
- Full local check: `bin/release-check`
- QuickShell smoke:
  `env QT_QPA_PLATFORM=wayland REPOBAR_BIN=$PWD/bin/repobar REPOBAR_CONFIG=$HOME/.repobar/config.json REPOBAR_STATE_DIR=$HOME/.local/state/repobar quickshell --path $PWD/frontend/quickshell/shell.qml`

## Coding Style

- Ruby only for the backend. Do not introduce Swift, TypeScript, or a second UI stack.
- Use standard-library dependencies unless a real blocker forces a dependency decision.
- Keep hosted-repo fetching in `core/github.rb`; UI code must not call GitHub.com or Forgejo directly.
- Keep QuickShell presentation backed by `snapshot.json` and `ui.json`.
- Waybar must remain a cached-state renderer, not a fetch path.

## Testing

- Add deterministic tests under `test/`.
- Prefer testing config normalization, local-git parsing, presenter output, snapshot behavior, and Waybar payloads without live network calls.
- Live GitHub.com and Forgejo checks are smoke tests only.

## Agent Notes

- GitHub.com mode uses `gh auth token`.
- Forgejo mode targets `http://vigilance:3002/api/v1` and supports public reads without a token.
- Config lives at `~/.repobar/config.json`.
- Runtime state lives at `~/.local/state/repobar/`.
- QuickShell is the only product UI.
- SolverForge Waybar integration should be edited in the managed default layer, not directly through symlinked `~/.config/waybar` files.
