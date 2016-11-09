module Eurotas
  class App < Sinatra::Base
    MissingEnvironmentVariableError = Class.new(StandardError)

    def self.validate_envs(*args)
      args.each { |ev| raise MissingEnvironmentVariableError, "You must set #{ev}" if ENV[ev.to_s].nil? || ENV[ev.to_s].empty? }
    end

    configure do
      validate_envs :GITHUB_WEBHOOK_SECRET, :DESTINATION_REPO, :FOLDER_MAP, :GITHUB_USERNAME, :GITHUB_PASSWORD
    end

    # Respond to Get requests
    get '/' do
      content_type 'text/plain'
      status 400; "Bad Request"
    end

    # Handle the webhook
    post '/' do
      request.body.rewind
      payload_body = request.body.read
      verify_signature(payload_body)
      push = JSON.parse(payload_body)

      source_repo_name = push["repository"]["name"]
      source_repo_fullname = push["repository"]["full_name"]
      source_repo_clone_url = "https://#{ENV['GITHUB_USERNAME']}:#{ENV['GITHUB_PASSWORD']}@github.com/#{source_repo_fullname}.git"

      dest_repo_fullname = ENV['DESTINATION_REPO']
      dest_repo_name = ENV['DESTINATION_REPO'].split('/').last
      dest_repo_clone_url = "https://#{ENV['GITHUB_USERNAME']}:#{ENV['GITHUB_PASSWORD']}@github.com/#{dest_repo_fullname}.git"

      tmp_dir = File.join(Dir.tmpdir, "eurotas-" + SecureRandom.uuid)
      folder_map = Regexp.new ENV['FOLDER_MAP'].sub(/^\//, '').sub(/\/$/, '') # Makes leading and trailing slashes optional

      dest_local_path = File.join tmp_dir, dest_repo_name
      source_local_path = File.join tmp_dir, source_repo_name

      # Setup
      exec_commands([
        "mkdir #{tmp_dir}",
        "git clone #{dest_repo_clone_url} #{dest_local_path}",
        "git clone #{source_repo_clone_url} #{source_local_path}",
        "rm -rdf #{dest_local_path}/*/",
        "git config --global user.name Eurotas",
        "git config --global user.email eurotas@spartaglobal.com",
      ])

      # Do the copy
      exec_commands(build_copy_command(folder_map: folder_map, source: source_local_path, destination: dest_local_path))

      # Commit and push if there is something to commit.
      if `git -C #{dest_local_path} status`.match('nothing to commit, working tree clean')
        puts 'Nothing to commit'
        @webhook_response = {status: 200, message: 'Nothing to update'}
      else
        puts 'Committing and pushing'
        exec_commands([
          "git -C #{dest_local_path} add -A && git -C #{dest_local_path} commit -m 'Eurotas: Updating startercode'",
          "git -C #{dest_local_path} push origin master"
        ])
        @webhook_response = {status: 200, message: "Updated Starter Code:\n\n\n#{`git -C #{dest_local_path} log -1 --pretty=oneline -p`}"}
      end

      # Cleanup
      exec_commands([
        "rm -rf #{tmp_dir}"
      ])

      # Respond to webhook
      content_type 'text/plain'
      status @webhook_response[:status]
      body @webhook_response[:message]
    end

    def verify_signature(payload_body)
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_WEBHOOK_SECRET'], payload_body)
      return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
    end

    def exec_commands(commands_array)
      commands_array.each do |c|
        # Redact password for printing
        if c.include? ENV['GITHUB_PASSWORD']
          log_cmd = c.gsub(ENV['GITHUB_PASSWORD'], '*' * ENV['GITHUB_PASSWORD'].size)
        end
        puts "Execute: #{log_cmd || c}"
        `#{c}`
      end
    end

    def build_copy_command(params)
      raise ArgumentError unless params[:folder_map] && params[:source] && params[:destination]
      commands = []
      Dir.glob("#{params[:source]}/**/*/").each do |path|
        match = path.match params[:folder_map]
        if match
          dest_path = File.join(params[:destination], match.captures)
          commands << "mkdir -p #{dest_path} && cp -rf #{path}. #{dest_path}"
        end
      end
      commands
    end
  end
end
