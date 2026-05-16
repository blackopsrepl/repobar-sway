# Repository Guidelines

## Project Structure

- `bin/repobar`: Ruby CLI entrypoint.
- `bin/release-check`: local release gate for syntax, tests, CLI smoke, Forgejo smoke, archive import smoke, and QuickShell load when available.
- `lib/repobar/core`: config normalization, REST/GraphQL cache, GitHub.com/Forgejo API access, local git scanning, formatting, and process helpers.
- `lib/repobar/runtime`: daemon, action store, cached state files, presenter, QuickShell launcher, and Waybar renderer.
- `frontend/quickshell/shell.qml`: the only human-facing UI.
- `docs/`: architecture, CLI reference, and UI assets.
- `test/`: deterministic Ruby tests.

## Build, Test, Run

- Syntax check: `ruby -wc $(rg --files bin lib test)`
- Test suite: `ruby -Itest test/run.rb`
- QML lint: `qmllint frontend/quickshell/shell.qml`
- CLI smoke: `bin/repobar config validate`, `bin/repobar waybar render`, `bin/repobar ui status --format json --pretty`
- Full local check: `bin/release-check`
- QuickShell smoke:
  `env QT_QPA_PLATFORM=wayland REPOBAR_BIN=$PWD/bin/repobar REPOBAR_CONFIG=$HOME/.repobar/config.json REPOBAR_STATE_DIR=$HOME/.local/state/repobar quickshell --path $PWD/frontend/quickshell/shell.qml`

## Architecture Rules

- Ruby only for the backend. Do not introduce Swift, TypeScript, Electron, or a second UI stack.
- Use standard-library dependencies unless a real blocker forces a dependency decision.
- QuickShell is the only product UI. Waybar is a cached-state chip and launcher.
- Keep hosted-repository fetching in `lib/repobar/core/github.rb`; UI code must not call GitHub.com or Forgejo directly.
- Keep local checkout scanning in `lib/repobar/core/local_git.rb`; UI code must not run `git`.
- Keep runtime actions daemon-owned. CLI and QuickShell dispatch actions; `Runtime::Daemon` and `Runtime::Store` own refresh, search, provider switching, pin/unpin/hide/show, and projection.
- Keep QuickShell presentation backed by `snapshot.json`, `ui.json`, `search.json`, and `state-event.json`.
- Waybar must remain a cached-state renderer, not a fetch path.
- Provider switching must preserve provider-specific cached snapshots under `providers/github.json` and `providers/forgejo.json`.
- Search must remain an async state transaction through `search.json`; do not make QuickShell block on network search.

## UI Rules

- Edit `frontend/quickshell/shell.qml` for the human UI.
- Keep repo action controls compact and icon-led. Current repo-card actions are open, read, refresh, pin/unpin, and hide.
- Preserve the bounded layout: repo heatmaps may clip inside their track, but controls must not push outside the panel bounds.
- Keep account heatmaps, repo heatmaps, issue/PR reader data, and pinned state driven by presenter output, not ad hoc UI fetches.
- Use tooltips and accessible names for icon-only controls.

## Testing

- Add deterministic tests under `test/`.
- Prefer testing config normalization, local-git parsing, cache behavior, presenter output, snapshot/state behavior, daemon/store transactions, and Waybar payloads without live network calls.
- Live GitHub.com and Forgejo checks are smoke tests only.
- When changing the QuickShell surface, run `qmllint frontend/quickshell/shell.qml` in addition to Ruby checks.
- When changing docs that list commands or architecture, compare against `lib/repobar/cli.rb`, `lib/repobar/core/config.rb`, and `lib/repobar/runtime/*`.

## Agent Notes

- GitHub.com mode uses `gh auth token`, `REPOBAR_GITHUB_TOKEN`, or `GITHUB_TOKEN`.
- Forgejo mode targets `http://vigilance:3002/api/v1` and supports public reads without a token.
- Forgejo private reads can use `REPOBAR_FORGEJO_TOKEN`, `FORGEJO_TOKEN`, or `GITEA_TOKEN`.
- Forgejo account heatmap login uses `REPOBAR_FORGEJO_LOGIN` when public auth reports `forgejo:public`, then falls back to `$USER`.
- Config lives at `~/.repobar/config.json`.
- Runtime state lives at `~/.local/state/repobar/`.
- REST/GraphQL/rate-limit cache files live under `~/.local/state/repobar/cache/`.
- SolverForge Waybar integration should be edited in the managed default layer, not directly through symlinked `~/.config/waybar` files.
