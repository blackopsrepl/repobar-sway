# frozen_string_literal: true

require "find"

module RepoBar
  module Core
    module LocalGit
      module_function

      def scan(config)
        roots = Array(config.dig(:localProjects, :roots))
        max_depth = config.dig(:localProjects, :maxDepth).to_i
        roots.flat_map { |root| scan_root(File.expand_path(root), max_depth) }
          .uniq { |repo| repo[:path] }
      end

      def resolve_target(config, target)
        text = target.to_s.strip
        raise ArgumentError, "Local repository target required." if text.empty?

        expanded = File.expand_path(text)
        return expanded if Dir.exist?(File.join(expanded, ".git")) || File.file?(File.join(expanded, ".git"))

        match = scan(config).find do |repo|
          repo[:fullName].to_s.casecmp?(text) || File.basename(repo[:path]).casecmp?(text)
        end
        raise ArgumentError, "Local repository not found: #{target}" unless match

        match[:path]
      end

      def sync(path)
        before = git(path, ["rev-parse", "HEAD"]).strip
        fetch_output = git(path, ["fetch", "--prune"])
        ahead, behind = ahead_behind(path)
        pull_output = ""
        push_output = ""
        pull_output = git(path, ["pull", "--ff-only"]) if behind.positive? && clean?(path)
        ahead_after, = ahead_behind(path)
        push_output = git(path, ["push"]) if ahead_after.positive? && clean?(path)
        after = git(path, ["rev-parse", "HEAD"]).strip
        {
          path: path,
          didFetch: true,
          didPull: !pull_output.empty?,
          didPush: !push_output.empty?,
          changed: before != after,
          output: [fetch_output, pull_output, push_output].reject(&:empty?).join("\n")
        }
      end

      def rebase(path)
        git(path, ["fetch", "--prune"])
        output = git(path, ["rebase", "@{u}"])
        { path: path, output: output }
      end

      def hard_reset(path)
        git(path, ["fetch", "--prune"])
        output = git(path, ["reset", "--hard", "@{u}"])
        { path: path, output: output }
      end

      def branches(path)
        current = git(path, ["branch", "--show-current"]).strip
        git(path, ["for-each-ref", "--format=%(refname:short)|%(committerdate:iso8601)|%(objectname:short)", "refs/heads"]).lines.map do |line|
          name, date, sha = line.chomp.split("|", 3)
          {
            name: name,
            current: name == current,
            updatedAt: date,
            sha: sha
          }
        end
      end

      def worktrees(path)
        git(path, ["worktree", "list", "--porcelain"]).split(/\n\n+/).filter_map do |block|
          fields = block.lines.map(&:chomp)
          tree = fields.find { |line| line.start_with?("worktree ") }&.split(" ", 2)&.last
          next unless tree

          {
            path: tree,
            branch: fields.find { |line| line.start_with?("branch ") }&.split(" ", 2)&.last&.sub(%r{\Arefs/heads/}, ""),
            sha: fields.find { |line| line.start_with?("HEAD ") }&.split(" ", 2)&.last,
            bare: fields.include?("bare"),
            detached: fields.include?("detached")
          }
        end
      end

      def clone(config, full_name, destination: nil)
        host = config.dig(:github, :host).to_s.sub(%r{/*\z}, "")
        root = Array(config.dig(:localProjects, :roots)).first || Dir.pwd
        destination ||= File.join(root, File.basename(full_name))
        url = "#{host}/#{full_name}.git"
        output = Core::Process.run_text("git", ["clone", url, destination])
        { fullName: full_name, url: url, path: destination, output: output }
      end

      def scan_root(root, max_depth)
        return [] unless Dir.exist?(root)

        repos = []
        root_depth = depth(root)
        Find.find(root) do |path|
          basename = File.basename(path)
          if File.directory?(path)
            if basename.start_with?(".") && path != root
              Find.prune
              next
            end
            Find.prune if depth(path) - root_depth > max_depth
          end

          next unless File.basename(path) == ".git"

          repo_path = File.dirname(path)
          repos << status(repo_path)
          Find.prune
        end
        repos.compact
      end

      def status(path)
        full_name = remote_full_name(path)
        branch = git(path, ["branch", "--show-current"]).strip
        porcelain = git(path, ["status", "--porcelain"]).lines.map(&:chomp)
        ahead, behind = ahead_behind(path)
        {
          path: path,
          fullName: full_name,
          branch: branch,
          dirty: porcelain.any?,
          dirtyCount: porcelain.length,
          dirtyFiles: porcelain.first(3).map { |line| line[3..] }.compact,
          ahead: ahead,
          behind: behind,
          detached: branch.empty?
        }
      rescue StandardError
        nil
      end

      def remote_full_name(path)
        remote = git(path, ["config", "--get", "remote.origin.url"]).strip
        parse_remote(remote)
      rescue StandardError
        nil
      end

      def parse_remote(remote)
        text = remote.to_s.strip
        return nil if text.empty?

        if text =~ %r{github\.com[:/](?<owner>[^/]+)/(?<name>[^/.]+)(?:\.git)?\z}
          "#{Regexp.last_match[:owner]}/#{Regexp.last_match[:name]}".downcase
        elsif text =~ %r{\Assh://git@[^/]+/(?<owner>[^/]+)/(?<name>[^/.]+)(?:\.git)?\z}
          "#{Regexp.last_match[:owner]}/#{Regexp.last_match[:name]}".downcase
        elsif text =~ %r{\Agit@[^:]+:(?<owner>[^/]+)/(?<name>[^/.]+)(?:\.git)?\z}
          "#{Regexp.last_match[:owner]}/#{Regexp.last_match[:name]}".downcase
        elsif text =~ %r{\Ahttps?://[^/]+/(?<owner>[^/]+)/(?<name>[^/.]+)(?:\.git)?\z}
          "#{Regexp.last_match[:owner]}/#{Regexp.last_match[:name]}".downcase
        end
      end

      def ahead_behind(path)
        upstream = git(path, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]).strip
        return [0, 0] if upstream.empty?

        counts = git(path, ["rev-list", "--left-right", "--count", "HEAD...#{upstream}"]).split.map(&:to_i)
        [counts[0].to_i, counts[1].to_i]
      rescue StandardError
        [0, 0]
      end

      def clean?(path)
        git(path, ["status", "--porcelain"]).strip.empty?
      end

      def match_repositories(repositories, local_repos)
        by_full_name = local_repos.each_with_object({}) do |repo, output|
          output[repo[:fullName]] = repo if repo[:fullName]
        end
        repositories.map do |repo|
          local = by_full_name[repo[:fullName].to_s.downcase]
          local ||= local_repos.find { |candidate| File.basename(candidate[:path]).casecmp?(repo[:name].to_s) }
          local ? repo.merge(local: local) : repo
        end
      end

      def git(path, args)
        Core::Process.run_text("git", ["-C", path] + args)
      end

      def depth(path)
        File.expand_path(path).split(File::SEPARATOR).length
      end
    end
  end
end
