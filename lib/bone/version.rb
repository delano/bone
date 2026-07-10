# frozen_string_literal: true

class Bone
  # Version information for Bone.
  #
  # Exposed as a module (rather than a bare constant) so that both
  # +Bone::VERSION.to_s+ and +Bone::VERSION.to_a+ are available and the
  # gemspec can read the version without loading the rest of the library.
  module VERSION
    MAJOR = 0
    MINOR = 4
    PATCH = 0

    class << self
      def to_a
        [MAJOR, MINOR, PATCH]
      end

      def to_s
        to_a.join('.')
      end
      alias inspect to_s
    end
  end
end
