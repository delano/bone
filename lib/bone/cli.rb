# frozen_string_literal: true

require 'dry/cli'
require_relative '../bone'

class Bone
  # Command-line interface for Bone, built on Dry::CLI.
  #
  # Loaded lazily by `exe/bone` so that `require 'bone'` does not pull in
  # dry-cli for library-only users.
  module CLI
    extend Dry::CLI::Registry

    # Shared option plumbing: source/token/secret resolution and a bound
    # ambient client, so every command reads credentials the same way.
    module Common
      def self.included(base)
        base.class_eval do
          option :source, desc: 'Backend source URI (overrides $BONE_SOURCE)'
          option :token,  desc: 'Bone token (overrides $BONE_TOKEN)'
          option :secret, desc: 'Bone secret (overrides $BONE_SECRET)'
        end
      end

      # Apply global-ish options to Bone before running a command.
      def configure(options)
        Bone.source = options[:source] if options[:source]
        Bone.token = options[:token] if options[:token]
        Bone.secret = options[:secret] if options[:secret]
      end

      def abort_with(message)
        warn message
        exit 1
      end
    end

    class Version < Dry::CLI::Command
      desc 'Print the Bone version'

      def call(**)
        puts "Bone #{Bone::VERSION}"
      end
    end

    class Generate < Dry::CLI::Command
      include Common

      desc 'Generate a new token/secret pair'

      def call(**options)
        configure(options)
        token, secret = Bone.generate
        puts "# Your token for #{Bone.source}"
        puts "BONE_TOKEN=#{token}"
        puts "BONE_SECRET=#{secret}"
      end
    end

    class Get < Dry::CLI::Command
      include Common

      desc 'Get the value for a key'
      argument :name, required: true, desc: 'Key name'

      def call(name:, **options)
        configure(options)
        value = Bone[name]
        puts value unless value.nil?
      end
    end

    class Set < Dry::CLI::Command
      include Common

      desc 'Set a key to a value (reads STDIN when no value is given)'
      argument :name, required: true, desc: 'Key name'
      argument :value, required: false, desc: 'Value (or pipe via STDIN)'

      def call(name:, value: nil, **options)
        configure(options)
        value = $stdin.read if value.nil? && !$stdin.tty?
        abort_with('No value given') if value.nil?
        puts Bone[name] = value
      end
    end

    class Delete < Dry::CLI::Command
      include Common

      desc 'Delete a key'
      argument :name, required: true, desc: 'Key name'

      def call(name:, **options)
        configure(options)
        Bone.delete(name)
      end
    end

    class Keys < Dry::CLI::Command
      include Common

      desc 'List keys (optionally filtered by a glob)'
      argument :filter, required: false, desc: 'Glob filter, e.g. "DB_*"'

      def call(filter: nil, **options)
        configure(options)
        list = Bone.keys(filter)
        puts(list.empty? ? '# no keys' : list)
      end
    end

    class EnvCmd < Dry::CLI::Command
      include Common

      desc 'Print all variables as KEY=value (dotenv format)'

      def call(**options)
        configure(options)
        print Bone.dump
      end
    end

    class Export < Dry::CLI::Command
      include Common

      desc 'Print all variables as shell `export` lines: eval "$(bone export)"'

      def call(**options)
        configure(options)
        print Bone.export
      end
    end

    class Import < Dry::CLI::Command
      include Common

      desc 'Import variables from a dotenv file (or STDIN)'
      argument :file, required: false, desc: 'Path to a .env file (default: STDIN)'

      def call(file: nil, **options)
        configure(options)
        text = file ? File.read(file) : $stdin.read
        names = Bone.import(text)
        warn "Imported #{names.size} variable(s): #{names.join(', ')}"
      end
    end

    register 'version', Version, aliases: %w[-v --version]
    register 'generate', Generate
    register 'get', Get
    register 'set', Set
    register 'delete', Delete, aliases: %w[del rm]
    register 'keys', Keys
    register 'env', EnvCmd
    register 'export', Export
    register 'import', Import
  end
end
