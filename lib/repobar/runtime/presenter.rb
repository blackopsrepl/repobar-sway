# frozen_string_literal: true

require "date"

module RepoBar
  module Runtime
    module Presenter
      module_function

      def build_snapshot_view(config, snapshot, now = Time.now)
        repos = Array(snapshot[:repositories])
        summary = summary_view(config, snapshot, repos, now)
        {
          summary: summary,
          chip: chip_view(summary, repos),
          repositories: repos.map { |repo| repo_view(config, repo, now) },
          localRepositories: Array(snapshot[:localRepositories])
        }
      end

      def summary_view(_config, snapshot, repos, now)
        stale = State.stale?(snapshot, snapshot[:config], now)
        errors = repos.count { |repo| repo[:error].to_s != "" }
        ci_failures = repos.count { |repo| repo[:ciStatus] == "failing" }
        dirty = repos.count { |repo| repo.dig(:local, :dirty) }
        open_prs = repos.sum { |repo| repo.dig(:stats, :openPulls).to_i }
        open_issues = repos.sum { |repo| repo.dig(:stats, :openIssues).to_i }
        rate = snapshot.dig(:account, :rateLimit) || {}
        provider = snapshot.dig(:account, :provider) || snapshot.dig(:config, :provider) || "github"
        {
          provider: provider.to_s == "forgejo" ? "forgejo" : "github",
          providerLabel: provider.to_s == "forgejo" ? "FJ" : "GH",
          repoCount: repos.length,
          openPulls: open_prs,
          openIssues: open_issues,
          ciFailures: ci_failures,
          dirtyRepos: dirty,
          errorCount: errors,
          stale: stale,
          account: snapshot.dig(:account, :login),
          rateLimitRemaining: rate[:remaining],
          rateLimitResetAt: rate[:resetAt],
          updatedText: Core::Format.relative_time(snapshot[:generatedAt], now)
        }
      end

      def chip_view(summary, repos)
        classes = ["repobar"]
        classes << "stale" if summary[:stale]
        classes << "error" if summary[:errorCount].positive?
        classes << "has-ci-failures" if summary[:ciFailures].positive?
        classes << "local-dirty" if summary[:dirtyRepos].positive?
        classes << "has-work" if summary[:openPulls].positive? || summary[:openIssues].positive?
        classes << "rate-limited" if summary[:rateLimitRemaining].to_i < 100 && !summary[:rateLimitRemaining].nil?
        classes << "healthy" if classes == ["repobar"]

        work = []
        work << "#{summary[:openPulls]} PR" if summary[:openPulls].positive?
        work << "#{summary[:openIssues]} issue" if summary[:openIssues].positive?
        work << "#{summary[:dirtyRepos]} dirty" if summary[:dirtyRepos].positive?
        work << "#{summary[:ciFailures]} CI" if summary[:ciFailures].positive?
        label = summary[:providerLabel] || "GH"
        text = work.empty? ? "#{label} #{summary[:repoCount]} repos" : "#{label} #{work.first(2).join(' ')}"

        tooltip = [
          "RepoBar",
          "Provider: #{summary[:provider] == 'forgejo' ? 'Forgejo' : 'GitHub'}",
          "Account: #{summary[:account] || 'not authenticated'}",
          "Repos: #{summary[:repoCount]}",
          "Open PRs: #{summary[:openPulls]}",
          "Open issues: #{summary[:openIssues]}",
          "Dirty local repos: #{summary[:dirtyRepos]}",
          "CI failures: #{summary[:ciFailures]}",
          summary[:rateLimitRemaining] ? "GitHub remaining: #{summary[:rateLimitRemaining]}" : nil,
          "Updated: #{summary[:updatedText]}",
          "",
          *repos.first(8).map { |repo| "#{repo[:fullName]}: #{repo.dig(:stats, :openPulls)} PR / #{repo.dig(:stats, :openIssues)} issues / #{repo[:ciStatus]}" }
        ].compact.join("\n")

        { text: text, tooltipLines: tooltip.split("\n"), classes: classes.uniq }
      end

      def repo_view(config, repo, now = Time.now)
        stats = repo.fetch(:stats, {})
        local = repo[:local]
        full_name = repo[:fullName].to_s.downcase
        pinned = Array(config.dig(:repoList, :pinnedRepositories)).include?(full_name)
        {
          fullName: repo[:fullName],
          name: repo[:name],
          owner: repo[:owner],
          ownerAvatarUrl: repo[:ownerAvatarUrl],
          ownerUrl: repo[:ownerUrl],
          description: repo[:description],
          url: repo[:url],
          private: repo[:private],
          archived: repo[:archived],
          fork: repo[:fork],
          pinned: pinned,
          stars: stats[:stars].to_i,
          forks: stats[:forks].to_i,
          openIssues: stats[:openIssues].to_i,
          openPulls: stats[:openPulls].to_i,
          pushedText: Core::Format.relative_time(stats[:pushedAt] || repo[:updatedAt], now),
          ciStatus: repo[:ciStatus] || "unknown",
          latestRelease: repo[:latestRelease],
          latestActivity: repo[:latestActivity],
          traffic: repo[:traffic],
          heatmap: heatmap_view(repo[:heatmap]),
          local: local,
          status: repo_status(repo),
          error: repo[:error]
        }
      end

      def heatmap_view(heatmap)
        cells = Array(heatmap && heatmap[:cells])
        cells = empty_heatmap_cells if cells.empty?
        max = (heatmap && heatmap[:max]).to_i
        {
          total: (heatmap && heatmap[:total]).to_i,
          max: max,
          cells: cells.last(42).map do |cell|
            count = cell[:count].to_i
            {
              date: cell[:date],
              count: count,
              intensity: max.positive? ? ((count.to_f / max) * 4).ceil : 0
            }
          end
        }
      end

      def empty_heatmap_cells
        start = Date.today - 41
        (0...42).map { |offset| { date: (start + offset).iso8601, count: 0 } }
      end

      def repo_status(repo)
        return "error" if repo[:error].to_s != ""
        return "ci-failing" if repo[:ciStatus] == "failing"
        return "dirty" if repo.dig(:local, :dirty)
        return "work" if repo.dig(:stats, :openPulls).to_i.positive? || repo.dig(:stats, :openIssues).to_i.positive?

        "quiet"
      end
    end
  end
end
