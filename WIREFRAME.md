# RepoBar Repo Wireframe

## High-Level Shape

1. `bin/repobar` starts the CLI.
2. `lib/repobar/cli.rb` routes commands.
3. `lib/repobar/core/github.rb` fetches GitHub.com data through the `gh` token or local Forgejo data through `http://vigilance:3002/api/v1`.
4. `lib/repobar/core/local_git.rb` scans local checkouts and maps them to hosted repos.
5. `lib/repobar/runtime/daemon.rb` refreshes data and writes snapshots.
6. `lib/repobar/runtime/presenter.rb` converts raw repo data into UI-ready state.
7. `lib/repobar/runtime/waybar.rb` renders the compact Waybar JSON payload.
8. `lib/repobar/runtime/quickshell.rb` opens and controls the QuickShell panel.
9. `frontend/quickshell/shell.qml` renders the human UI.

## Data Flow

Normal refresh:

1. `repobar daemon` or `repobar refresh` loads config.
2. GitHub.com auth is read from `gh auth token`; Forgejo public mode does not require a token.
3. Repositories are fetched and hydrated with issues, PRs, CI, release, and activity data.
4. Local git repos are scanned from configured roots.
5. Local state is matched to repository rows.
6. A snapshot is written to `~/.local/state/repobar/snapshot.json`.
7. Waybar is signaled.
8. QuickShell updates from the watched file.

UI flow:

1. Waybar calls `solverforge-waybar-repobar open`.
2. The wrapper calls `repobar waybar panel`.
3. `ui.json` is updated and QuickShell is started if needed.
4. QuickShell reads `snapshot.json` and `ui.json`.

## Canonical Files

- `README.md`
- `PRD.md`
- `WIREFRAME.md`
- `AGENTS.md`
- `bin/repobar`
- `bin/release-check`
- `lib/repobar/core/config.rb`
- `lib/repobar/core/github.rb`
- `lib/repobar/core/local_git.rb`
- `lib/repobar/runtime/state.rb`
- `lib/repobar/runtime/presenter.rb`
- `lib/repobar/runtime/daemon.rb`
- `lib/repobar/runtime/quickshell.rb`
- `lib/repobar/runtime/waybar.rb`
- `frontend/quickshell/shell.qml`
