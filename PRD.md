# RepoBar Linux PRD

## Summary

RepoBar Linux is a SolverForge Linux implementation inspired by [steipete](https://github.com/steipete)'s original [RepoBar](https://github.com/steipete/RepoBar). It keeps the repository-pressure product idea, but implements it with the same local architecture used by CodexBar:

- Ruby backend
- cached JSON state
- resident daemon
- QuickShell popover
- Waybar chip

## Goal

Make GitHub.com and local Forgejo repository pressure visible without opening a
browser:

- which repos have open PRs or issues
- which repos have failing or pending CI
- which local checkouts are dirty, ahead, or behind
- whether GitHub rate limits are healthy when using GitHub.com
- when each repo last moved

## V1 Decisions

- Use the existing `gh` token for GitHub.com auth.
- Support the local Forgejo instance at `http://vigilance:3002` through
  `/api/v1`, with no token required for public repositories.
- Use standard-library Ruby and JSON cache/state.
- Do not implement GitHub App OAuth in v1.
- Use RepoBar-owned JSON API cache files and import Discrawl-style archive snapshots into SQLite through the `sqlite3` CLI.
- Do not implement macOS Swift/AppKit, Sparkle, Keychain, or Homebrew paths.
- Use one human UI: QuickShell.
- Use Waybar only as a compact launcher/render surface.

## Runtime Contract

- CLI: `bin/repobar`
- Config: `~/.repobar/config.json`
- Snapshot: `~/.local/state/repobar/snapshot.json`
- UI state: `~/.local/state/repobar/ui.json`

The frontend reads files and sends mutations through CLI commands. It does not fetch repository-host data directly.

## Success Criteria

- `repobar refresh` writes a usable snapshot from live GitHub.com or Forgejo data.
- `repobar waybar render` returns valid Waybar JSON from cached state.
- The QuickShell panel renders repo rows and status summaries from `snapshot.json`.
- Local checkout state is matched to hosted repositories without mutating local repos.
- The SolverForge Waybar module opens the panel and refreshes on demand.
