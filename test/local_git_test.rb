# frozen_string_literal: true

require_relative "test_helper"

class LocalGitTest < Minitest::Test
  def test_parse_github_remotes
    assert_equal "owner/repo", RepoBar::Core::LocalGit.parse_remote("git@github.com:Owner/repo.git")
    assert_equal "owner/repo", RepoBar::Core::LocalGit.parse_remote("https://github.com/Owner/repo.git")
  end

  def test_parse_forgejo_remotes
    assert_equal "owner/repo", RepoBar::Core::LocalGit.parse_remote("ssh://git@vigilance/Owner/repo.git")
    assert_equal "owner/repo", RepoBar::Core::LocalGit.parse_remote("git@vigilance:Owner/repo.git")
    assert_equal "owner/repo", RepoBar::Core::LocalGit.parse_remote("http://vigilance:3002/Owner/repo.git")
  end

  def test_match_repositories_prefers_remote_full_name
    repo = sample_repo(name: "openclaw/openclaw")
    local = [{ path: "/tmp/not-name", fullName: "openclaw/openclaw", branch: "main" }]

    matched = RepoBar::Core::LocalGit.match_repositories([repo], local).first

    assert_equal "/tmp/not-name", matched.dig(:local, :path)
  end
end
