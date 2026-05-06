# frozen_string_literal: true

require_relative "test_helper"

class StoreTest < Minitest::Test
  def test_pin_projects_cached_repo_immediately
    config_path = write_test_config
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo(name: "openclaw/openclaw")], [], { provider: "github" }, Time.now.utc)
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
      RepoBar::Runtime::Store.pin_repo(config_path, "OpenClaw/OpenClaw")
    end

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

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
      RepoBar::Runtime::Store.unpin_repo(config_path, "openclaw/openclaw")
    end

    saved = RepoBar::Core::Config.load_config(config_path)
    view = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).first
    refute_includes saved.dig(:repoList, :pinnedRepositories), "openclaw/openclaw"
    assert_equal false, view[:pinned]
  end

  def test_hide_removes_repo_from_projected_view
    config_path = write_test_config(repoList: { pinnedRepositories: ["openclaw/openclaw"] })
    config = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.build_snapshot(config, [sample_repo(name: "openclaw/openclaw")], [], { provider: "github" }, Time.now.utc)
    RepoBar::Runtime::State.write_snapshot(config, snapshot)

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
      RepoBar::Runtime::Store.hide_repo(config_path, "openclaw/openclaw")
    end

    saved = RepoBar::Core::Config.load_config(config_path)
    view_repos = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories)
    assert_empty view_repos
    assert_includes saved.dig(:repoList, :hiddenRepositories), "openclaw/openclaw"
  end

  def test_pin_search_result_inserts_pending_repo
    config_path = write_test_config
    config = RepoBar::Core::Config.load_config(config_path)
    RepoBar::Runtime::State.write_snapshot(config, RepoBar::Runtime::State.build_snapshot(config, [], [], { provider: "github" }, Time.now.utc))
    search = RepoBar::Runtime::Store.start_search(config_path, "solverforge", limit: 5, effects: false)
    RepoBar::Runtime::Store.finish_search(config_path, search[:requestId], "solverforge", results: [sample_repo(name: "solverforge/solverforge")])

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
      RepoBar::Runtime::Store.pin_repo(config_path, "solverforge/solverforge")
    end

    saved = RepoBar::Core::Config.load_config(config_path)
    repo = RepoBar::Runtime::State.read_snapshot(saved).dig(:view, :repositories).first
    assert_equal "solverforge/solverforge", repo[:fullName]
    assert_equal true, repo[:pinned]
    assert_equal true, repo[:pending]
  end

  def test_provider_switch_projects_provider_without_changing_default
    config_path = write_test_config

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
      RepoBar::Runtime::Store.set_provider(config_path, "forgejo")
    end

    saved = RepoBar::Core::Config.load_config(config_path)
    snapshot = RepoBar::Runtime::State.read_snapshot(saved)
    assert_equal "forgejo", saved.dig(:github, :provider)
    assert_equal "forgejo", snapshot.dig(:view, :summary, :provider)
    assert_equal "github", RepoBar::Core::Config.default_config.dig(:github, :provider)
  end

  def test_search_start_and_finish_are_state_transactions
    config_path = write_test_config

    RepoBar::Runtime::Store.stub(:spawn_search_effect, nil) do
      state = RepoBar::Runtime::Store.start_search(config_path, "solverforge", limit: 5)
      assert_equal "loading", state[:status]
      assert_equal "solverforge", state[:query]

      finished = RepoBar::Runtime::Store.finish_search(config_path, state[:requestId], "solverforge", results: [sample_repo(name: "solverforge/solverforge")])
      assert_equal "ready", finished[:status]
      assert_equal ["solverforge/solverforge"], finished[:results].map { |repo| repo[:fullName] }
    end
  end

  def test_cli_visibility_commands_do_not_refresh_synchronously
    config_path = write_test_config

    RepoBar::Runtime::Store.stub(:spawn_refresh_effect, nil) do
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
