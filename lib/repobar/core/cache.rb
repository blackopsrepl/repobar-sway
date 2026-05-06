# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "time"

module RepoBar
  module Core
    module Cache
      module_function

      def cache_dir(config)
        File.join(File.expand_path(config.dig(:runtime, :stateDir)), "cache")
      end

      def rest_path(config)
        File.join(cache_dir(config), "rest.json")
      end

      def graphql_path(config)
        File.join(cache_dir(config), "graphql.json")
      end

      def rate_limits_path(config)
        File.join(cache_dir(config), "rate_limits.json")
      end

      def rest_entry(config, uri, ttl_seconds: nil)
        entry = read_json(rest_path(config))[key(uri)]
        return nil unless entry
        return entry unless ttl_seconds

        fetched = Format.parse_time(entry["fetchedAt"] || entry[:fetchedAt])
        return nil unless fetched && fetched > Time.now.utc - ttl_seconds

        entry
      end

      def write_rest_entry(config, uri, status:, headers:, body:)
        update_json(rest_path(config)) do |data|
          data[key(uri)] = {
            url: uri.to_s,
            status: status,
            headers: headers,
            body: safe_text(body),
            fetchedAt: Time.now.utc.iso8601
          }
        end
        write_rate_limit(config, headers, uri)
      end

      def graphql_entry(config, cache_key, ttl_seconds:)
        entry = read_json(graphql_path(config))[cache_key]
        return nil unless entry

        fetched = Format.parse_time(entry["fetchedAt"] || entry[:fetchedAt])
        return nil unless fetched && fetched > Time.now.utc - ttl_seconds

        entry
      end

      def write_graphql_entry(config, cache_key, body:)
        update_json(graphql_path(config)) do |data|
          data[cache_key] = {
            body: safe_text(body),
            fetchedAt: Time.now.utc.iso8601
          }
        end
      end

      def write_rate_limit(config, headers, uri)
        resource = headers["x-ratelimit-resource"] || "default"
        return unless headers["x-ratelimit-limit"] || headers["x-ratelimit-remaining"]

        update_json(rate_limits_path(config)) do |data|
          data[resource] = {
            url: uri.to_s,
            limit: headers["x-ratelimit-limit"]&.to_i,
            remaining: headers["x-ratelimit-remaining"]&.to_i,
            used: headers["x-ratelimit-used"]&.to_i,
            resetAt: headers["x-ratelimit-reset"] ? Time.at(headers["x-ratelimit-reset"].to_i).utc.iso8601 : nil,
            observedAt: Time.now.utc.iso8601
          }
        end
      end

      def summary(config, limit: 10)
        rest = read_json(rest_path(config))
        graphql = read_json(graphql_path(config))
        rate_limits = read_json(rate_limits_path(config))
        {
          cacheDir: cache_dir(config),
          restResponseCount: rest.length,
          graphQLResponseCount: graphql.length,
          rateLimitCount: rate_limits.length,
          latestResponses: rest.values.sort_by { |entry| entry["fetchedAt"].to_s }.last(limit),
          rateLimits: rate_limits
        }
      end

      def clear(config)
        FileUtils.rm_f(rest_path(config))
        FileUtils.rm_f(graphql_path(config))
        FileUtils.rm_f(rate_limits_path(config))
        summary(config)
      end

      def key(value)
        Digest::SHA256.hexdigest(value.to_s)
      end

      def safe_text(value)
        value.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      end

      def read_json(path)
        return {} unless File.file?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end

      def update_json(path)
        FileUtils.mkdir_p(File.dirname(path))
        data = read_json(path)
        yield data
        temp = "#{path}.tmp.#{$$}"
        File.write(temp, "#{JSON.pretty_generate(data)}\n")
        File.chmod(0o600, temp)
        File.rename(temp, path)
        File.chmod(0o600, path)
      ensure
        FileUtils.rm_f(temp) if temp && File.exist?(temp)
      end
    end
  end
end
