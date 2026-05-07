# frozen_string_literal: true

require_relative "test_helper"

class ForgejoTest < Minitest::Test
  def test_maps_forgejo_repository_shape
    config = RepoBar::Core::Config.normalize_config(github: { provider: "forgejo" })
    repo = RepoBar::Core::GitHub.map_repo_item(
      {
        owner: { login: "pvd", avatar_url: "http://vigilance:3002/avatars/pvd" },
        name: "repo-bar-port",
        full_name: "pvd/repo-bar-port",
        html_url: "http://vigilance:3002/pvd/repo-bar-port",
        private: false,
        fork: false,
        archived: false,
        stars_count: 7,
        forks_count: 2,
        open_issues_count: 3,
        open_pr_counter: 4,
        updated_at: "2026-05-06T10:00:00Z"
      },
      {},
      config
    )

    assert_equal "pvd/repo-bar-port", repo[:fullName]
    assert_equal "http://vigilance:3002/avatars/pvd", repo[:ownerAvatarUrl]
    assert_equal "http://vigilance:3002/pvd/repo-bar-port", repo[:url]
    assert_equal 7, repo.dig(:stats, :stars)
    assert_equal 3, repo.dig(:stats, :openIssues)
    assert_equal 4, repo.dig(:stats, :openPulls)
    assert_equal "2026-05-06T10:00:00Z", repo.dig(:stats, :pushedAt)
  end

  def test_public_forgejo_has_no_required_token
    config = RepoBar::Core::Config.normalize_config(github: { provider: "forgejo" })

    assert_nil RepoBar::Core::GitHub.access_token(config)
  end

  def test_github_heatmap_uses_recent_commit_activity
    config = build_config
    today = Date.today.iso8601
    yesterday = (Date.today - 1).iso8601
    commits = [
      { date: "#{today}T08:00:00Z" },
      { date: "#{today}T10:00:00Z" },
      { date: "#{yesterday}T10:00:00Z" }
    ]

    RepoBar::Core::GitHub.stub(:commits, commits) do
      heatmap = RepoBar::Core::GitHub.heatmap(config, "token", "openclaw", "openclaw")
      counts = heatmap[:cells].to_h { |cell| [cell[:date], cell[:count]] }

      assert_equal 3, heatmap[:total]
      assert_equal 2, counts[today]
      assert_equal 1, counts[yesterday]
    end
  end

  def test_fresh_rest_cache_short_circuits_network
    config = build_config
    uri = URI("https://api.github.com/repos/openclaw/openclaw")
    RepoBar::Core::Cache.write_rest_entry(
      config,
      uri,
      status: 200,
      headers: { "etag" => "cached" },
      body: JSON.generate(full_name: "openclaw/openclaw", name: "openclaw", owner: { login: "openclaw" })
    )

    Net::HTTP.stub(:start, ->(*) { raise "network should not be used for fresh cache" }) do
      response = RepoBar::Core::GitHub.request(config, "/repos/openclaw/openclaw", token: "token")
      assert_equal 200, response.status
      assert_equal "openclaw/openclaw", response.data[:full_name]
    end
  end

  def test_stale_rest_cache_uses_network
    config = build_config
    uri = URI("https://api.github.com/repos/openclaw/openclaw")
    RepoBar::Core::Cache.write_rest_entry(
      config,
      uri,
      status: 200,
      headers: { "etag" => "stale" },
      body: JSON.generate(full_name: "stale/repo")
    )
    path = RepoBar::Core::Cache.rest_path(config)
    data = JSON.parse(File.read(path))
    data.values.first["fetchedAt"] = (Time.now.utc - 3600).iso8601
    File.write(path, "#{JSON.pretty_generate(data)}\n")
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, JSON.generate(full_name: "openclaw/openclaw"))
    http = Object.new
    http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:start, lambda { |*_, &block| block.call(http) }) do
      result = RepoBar::Core::GitHub.request(config, "/repos/openclaw/openclaw", token: "token")
      assert_equal "openclaw/openclaw", result.data[:full_name]
    end
  end
end
