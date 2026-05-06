# frozen_string_literal: true

module RepoBar
  module Core
    module Process
      module_function

      Result = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
        def success?
          status.to_i.zero?
        end
      end

      def run_command(command, args = [], env: {}, stdin_data: nil)
        require "open3"

        stdout, stderr, status = Open3.capture3(env, command, *args, stdin_data: stdin_data)
        Result.new(stdout: stdout, stderr: stderr, status: status.exitstatus)
      end

      def run_text(command, args = [], env: {})
        result = run_command(command, args, env: env)
        return result.stdout if result.success?

        raise "#{command} #{args.join(' ')} failed: #{result.stderr.strip}"
      end

      def spawn_detached(command, args = [], env: {}, cwd: nil)
        options = { out: File::NULL, err: File::NULL }
        options[:chdir] = cwd if cwd
        pid = ::Process.spawn(env, command, *args, **options)
        ::Process.detach(pid)
        pid
      end
    end
  end
end
