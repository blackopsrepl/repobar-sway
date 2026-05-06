# frozen_string_literal: true

require "securerandom"
require "time"

module RepoBar
  module Runtime
    module Store
      module_function

      def open_panel(config_path, repository = nil)
        config = Core::Config.load_config(config_path)
        State.ensure_ui_state(config)
        state = State.read_ui_state(config)
        state[:open] = true
        state[:focusRepository] = repository.to_s if repository
        state[:requestedAt] = timestamp
        State.write_ui_state(config, state)
        state
      end

      def close_panel(config_path)
        config = Core::Config.load_config(config_path)
        state = State.read_ui_state(config)
        state[:open] = false
        state[:requestedAt] = timestamp
        State.write_ui_state(config, state)
        state
      end

      def provider_config(config, provider, host = nil)
        if provider == "forgejo"
          forgejo_host = host || "http://vigilance:3002"
          return config.merge(
            github: config[:github].merge(
              provider: "forgejo",
              host: forgejo_host,
              apiHost: "#{forgejo_host.sub(%r{/*\z}, '')}/api/v1",
              authSource: "env"
            )
          )
        end

        config.merge(
          github: config[:github].merge(
            provider: "github",
            host: "https://github.com",
            apiHost: "https://api.github.com",
            authSource: "gh"
          )
        )
      end

      def set_provider(config_path, provider, host: nil, effects: true)
        raise ArgumentError, "provider must be github or forgejo." unless %w[github forgejo].include?(provider)

        config = Core::Config.load_config(config_path)
        saved = Core::Config.save_config(provider_config(config, provider, host), config_path)
        State.write_search_state(saved, State.default_search_state)
        commit_projection(saved, repositories: [], local_repositories: [], account: { provider: provider })
        spawn_refresh_effect(config_path) if effects
        saved
      end

      def pin_repo(config_path, full_name, effects: true)
        mutate_repo_visibility(config_path, full_name, effects: effects) do |repo_list, normalized|
          repo_list[:hiddenRepositories].delete(normalized)
          repo_list[:pinnedRepositories] |= [normalized]
        end
      end

      def unpin_repo(config_path, full_name, effects: true)
        mutate_repo_visibility(config_path, full_name, effects: effects) do |repo_list, normalized|
          repo_list[:pinnedRepositories].delete(normalized)
        end
      end

      def hide_repo(config_path, full_name, effects: true)
        mutate_repo_visibility(config_path, full_name, effects: effects) do |repo_list, normalized|
          repo_list[:pinnedRepositories].delete(normalized)
          repo_list[:hiddenRepositories] |= [normalized]
        end
      end

      def show_repo(config_path, full_name, effects: true)
        mutate_repo_visibility(config_path, full_name, effects: effects) do |repo_list, normalized|
          repo_list[:hiddenRepositories].delete(normalized)
        end
      end

      def start_search(config_path, query, limit:, effects: true)
        config = Core::Config.load_config(config_path)
        clean_query = query.to_s.strip
        raise ArgumentError, "Search query required." if clean_query.empty?

        state = {
          status: "loading",
          query: clean_query,
          requestId: SecureRandom.hex(8),
          selectedFullName: "",
          results: [],
          error: "",
          updatedAt: timestamp
        }
        State.write_search_state(config, state)
        spawn_search_effect(config_path, clean_query, limit, state[:requestId]) if effects
        State.read_search_state(config)
      end

      def select_search_result(config_path, full_name)
        config = Core::Config.load_config(config_path)
        state = State.read_search_state(config)
        normalized = normalize_full_name(full_name)
        result = Array(state[:results]).find { |repo| repo[:fullName].to_s.downcase == normalized }
        raise ArgumentError, "Search result not found: #{full_name}" unless result

        state[:selectedFullName] = normalized
        state[:updatedAt] = timestamp
        State.write_search_state(config, state)
        State.read_search_state(config)
      end

      def finish_search(config_path, request_id, query, results: [], error: nil)
        config = Core::Config.load_config(config_path)
        current = State.read_search_state(config)
        return current if current[:requestId].to_s != request_id.to_s

        state = current.merge(
          status: error.to_s.empty? ? "ready" : "error",
          query: query.to_s,
          results: Array(results),
          error: error.to_s,
          selectedFullName: "",
          updatedAt: timestamp
        )
        State.write_search_state(config, state)
        State.read_search_state(config)
      end

      def commit_refresh(config, repositories, local_repositories, account)
        snapshot = State.build_snapshot(config, repositories, local_repositories, account)
        State.write_snapshot(config, snapshot)
        signal_waybar(config)
        snapshot
      end

      def refresh_effect(config_path)
        config = Core::Config.load_config(config_path)
        account = Core::GitHub.auth_status(config)
        repositories = Core::GitHub.fetch_repositories(config)
        local_repositories = Core::LocalGit.scan(config)
        repositories = Core::LocalGit.match_repositories(repositories, local_repositories)
        commit_refresh(config, repositories, local_repositories, account)
      end

      def search_effect(config_path, query, limit, request_id)
        config = Core::Config.load_config(config_path)
        rows = Core::GitHub.search_repositories(config, Core::GitHub.access_token(config), query, limit)
        finish_search(config_path, request_id, query, results: rows)
      rescue StandardError => e
        finish_search(config_path, request_id, query, error: e.message)
      end

      def spawn_refresh_effect(config_path)
        Core::Process.spawn_detached(repobar_executable, ["effect", "refresh", "--config", File.expand_path(config_path)])
      end

      def spawn_search_effect(config_path, query, limit, request_id)
        Core::Process.spawn_detached(repobar_executable, ["effect", "search", query, "--limit", limit.to_i.to_s, "--request-id", request_id, "--config", File.expand_path(config_path)])
      end

      def signal_waybar(config)
        signal = config.dig(:runtime, :waybarSignal).to_i
        return if signal <= 0

        Core::Process.run_command("pkill", ["-RTMIN+#{signal}", "waybar"])
      rescue StandardError
        nil
      end

      def mutate_repo_visibility(config_path, full_name, effects:)
        normalized = normalize_full_name(full_name)
        config = Core::Config.load_config(config_path)
        repo_list = config[:repoList]
        yield(repo_list, normalized)
        saved = Core::Config.save_config(config, config_path)
        project_repo_visibility(saved, normalized)
        spawn_refresh_effect(config_path) if effects
        saved[:repoList]
      end

      def project_repo_visibility(config, changed_full_name)
        previous = State.read_snapshot(config)
        repositories = Array(previous && previous[:repositories]).map { |repo| deep_dup(repo) }
        repositories = ensure_projected_repo(config, repositories, changed_full_name)
        hidden = Array(config.dig(:repoList, :hiddenRepositories))
        repositories.reject! { |repo| hidden.include?(repo[:fullName].to_s.downcase) }
        account = deep_dup(previous && previous[:account]) || {}
        account[:provider] = config.dig(:github, :provider)
        commit_projection(config, repositories: repositories, local_repositories: Array(previous && previous[:localRepositories]), account: account)
      end

      def ensure_projected_repo(config, repositories, full_name)
        pinned = Array(config.dig(:repoList, :pinnedRepositories))
        return repositories unless pinned.include?(full_name)
        return repositories if repositories.any? { |repo| repo[:fullName].to_s.downcase == full_name }

        search_repo = Array(State.read_search_state(config)[:results]).find { |repo| repo[:fullName].to_s.downcase == full_name }
        repositories.unshift((search_repo ? deep_dup(search_repo) : lightweight_repo(config, full_name)).merge(pending: true))
        repositories
      end

      def commit_projection(config, repositories:, local_repositories:, account:)
        snapshot = State.build_snapshot(config, repositories, local_repositories, account)
        State.write_snapshot(config, snapshot)
        signal_waybar(config)
        snapshot
      end

      def lightweight_repo(config, full_name)
        owner, name = full_name.split("/", 2)
        host = config.dig(:github, :host).to_s.sub(%r{/*\z}, "")
        {
          id: full_name,
          fullName: full_name,
          owner: owner,
          name: name,
          description: "Pending refresh",
          url: "#{host}/#{full_name}",
          private: false,
          fork: false,
          archived: false,
          updatedAt: Time.now.utc.iso8601,
          stats: {
            stars: 0,
            forks: 0,
            pushedAt: Time.now.utc.iso8601,
            openIssues: 0,
            openPulls: 0
          },
          ciStatus: "unknown",
          pending: true
        }
      end

      def normalize_full_name(full_name)
        text = full_name.to_s.strip.downcase
        raise ArgumentError, "Repository required as owner/name." unless text.match?(%r{\A[^/\s]+/[^/\s]+\z})

        text
      end

      def deep_dup(value)
        Marshal.load(Marshal.dump(value))
      end

      def timestamp
        Time.now.utc.iso8601(6)
      end

      def repobar_executable
        candidate = File.expand_path("../../../bin/repobar", __dir__)
        return candidate if File.executable?(candidate)

        "repobar"
      end
    end
  end
end
