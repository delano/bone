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

  # Raised when a variable name is not a valid shell/env identifier (does not
  # match Bone::Env::NAME). Guards the eval-able output of `export`/`dump`
  # against shell injection via crafted key names.
  class InvalidName < Problem; end
end
