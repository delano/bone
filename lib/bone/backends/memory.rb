# frozen_string_literal: true

class Bone
  module Backends
    # In-memory backend. Data lives for the life of the process only.
    #
    # Useful for tests and for `memory://` sources. Values are stored as
    # strings, mirroring the semantics of the persistent backends.
    module Memory
      extend self

      # token => { secret: String, vars: { name => value } }
      @store = {}

      # Reset all in-memory state. Test helper; not part of the backend
      # contract.
      def reset!
        @store = {}
        self
      end

      def connect(_uri = nil)
        @store ||= {}
        self
      end

      def generate
        token = Bone.random_token
        token = Bone.random_token while @store.key?(token)
        secret = Bone.random_secret
        @store[token] = { secret: secret, vars: {} }
        [token, secret]
      end

      def register(token, secret)
        token = token.to_s
        raise Bone::TokenExists, token if @store.key?(token)

        @store[token] = { secret: secret.to_s, vars: {} }
        token
      end

      def destroy(token, _secret = nil)
        !@store.delete(token.to_s).nil?
      end

      def token?(token)
        @store.key?(token.to_s)
      end

      def secret(token)
        @store.dig(token.to_s, :secret)
      end

      def get(token, _secret, name)
        vars_or_empty(token)[name.to_s]
      end

      def set(token, _secret, name, value)
        require_vars(token)[name.to_s] = value.to_s
      end

      def delete(token, _secret, name)
        !vars_or_empty(token).delete(name.to_s).nil?
      end

      def keys(token, _secret)
        vars_or_empty(token).keys
      end

      def key?(token, _secret, name)
        vars_or_empty(token).key?(name.to_s)
      end

      def all(token, _secret)
        vars_or_empty(token).dup
      end

      private

      # Non-raising read path: an unknown token yields an empty bag, so reads
      # return the benign defaults the backend contract promises (nil / [] /
      # false / {}) — matching the Redis backend. See F4/F5 in the 2026-07 audit.
      def vars_or_empty(token)
        entry = @store[token.to_s]
        entry ? entry[:vars] : {}
      end

      # Raising write path: writing to an unknown token is an error on both
      # backends (mirrors Redis's require_token).
      def require_vars(token)
        entry = @store[token.to_s]
        raise Bone::NoToken, token.to_s if entry.nil?

        entry[:vars]
      end

      Bone::Backends.register self, :memory
    end
  end
end
