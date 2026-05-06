# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_default_config_uses_repobar_paths
    config = RepoBar::Core::Config.default_config

    assert_equal 1, config[:version]
    assert_equal "github", config.dig(:github, :provider)
    assert_equal File.join(Dir.home, ".local", "state", "repobar"), config.dig(:runtime, :stateDir)
    assert_equal File.join(Dir.home, ".repobar", "config.json"), RepoBar::Core::Config.default_config_path
  end

  def test_normalize_filters_invalid_repo_names_and_clamps_values
    config = RepoBar::Core::Config.normalize_config(
      repoList: {
        displayLimit: 0,
        pinnedRepositories: ["OpenClaw/OpenClaw", "bad", "openclaw/openclaw"]
      },
      runtime: {
        refreshSeconds: 1,
        waybarSignal: 0
      }
    )

    assert_equal 5, config.dig(:repoList, :displayLimit)
    assert_equal ["openclaw/openclaw"], config.dig(:repoList, :pinnedRepositories)
    assert_equal 30, config.dig(:runtime, :refreshSeconds)
    assert_equal 10, config.dig(:runtime, :waybarSignal)
  end

  def test_forgejo_config_uses_local_api_defaults
    config = RepoBar::Core::Config.normalize_config(
      github: {
        provider: "forgejo",
        host: "http://vigilance:3002"
      }
    )

    assert_equal "forgejo", config.dig(:github, :provider)
    assert_equal "http://vigilance:3002", config.dig(:github, :host)
    assert_equal "http://vigilance:3002/api/v1", config.dig(:github, :apiHost)
    assert_equal "env", config.dig(:github, :authSource)
    assert_empty RepoBar::Core::Config.validate_config(config).select { |issue| issue[:severity] == "error" }
  end
end
