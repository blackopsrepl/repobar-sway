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
end
