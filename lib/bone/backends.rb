# frozen_string_literal: true

class Bone
  # Namespace for storage backends and the scheme -> backend registry.
  #
  # A backend is any object that responds to the storage contract used by
  # {Bone} and {Bone::Client}:
  #
  #   connect(uri)                     -> self
  #   generate                         -> [token, secret]
  #   register(token, secret)          -> token
  #   destroy(token, secret)           -> Boolean
  #   token?(token)                    -> Boolean
  #   secret(token)                    -> String, nil
  #   get(token, secret, name)         -> String, nil
  #   set(token, secret, name, value)  -> String
  #   delete(token, secret, name)      -> Boolean
  #   keys(token, secret)              -> Array<String>
  #   key?(token, secret, name)        -> Boolean
  #   all(token, secret)               -> Hash{String => String}
  #
  # Backends register themselves for one or more URI schemes so that
  # +Bone.source = 'redis://...'+ selects the matching implementation.
  module Backends
    @registry = {}

    class << self
      # @return [Hash{Symbol => #connect}] scheme -> backend
      attr_reader :registry

      # Register +backend+ for one or more URI +schemes+.
      def register(backend, *schemes)
        schemes.each { |scheme| registry[scheme.to_sym] = backend }
        backend
      end

      # Look up the backend for a URI scheme, or nil.
      def for(scheme)
        registry[scheme.to_sym]
      end
    end
  end
end

require_relative 'backends/memory'
require_relative 'backends/redis'
