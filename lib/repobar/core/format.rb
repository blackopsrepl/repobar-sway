# frozen_string_literal: true

require "time"

module RepoBar
  module Core
    module Format
      module_function

      def relative_time(value, now = Time.now)
        time = parse_time(value)
        return "unknown" unless time

        seconds = [(now - time).to_i, 0].max
        return "#{seconds}s ago" if seconds < 60

        minutes = seconds / 60
        return "#{minutes}m ago" if minutes < 60

        hours = minutes / 60
        return "#{hours}h ago" if hours < 48

        days = hours / 24
        return "#{days}d ago" if days < 60

        time.strftime("%Y-%m-%d")
      end

      def parse_time(value)
        return value if value.is_a?(Time)
        return nil if value.to_s.strip.empty?

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def repo_line(repo)
        stats = repo.fetch(:stats, {})
        local = repo[:local]
        local_text = if local
                       branch = local[:branch].to_s.empty? ? "detached" : local[:branch]
                       dirty = local[:dirtyCount].to_i.positive? ? " dirty=#{local[:dirtyCount]}" : ""
                       " #{branch}#{dirty}"
                     else
                       ""
                     end
        format(
          "%-36s issues=%-3d prs=%-3d ci=%-8s stars=%-5d updated=%s%s",
          repo[:fullName],
          stats[:openIssues].to_i,
          stats[:openPulls].to_i,
          repo[:ciStatus] || "unknown",
          stats[:stars].to_i,
          relative_time(stats[:pushedAt] || repo[:updatedAt]),
          local_text
        )
      end
    end
  end
end
