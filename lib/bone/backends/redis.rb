# frozen_string_literal: true

class Bone
  module Backends
    # Valkey/Redis backend built on Familia v2 (Familia::Horreum).
    #
    # Each token is a small Horreum record holding its secret plus a Redis
    # hash of remote variables (`vars`). This maps a token directly onto a
    # namespaced bag of key/value pairs — exactly the shape needed for a
    # remote environment-variable store.
    #
    # Familia and its Token model are required/defined lazily on first
    # {connect} so that `memory://` users never need Familia installed.
    module Redis
      extend self

      # Point Familia at +uri+ and make sure the Token model exists.
      #
      # Familia connects lazily via +Familia.dbclient+, so setting the URI
      # is all that is required here.
      def connect(uri)
        require 'familia' unless defined?(::Familia)
        ::Familia.uri = uri.to_s
        define_model! unless const_defined?(:Token)
        self
      end

      def generate
        token  = unique_token
        secret = Bone.random_secret
        model.new(token: token, secret: secret).save
        [token, secret]
      end

      def register(token, secret)
        token = token.to_s
        raise Bone::TokenExists, token if model.exists?(token)

        model.new(token: token, secret: secret.to_s).save
        token
      end

      def destroy(token, _secret = nil)
        obj = model.load(token.to_s)
        return false if obj.nil?

        obj.vars.clear
        obj.destroy!
        true
      end

      def token?(token)
        model.exists?(token.to_s)
      end

      def secret(token)
        model.load(token.to_s)&.secret
      end

      def get(token, _secret, name)
        obj = model.load(token.to_s)
        obj && obj.vars[name.to_s]
      end

      def set(token, _secret, name, value)
        require_token(token).vars[name.to_s] = value.to_s
        value.to_s
      end

      def delete(token, _secret, name)
        obj = model.load(token.to_s)
        return false if obj.nil?

        obj.vars.remove(name.to_s).to_i.positive?
      end

      def keys(token, _secret)
        obj = model.load(token.to_s)
        obj ? obj.vars.keys : []
      end

      def key?(token, _secret, name)
        obj = model.load(token.to_s)
        obj ? obj.vars.key?(name.to_s) : false
      end

      def all(token, _secret)
        obj = model.load(token.to_s)
        obj ? obj.vars.all : {}
      end

      # @return [Class] the lazily-defined Familia::Horreum Token model
      def model
        const_defined?(:Token) ? const_get(:Token) : define_model!
      end

      private

      def require_token(token)
        obj = model.load(token.to_s)
        raise Bone::NoToken, token.to_s if obj.nil?

        obj
      end

      def unique_token
        token = Bone.random_token
        token = Bone.random_token while model.exists?(token)
        token
      end

      # Define Bone::Backends::Redis::Token as a named (non-anonymous)
      # Horreum subclass. Named so Familia's member registry and dbkey
      # generation get a stable config name.
      def define_model!
        klass = Class.new(::Familia::Horreum) do
          identifier_field :token
          field :token
          field :secret
          hashkey :vars
        end
        const_set(:Token, klass)
      end

      Bone::Backends.register self, :redis, :rediss, :valkey
    end
  end
end
