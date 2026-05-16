# frozen_string_literal: true

require_relative "test_helper"
require "timeout"

class StoreTest < Minitest::Test
  def test_pin_projects_cached_repo_immediately
    config_path = write_test_config
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo(name: "openclaw/openclaw")], [], { provider: "github" }, Time.now.utc)
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.pin_repo(config_path, "OpenClaw/OpenClaw")

    saved = RepoBar::Core::Config.load_config(config_path)
    view = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).first
    assert_includes saved.dig(:repoList, :pinnedRepositories), "openclaw/openclaw"
    assert_equal true, view[:pinned]
  end

  def test_unpin_projects_cached_repo_immediately
    config_path = write_test_config(repoList: { pinnedRepositories: ["openclaw/openclaw"] })
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo(name: "openclaw/openclaw")], [], { provider: "github" }, Time.now.utc)
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.unpin_repo(config_path, "openclaw/openclaw")

    saved = RepoBar::Core::Config.load_config(config_path)
    view = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).first
    refute_includes saved.dig(:repoList, :pinnedRepositories), "openclaw/openclaw"
    assert_equal false, view[:pinned]
  end

  def test_move_pinned_repo_reorders_config_and_projected_snapshot
    names = ["one/one", "two/two", "three/three"]
    config_path = write_test_config(repoList: { pinnedRepositories: names })
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(
      config,
      names.map { |name| sample_repo(name: name) },
      [],
      { provider: "github" },
      Time.now.utc
    )
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.move_pinned_repo(config_path, "three/three", 0)

    saved = RepoBar::Core::Config.load_config(config_path)
    view_names = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).map { |repo| repo[:fullName] }
    assert_equal ["three/three", "one/one", "two/two"], saved.dig(:repoList, :pinnedRepositories)
    assert_equal ["three/three", "one/one", "two/two"], view_names
  end

  def test_hide_removes_repo_from_projected_view
    config_path = write_test_config(repoList: { pinnedRepositories: ["openclaw/openclaw"] })
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo(name: "openclaw/openclaw")], [], { provider: "github" }, Time.now.utc)
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.hide_repo(config_path, "openclaw/openclaw")

    saved = RepoBar::Core::Config.load_config(config_path)
    view_repos = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories)
    assert_empty view_repos
    assert_includes saved.dig(:repoList, :hiddenRepositories), "openclaw/openclaw"
  end

  def test_pin_search_result_inserts_pending_repo
    config_path = write_test_config
    config = RepoBar::Core::Config.load_config(config_path)
    RepoBar::Runtime::State.write_snapshot(config, RepoBar::Runtime::State.build_snapshot(config, [], [], { provider: "github" }, Time.now.utc))
    search = RepoBar::Runtime::Store.start_search(config_path, "solverforge", limit: 5)
    RepoBar::Runtime::Store.finish_search(config_path, search[:requestId], "solverforge", results: [sample_repo(name: "solverforge/solverforge")])

    RepoBar::Runtime::Store.pin_repo(config_path, "solverforge/solverforge")

    saved = RepoBar::Core::Config.load_config(config_path)
    repo = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).first
    assert_equal "solverforge/solverforge", repo[:fullName]
    assert_equal true, repo[:pinned]
    assert_equal true, repo[:pending]
  end

  def test_provider_switch_projects_provider_without_changing_default
    config_path = write_test_config

    RepoBar::Runtime::Store.set_provider(config_path, "forgejo")

    saved = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.read_snapshot(saved)
    assert_equal "forgejo", saved.dig(:github, :provider)
    assert_equal "forgejo", snapshot.dig(:view, :summary, :provider)
    assert_equal "github", RepoBar::Core::Config.default_config.dig(:github, :provider)
  end

  def test_provider_switch_restores_cached_provider_snapshot
    config_path = write_test_config
    github_config = RepoBar::Core::Config.load_config(config_path)
    forgejo_config = RepoBar::Runtime::Store.provider_config(github_config, "forgejo")
    forgejo_snapshot = RepoBar::Runtime::State.build_snapshot(
      forgejo_config,
      [sample_repo(name: "pvd/fizzy")],
      [],
      { provider: "forgejo", login: "forgejo:public" },
      Time.now.utc
    )
    RepoBar::Runtime::State.write_provider_snapshot(forgejo_config, forgejo_snapshot, "forgejo")

    RepoBar::Runtime::Store.set_provider(config_path, "forgejo")

    saved = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.read_snapshot(saved)
    assert_equal "forgejo", snapshot.dig(:view, :summary, :provider)
    assert_equal ["pvd/fizzy"], snapshot.dig(:view, :repositories).map { |repo| repo[:fullName] }
  end

  def test_stale_refresh_does_not_overwrite_switched_provider_snapshot
    config_path = write_test_config(settings: { showContributionHeader: false })
    github_config = RepoBar::Core::Config.load_config(config_path)
    RepoBar::Runtime::State.write_snapshot(
      github_config,
      RepoBar::Runtime::State.build_snapshot(github_config, [sample_repo(name: "old/github")], [], { provider: "github" }, Time.now.utc)
    )
    forgejo_config = RepoBar::Runtime::Store.provider_config(github_config, "forgejo")
    forgejo_snapshot = RepoBar::Runtime::State.build_snapshot(
      forgejo_config,
      [sample_repo(name: "pvd/fizzy")],
      [],
      { provider: "forgejo", login: "forgejo:public" },
      Time.now.utc
    )
    RepoBar::Runtime::State.write_provider_snapshot(forgejo_config, forgejo_snapshot, "forgejo")

    RepoBar::Core::GitHub.stub(:auth_status, ->(config) { { authenticated: true, provider: config.dig(:github, :provider), login: "pvd" } }) do
      RepoBar::Core::GitHub.stub(:fetch_repositories, ->(_config) {
        RepoBar::Runtime::Store.set_provider(config_path, "forgejo")
        [sample_repo(name: "late/github")]
      }) do
        RepoBar::Core::LocalGit.stub(:scan, ->(_config) { [] }) do
          RepoBar::Runtime::Store.refresh_effect(config_path)
        end
      end
    end

    saved = RepoBar::Core::Config.load_config(config_path)
    active_snapshot = RepoBar::Runtime::State.read_snapshot(saved)
    github_snapshot = RepoBar::Runtime::State.read_provider_snapshot(saved, "github")
    assert_equal "forgejo", active_snapshot.dig(:view, :summary, :provider)
    assert_equal ["pvd/fizzy"], active_snapshot.dig(:view, :repositories).map { |repo| repo[:fullName] }
    assert_equal ["late/github"], github_snapshot.dig(:view, :repositories).map { |repo| repo[:fullName] }
  end

  def test_stale_same_provider_refresh_preserves_current_pinned_order_in_provider_cache
    config_path = write_test_config(
      settings: { showContributionHeader: false },
      repoList: { pinnedRepositories: ["one/one", "two/two", "three/three"] }
    )
    config = RepoBar::Core::Config.load_config(config_path)
    RepoBar::Runtime::State.write_snapshot(
      config,
      RepoBar::Runtime::State.build_snapshot(
        config,
        ["one/one", "two/two", "three/three"].map { |name| sample_repo(name: name) },
        [],
        { provider: "github" },
        Time.now.utc
      )
    )

    RepoBar::Core::GitHub.stub(:auth_status, ->(loaded_config) { { authenticated: true, provider: loaded_config.dig(:github, :provider), login: "pvd" } }) do
      RepoBar::Core::GitHub.stub(:fetch_repositories, ->(_loaded_config) {
        RepoBar::Runtime::Store.move_pinned_repo(config_path, "three/three", 0)
        ["one/one", "two/two", "three/three"].map { |name| sample_repo(name: name) }
      }) do
        RepoBar::Core::LocalGit.stub(:scan, ->(_loaded_config) { [] }) do
          RepoBar::Runtime::Store.refresh_effect(config_path)
        end
      end
    end

    current = RepoBar::Core::Config.load_config(config_path)
    active_snapshot = RepoBar::Runtime::State.read_snapshot(current)
    provider_snapshot = RepoBar::Runtime::State.read_provider_snapshot(current, "github")
    assert_equal ["three/three", "one/one", "two/two"], active_snapshot.dig(:view, :repositories).map { |repo| repo[:fullName] }
    assert_equal ["three/three", "one/one", "two/two"], provider_snapshot.dig(:view, :repositories).map { |repo| repo[:fullName] }
  end

  def test_daemon_refresh_requests_coalesce_while_refresh_is_running
    config_path = write_test_config
    refresh_state = { thread: nil, pending: false, mutex: Mutex.new }
    started = Queue.new
    release = Queue.new
    call_count = 0
    count_mutex = Mutex.new

    RepoBar::Runtime::Daemon.stub(:refresh, ->(_path) {
      current = count_mutex.synchronize do
        call_count += 1
      end
      started << current
      release.pop
    }) do
      thread = RepoBar::Runtime::Daemon.request_refresh(config_path, refresh_state)
      assert_equal 1, Timeout.timeout(1) { started.pop }

      3.times { RepoBar::Runtime::Daemon.request_refresh(config_path, refresh_state) }
      release << true
      assert_equal 2, Timeout.timeout(1) { started.pop }
      release << true
      thread.join(1)
    end

    assert_equal 2, call_count
    assert_nil refresh_state[:thread]
    assert_equal false, refresh_state[:pending]
  end

  def test_timer_refresh_requests_do_not_queue_pending_refresh
    config_path = write_test_config
    refresh_state = { thread: nil, pending: false, mutex: Mutex.new }
    started = Queue.new
    release = Queue.new
    call_count = 0
    count_mutex = Mutex.new

    RepoBar::Runtime::Daemon.stub(:refresh, ->(_path) {
      count_mutex.synchronize do
        call_count += 1
      end
      started << true
      release.pop
    }) do
      thread = RepoBar::Runtime::Daemon.request_refresh(config_path, refresh_state)
      Timeout.timeout(1) { started.pop }

      3.times { RepoBar::Runtime::Daemon.request_refresh(config_path, refresh_state, queue_pending: false) }
      release << true
      thread.join(1)
    end

    assert_equal 1, call_count
    assert_nil refresh_state[:thread]
    assert_equal false, refresh_state[:pending]
  end

  def test_search_start_and_finish_are_state_transactions
    config_path = write_test_config

    state = RepoBar::Runtime::Store.start_search(config_path, "solverforge", limit: 5)
    assert_equal "loading", state[:status]
    assert_equal "solverforge", state[:query]

    finished = RepoBar::Runtime::Store.finish_search(config_path, state[:requestId], "solverforge", results: [sample_repo(name: "solverforge/solverforge")])
    assert_equal "ready", finished[:status]
    assert_equal ["solverforge/solverforge"], finished[:results].map { |repo| repo[:fullName] }
  end

  def test_cli_visibility_commands_do_not_refresh_synchronously
    config_path = write_test_config

    RepoBar::Runtime::Daemon.stub(:dispatch_action, ->(_path, action) { { action: action[:type], pinnedRepositories: ["openclaw/openclaw"] } }) do
      RepoBar::Runtime::Daemon.stub(:refresh, ->(*) { raise "refresh should be an effect" }) do
        _out, _err = capture_io do
          assert_equal 0, RepoBar::CLI.run(["pin", "openclaw/openclaw", "--config", config_path])
        end
      end
    end
  end

  private

  def write_test_config(overrides = {})
    dir = Dir.mktmpdir
    path = File.join(dir, "config.json")
    config = RepoBar::Core::Config.normalize_config({ runtime: { stateDir: File.join(dir, "state") }, localProjects: { roots: [] } }.merge(overrides))
    RepoBar::Core::Config.save_config(config, path)
    path
  end
end
