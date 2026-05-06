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
          snapshot = Store.refresh_effect(config_path)
        end
        snapshot
      end

      def signal_waybar(config)
        Store.signal_waybar(config)
      end
    end
  end
end
