# frozen_string_literal: true

class Bone
  # Helpers for treating a token's stored keys as remote environment
  # variables: parsing dotenv-style input and rendering shell/dotenv output.
  #
  # These are pure functions over hashes and strings; they perform no I/O and
  # never touch a backend. {Bone} and {Bone::Client} wire them to storage.
  module Env
    # A valid variable name: a POSIX shell / env identifier. Names are
    # validated against this at the write boundary and again before being
    # emitted, so a crafted name can never inject shell into eval-able output.
    # Keep in sync with the name sub-pattern in LINE below.
    NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/
    LINE = /\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*\z/
    NEEDS_DQUOTE = %r{[^A-Za-z0-9_./@%+=:,-]}

    module_function

    # @return [Boolean] whether +name+ is a valid variable name (matches NAME).
    #   Callers validate at the write boundary so unsafe names never reach the
    #   store, and thus never reach eval-able `export`/`dump` output.
    def valid_name?(name)
      name.to_s.match?(NAME)
    end

    # Parse dotenv-style text into a { name => value } hash.
    #
    # Understands blank lines, `#` comments, an optional leading `export`,
    # and single- or double-quoted values (double quotes honour \n, \t, \\
    # and \" escapes; single quotes are literal).
    def parse(text)
      {}.tap do |vars|
        text.to_s.each_line do |raw|
          line = raw.chomp
          next if line.strip.empty? || line.strip.start_with?('#')

          match = LINE.match(line)
          next if match.nil?

          vars[match[1]] = unquote(match[2])
        end
      end
    end

    # Render a hash as dotenv-style `KEY=value` lines (sorted, newline-ended).
    def dump(vars)
      format_lines(vars) { |k, v| "#{k}=#{dotenv_quote(v)}" }
    end

    # Render a hash as shell-eval-able `export KEY='value'` lines.
    #
    #   eval "$(bone export)"
    def export(vars)
      format_lines(vars) { |k, v| "export #{k}=#{shell_single_quote(v)}" }
    end

    # -- internals -----------------------------------------------------------

    # Render sorted, newline-terminated lines via the given block. Guards the
    # key of every line: a name that is not a valid identifier could inject
    # shell once the output is eval'd, so we raise rather than emit it. This is
    # the emit-time backstop to the write-boundary check in Bone::Client#set.
    def format_lines(vars)
      lines = vars.sort_by { |k, _| k.to_s }.map do |k, v|
        key = k.to_s
        raise Bone::InvalidName, key.inspect unless valid_name?(key)

        yield(key, v.to_s)
      end
      "#{lines.join("\n")}\n"
    end

    def unquote(value)
      if value.start_with?("'") && value.end_with?("'") && value.length >= 2
        value[1..-2]
      elsif value.start_with?('"') && value.end_with?('"') && value.length >= 2
        value[1..-2].gsub(/\\(.)/) { unescape(::Regexp.last_match(1)) }
      else
        value
      end
    end

    def unescape(char)
      { 'n' => "\n", 't' => "\t", 'r' => "\r", '"' => '"', '\\' => '\\' }.fetch(char, char)
    end

    def dotenv_quote(value)
      return value unless value.empty? || value.match?(NEEDS_DQUOTE)

      # Block form avoids gsub replacement-string escapes (\\, \0, \1, …).
      escaped = value.gsub(/[\\"\n\r\t]/) do |char|
        { '\\' => '\\\\', '"' => '\\"', "\n" => '\\n', "\r" => '\\r', "\t" => '\\t' }[char]
      end
      %("#{escaped}")
    end

    # Wrap in single quotes for POSIX shells, escaping embedded single quotes
    # via the '\'' idiom. Block form keeps gsub from interpreting \' as the
    # post-match reference.
    def shell_single_quote(value)
      "'#{value.gsub("'") { "'\\''" }}'"
    end

    private_class_method :format_lines, :unquote, :unescape, :dotenv_quote, :shell_single_quote
  end
end
