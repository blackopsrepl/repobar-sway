# frozen_string_literal: true

require "json"

module RepoBar
  module Runtime
    module Waybar
      module_function

      def render(config_path, out: $stdout)
        config = Core::Config.load_config(config_path)
        snapshot = State.read_snapshot(config)
        out.puts(JSON.generate(payload(config, snapshot)))
      end

      def payload(config, snapshot, now = Time.now)
        if snapshot.nil?
          provider = config.dig(:github, :provider).to_s == "forgejo" ? "FJ" : "GH"
          return {
            text: "#{provider} ...",
            tooltip: "RepoBar is waiting for cached data.\nMiddle click: refresh",
            class: ["repobar", "loading"]
          }
        end

        view = snapshot[:view] || Presenter.build_snapshot_view(config, snapshot, now)
        chip = view[:chip] || {}
        {
          text: chip[:text] || (config.dig(:github, :provider).to_s == "forgejo" ? "FJ" : "GH"),
          tooltip: Array(chip[:tooltipLines]).join("\n"),
          class: Array(chip[:classes]).uniq
        }
      end
    end
  end
end
