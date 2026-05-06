# frozen_string_literal: true

require_relative "test_helper"

class RuntimeTest < Minitest::Test
  def test_snapshot_contains_view_and_waybar_work_classes
    config = build_config
    repos = [
      sample_repo(name: "openclaw/openclaw", prs: 2, issues: 1, ci: "failing", dirty: true),
      sample_repo(name: "solverforge/solverforge-rs", prs: 0, issues: 0, ci: "passing")
    ]
    account = { authenticated: true, login: "blackopsrepl", rateLimit: { remaining: 4, limit: 5000 } }

    snapshot = RepoBar::Runtime::State.build_snapshot(config, repos, [], account, Time.now.utc)
    payload = RepoBar::Runtime::Waybar.payload(config, snapshot, Time.now)

    assert_equal 2, snapshot.dig(:view, :summary, :repoCount)
    assert_includes payload[:text], "GH"
    assert_includes payload[:class], "has-work"
    assert_includes payload[:class], "has-ci-failures"
    assert_includes payload[:class], "local-dirty"
    assert_includes payload[:class], "rate-limited"
  end

  def test_waybar_payload_reports_loading_without_snapshot
    config = build_config
    payload = RepoBar::Runtime::Waybar.payload(config, nil, Time.now)

    assert_equal "GH ...", payload[:text]
    assert_includes payload[:class], "loading"
  end

  def test_repo_view_always_exposes_heatmap_track
    view = RepoBar::Runtime::Presenter.repo_view(build_config, sample_repo, Time.now.utc)

    assert_equal 42, view.dig(:heatmap, :cells).length
  end

  def test_repo_view_exposes_pinned_state
    config = build_config
    config[:repoList][:pinnedRepositories] = ["openclaw/openclaw"]
    view = RepoBar::Runtime::Presenter.repo_view(config, sample_repo(name: "OpenClaw/OpenClaw"), Time.now.utc)

    assert_equal true, view[:pinned]
  end

  def test_state_event_file_keeps_stable_inode_across_snapshot_writes
    config = build_config
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo], [], {}, Time.now.utc)

    RepoBar::Runtime::State.write_snapshot(config, snapshot)
    event_path = RepoBar::Runtime::State.state_event_path(config)
    first_inode = File.stat(event_path).ino

    RepoBar::Runtime::State.write_snapshot(config, snapshot.merge(generatedAt: Time.now.utc.iso8601))

    assert_equal first_inode, File.stat(event_path).ino
    assert_match(/updatedAt/, File.read(event_path))
  end
end
