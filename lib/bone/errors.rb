# frozen_string_literal: true

class Bone
  # Base class for all Bone errors.
  class Problem < RuntimeError; end

  # Raised when an operation needs credentials but none are available.
  class NoToken < Problem; end

  # Raised when the configured source scheme has no registered backend.
  class UnknownBackend < Problem; end

  # Raised when a token is already registered.
  class TokenExists < Problem; end
end
