# Architecture

RepoBar Linux has four active layers:

1. Ruby CLI
2. Ruby backend for GitHub.com/Forgejo/local-git/state
3. Cached runtime files
4. QuickShell frontend plus Waybar chip

The hosted-repository boundary lives in `lib/repobar/core/github.rb`; despite
the historical filename, it handles GitHub.com and the local Forgejo API at
`http://vigilance:3002/api/v1`. The local checkout boundary lives in
`lib/repobar/core/local_git.rb`. Runtime state is assembled in
`lib/repobar/runtime/state.rb` and presentation state is assembled in
`lib/repobar/runtime/presenter.rb`.

The frontend does not call GitHub.com/Forgejo, run `git`, or mutate config directly.
