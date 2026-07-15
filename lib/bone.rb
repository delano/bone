# frozen_string_literal: true

require 'securerandom'
require 'uri'

require_relative 'bone/version'
require_relative 'bone/errors'
require_relative 'bone/env'
require_relative 'bone/backends'

# Bone — a small client for remote key/value storage, used here as a store of
# remote environment variables for services such as staging.
#
# A {Bone} instance is a *client* bound to a token (and optional secret). The
# token namespaces a bag of variables in the configured backend
# (`memory://` or `redis://`/`valkey://`). Class-level methods operate through
# an ambient client built from +Bone.token+ / +Bone.secret+ (which default to
# the +BONE_TOKEN+ / +BONE_SECRET+ environment variables).
#
# @example Library usage
#   Bone.source = 'redis://127.0.0.1:6379/0'
#   token, secret = Bone.generate
#   Bone.credentials = "#{token}:#{secret}"
#   Bone[:database_url] = 'postgres://…'
#   Bone[:database_url]        # => "postgres://…"
#   Bone.env                   # => { "database_url" => "postgres://…" }
class Bone
  DEFAULT_SOURCE = 'redis://127.0.0.1:6379/0'

  # Characters used when generating tokens (unambiguous alphanumerics).
  TOKEN_ALPHABET = [*'A'..'Z', *'a'..'z', *'0'..'9'].freeze

  class << self
    attr_writer :token, :secret

    # -- configuration -----------------------------------------------------

    # @return [URI] the current source (defaults to $BONE_SOURCE or Redis).
    def source
      @source ||= URI.parse(ENV['BONE_SOURCE'] || DEFAULT_SOURCE)
    end

    # Set the source and (re)select the matching backend.
    # @param value [String, URI]
    def source=(value)
      @source = value.is_a?(URI) ? value : URI.parse(value.to_s)
      select_backend
    end
    alias src source
    alias src= source=

    # @return [#connect] the backend for the current source.
    def backend
      @backend ||= select_backend
    end

    def select_backend
      scheme = source.scheme.to_s
      klass = Backends.for(scheme)
      raise UnknownBackend, "No backend for #{scheme.inspect} (#{source})" if klass.nil?

      @backend = klass.connect(source)
    end

    # -- credentials -------------------------------------------------------

    def token
      @token || ENV.fetch('BONE_TOKEN', nil)
    end

    def secret
      @secret || ENV.fetch('BONE_SECRET', nil)
    end

    # Accept a combined "token:secret" credential string.
    def credentials=(pair)
      @token, @secret = pair.to_s.split(':', 2)
    end
    alias cred= credentials=

    # Build a client. Defaults to the ambient token/secret.
    def new(token = self.token, secret = self.secret)
      Client.new(token, secret)
    end

    # -- token lifecycle ---------------------------------------------------

    # @return [Array(String, String)] a freshly generated [token, secret].
    def generate
      backend.generate
    end

    def register(token, secret)
      backend.register(token, secret)
    end

    def destroy(token = self.token, secret = self.secret)
      backend.destroy(token, secret)
    end

    def token?(token = self.token)
      return false if token.nil?

      backend.token?(token)
    end

    # -- ambient-client delegation ----------------------------------------

    def get(name)
      new.get(name)
    end
    alias [] get

    def set(name, value)
      new.set(name, value)
    end
    alias []= set

    def delete(name)
      new.delete(name)
    end

    def key?(name)
      new.key?(name)
    end

    def keys(filter = nil)
      new.keys(filter)
    end

    # Remote environment variables for the ambient token.
    def env
      new.to_h
    end

    def export
      Env.export(env)
    end

    def dump
      Env.dump(env)
    end

    def import(source)
      new.import(source)
    end

    # Load all of the token's variables into ENV. Returns the names loaded.
    def load_env!
      new.load_env!
    end

    # -- crypto / token helpers -------------------------------------------

    def random_token(length = 26)
      SecureRandom.alphanumeric(length)
    end

    def random_secret(bytes = 48)
      SecureRandom.urlsafe_base64(bytes)
    end
  end

  # A client bound to a token/secret pair. Instances are what actually read
  # and write variables; the class-level API delegates here.
  class Client
    attr_reader :token, :secret

    def initialize(token = nil, secret = nil)
      @token  = token
      @secret = secret
    end

    def get(name)
      backend.get(require_token!, secret, name)
    end
    alias [] get

    def set(name, value)
      backend.set(require_token!, secret, name, value)
    end
    alias []= set

    def delete(name)
      backend.delete(require_token!, secret, name)
    end

    def key?(name)
      backend.key?(require_token!, secret, name)
    end

    # All variable names, optionally filtered by a glob (e.g. "DB_*").
    def keys(filter = nil)
      names = backend.keys(require_token!, secret)
      return names if filter.nil? || filter.to_s.empty? || filter.to_s == '*'

      names.select { |name| File.fnmatch(filter.to_s, name) }
    end

    # @return [Hash{String => String}] all variables for this token.
    def to_h
      backend.all(require_token!, secret)
    end
    alias env to_h

    # Import variables from a Hash or dotenv-style String. Returns the names
    # written.
    def import(source)
      vars = source.is_a?(Hash) ? source : Bone::Env.parse(source)
      vars.each { |name, value| set(name, value) }
      vars.keys.map(&:to_s)
    end

    # Copy every stored variable into the process ENV. Returns names loaded.
    def load_env!
      to_h.each { |name, value| ENV[name] = value }.keys
    end

    def export
      Bone::Env.export(to_h)
    end

    def dump
      Bone::Env.dump(to_h)
    end

    private

    def backend
      Bone.backend
    end

    def require_token!
      raise Bone::NoToken, 'No token set (see Bone.credentials= or $BONE_TOKEN)' if token.nil? || token.to_s.empty?

      token
    end
  end
end
