# RepoBar CLI

Global flags:

- `--config PATH`
- `--format json|text`
- `--pretty`
- `--limit N`

Commands:

- `repobar auth status`
- `repobar config init`
- `repobar config github`
- `repobar config forgejo [http://vigilance:3002]`
- `repobar config validate`
- `repobar provider github|forgejo`
- `repobar repos`
- `repobar search query`
- `repobar repo owner/name`
- `repobar issues owner/name`
- `repobar pulls owner/name`
- `repobar releases owner/name`
- `repobar ci owner/name`
- `repobar discussions owner/name`
- `repobar tags owner/name`
- `repobar branches owner/name`
- `repobar contributors owner/name`
- `repobar commits [owner/name|login]`
- `repobar activity [owner/name|login]`
- `repobar contributions [login]`
- `repobar local`
- `repobar local sync|rebase|branches <path|owner/name>`
- `repobar local reset <path|owner/name> --yes`
- `repobar worktrees <path|owner/name>`
- `repobar checkout owner/name`
- `repobar pin|unpin|hide|show owner/name`
- `repobar settings show`
- `repobar settings set <key> <value>`
- `repobar cache status|clear`
- `repobar rate-limits`
- `repobar archives list|status|validate|add|remove|enable|disable|update`
- `repobar changelog [path]`
- `repobar markdown path`
- `repobar refresh`
- `repobar daemon`
- `repobar panel`
- `repobar ui open|close|toggle|status`
- `repobar waybar render|refresh|panel`
- `repobar open URL`

GitHub is the default provider. `repobar provider github|forgejo` switches the
active provider and refreshes the snapshot immediately.

Forgejo mode points `github.provider` at `forgejo`, uses
`http://vigilance:3002/api/v1`, and works without a token for public local
repositories. Private repositories can be enabled by exporting
`REPOBAR_FORGEJO_TOKEN`, `FORGEJO_TOKEN`, or `GITEA_TOKEN`.
