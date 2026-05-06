# frozen_string_literal: true

module RepoBar
  module Runtime
    module Daemon
      module_function

      def run(config_path, once: false)
        config = Core::Config.load_config(config_path)
        return refresh(config_path, config: config) if once

        lock = State.acquire_daemon_lock(config)
        raise "repobar daemon already running for #{State.state_dir(config)}." unless lock

        refresh(config_path, config: config)
        loop do
          sleep(config.dig(:runtime, :refreshSeconds).to_i)
          config = Core::Config.load_config(config_path)
          refresh(config_path, config: config)
        rescue StandardError => e
          warn "repobar daemon refresh error: #{e.message}"
        end
      ensure
        lock&.close
      end

      def refresh(config_path, config: nil)
        config ||= Core::Config.load_config(config_path)
        snapshot = nil
        State.with_refresh_lock(config) do
          account = Core::GitHub.auth_status(config)
          repositories = Core::GitHub.fetch_repositories(config)
          local_repositories = Core::LocalGit.scan(config)
          repositories = Core::LocalGit.match_repositories(repositories, local_repositories)
          snapshot = State.build_snapshot(config, repositories, local_repositories, account)
          State.write_snapshot(config, snapshot)
        end
        signal_waybar(config)
        snapshot
      end

      def signal_waybar(config)
        signal = config.dig(:runtime, :waybarSignal).to_i
        return if signal <= 0

        Core::Process.run_command("pkill", ["-RTMIN+#{signal}", "waybar"])
      rescue StandardError
        nil
      end
    end
  end
end
