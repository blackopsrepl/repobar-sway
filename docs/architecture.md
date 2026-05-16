# Architecture

RepoBar Linux has five active layers:

1. Ruby CLI in `bin/repobar`.
2. Core Ruby services for config, hosted APIs, cache, local git, formatting, and process execution.
3. Daemon-owned runtime actions and cached JSON state.
4. Presenter output for Waybar and QuickShell.
5. QuickShell panel plus Waybar chip.

## Boundaries

The hosted-repository boundary lives in `lib/repobar/core/github.rb`; despite the historical filename, it handles both GitHub.com and the local Forgejo API at `http://vigilance:3002/api/v1`. It also owns REST caching, GraphQL contribution calendar calls, issue/PR/release/CI/activity hydration, and account/repo heatmaps.

The local checkout boundary lives in `lib/repobar/core/local_git.rb`. It scans configured roots, resolves repo targets, reports branch/dirty/ahead/behind state, and performs explicit sync/rebase/reset/clone operations.

The runtime boundary lives in `lib/repobar/runtime/daemon.rb`, `store.rb`, and `state.rb`. The daemon owns the action socket, refresh loop, async search jobs, provider switches, visibility mutations, and state projection.

The presentation boundary lives in `lib/repobar/runtime/presenter.rb`. It converts raw snapshots into summary state, Waybar chip state, account heatmap rows, repo cards, readable issue/PR previews, pinned state, and normalized heatmap cells.

The frontend boundary is `frontend/quickshell/shell.qml`. It watches JSON files, dispatches CLI commands, and renders the UI. It does not call GitHub.com, Forgejo, or `git`.

## State

Runtime state defaults to `~/.local/state/repobar/`.

- `snapshot.json`: canonical current provider snapshot plus presenter `view`.
- `providers/github.json` and `providers/forgejo.json`: provider-specific snapshots for instant provider switching.
- `ui.json`: panel state.
- `search.json`: async search state.
- `state-event.json`: stable watched reload signal.
- `daemon.sock`: daemon action socket.
- `cache/rest.json`, `cache/graphql.json`, and `cache/rate_limits.json`: network cache and rate-limit records.

## UI

QuickShell renders a header, optional account activity heatmap, search results, an issue/PR reader, and repo cards. Repo cards use icon actions for open, read, refresh, pin/unpin, and hide. The repo heatmap track is clipped inside the card so controls cannot force the row outside the panel.

Waybar reads cached presenter state only. It never refreshes network data directly; refresh is a daemon action.
