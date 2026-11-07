# Learning PowerShell through DevOps CLI

Start with `devops.ps1` to see the workflow, then open one feature file at a
time. These are ordinary scripts and functions, not classes or a framework.
Examples below come from the implementation; running setup itself can change
your SSH files and the remote account. Prefer the isolated tests for study.

## Variables, strings, and interaction

PowerShell variable names begin with `$`. Assignment resembles many languages:

```powershell
$sshDirectory = Join-Path $HOME '.ssh'
$publicPath = "$KeyPath.pub"
```

Double-quoted strings interpolate variables, like template strings in other
languages. Single-quoted strings are literal. `$HOME` is the current user's
home, independent of the current working directory. A subexpression expands
an object's property inside a string:

```powershell
Write-Host "SSH connection successful. Remote user: $($result.RemoteUser)"
```

`Read-SSHSetupInput` uses `(Read-Host 'Enter the SSH alias').Trim()` to read a
line and remove surrounding whitespace. `Read-Host` returns text; `Write-Host`
displays user-facing progress. Neither setup nor the installer collects a
password into a PowerShell variable: native SSH owns authentication prompts.

## Decisions and comparisons

In `New-SSHKey`, these Booleans determine whether a key pair is complete:

```powershell
$privateExists = Test-Path -LiteralPath $KeyPath
$publicExists = Test-Path -LiteralPath $publicPath
if ($privateExists -ne $publicExists) {
    throw 'Incomplete SSH key pair: preserve the existing file and restore its matching partner before retrying.'
}
```

`if` runs its block when the condition is true. `else` can supply the alternative:
the project uses early returns and errors where an alternative branch would
otherwise nest the workflow. `$true` and `$false` are Boolean constants.
`-eq` means equal; `-ne` means unequal; `-not` reverses a Boolean. `-and` and
`-or` combine conditions. Unlike JavaScript, `=` assigns rather than compares.

`-match` tests a regular expression. `-notmatch` rejects a match; `-cnotmatch`
also makes the comparison case-sensitive. Most PowerShell string comparisons
are case-insensitive by default; `-ceq` explicitly requires case equality.
Validation uses `\A` and `\z` to anchor a pattern to the entire input so a
newline cannot inject another SSH configuration directive.

On a successful regex match, `$Matches` contains captured groups. Installation
copies `$Matches[1]` into `$blob` before doing other operations, because later
matches can replace this automatic variable.

## Paths and commands

`Join-Path` combines a directory and child name using platform path rules.
`Test-Path` checks existence; `-PathType Leaf` requires a file rather than a
directory. `-LiteralPath` prevents wildcard characters in actual filenames
from being interpreted as search patterns.

```powershell
if (-not (Test-Path -LiteralPath $directory)) {
    $null = New-Item -ItemType Directory -Path $directory -ErrorAction Stop
}
```

The `-not` avoids recreating an existing directory. Assigning to `$null`
discards `New-Item`'s returned directory object so it does not become part of
the calling function's output.

`Test-SSHClient` uses `Get-Command ssh -CommandType Application` to search PATH.
Application restricts discovery to executables, excluding PowerShell aliases
and functions. `-ErrorAction SilentlyContinue` suppresses the usual missing
command diagnostic so the function can return false. Setup then uses
`-ErrorAction Stop` when resolving the actual executable path.

## Functions, parameters, and output

Feature files define functions without running the setup workflow. `param`
declares inputs; `[string]` gives a type; `[Parameter(Mandatory=$true)]` requires
a value. `[switch]` is a flag such as `-NonInteractive`.

```powershell
$pair = New-SSHKey -KeyPath $keyPath -KeygenPath $keygenPath
```

Functions emit objects to PowerShell's success output stream. **Every
uncaptured expression can be output**, even without `return`. `return`
emits its value and stops that invocation; it does not discard earlier output.
That differs from languages with a single return-value slot. This is why
native keygen progress is sent to `Out-Host` and helper results to `$null`.

`New-SSHKey` returns one object containing related results:

```powershell
return [pscustomobject]@{ KeyPath = $KeyPath; PublicKeyPath = $publicPath; Created = $created }
```

`@{ ... }` alone is a hashtable, similar to a dictionary. Input collection
returns one so setup can use `& $commands.ValidateInput @values`. This is **splatting**:
the keys `Server`, `Username`, and `Alias` become named arguments. Dependencies
remain explicit, without globals shared across feature scripts.

Every public function includes comment-based help with `.SYNOPSIS`, real
parameters, outputs, and examples. After loading a file, try:

```powershell
. ./src/SSH/SSHDetection.ps1
Get-Help Test-SSHClient -Full
```

## Dot-sourcing and script location

Setup loads scripts with a leading dot followed by a space:

```powershell
. (Join-Path $PSScriptRoot $module.Path)
```

Dot-sourcing evaluates definitions in the caller's scope, so setup can call
those functions. Running a script normally gives it its own script scope.
`$PSScriptRoot` is the containing script's directory, not the terminal's current
directory. This makes the launcher work from elsewhere. `@(...)` makes an array;
setup loops over the list with `foreach`.

Setup's `$modules` array stores each file's `Path` and a `Functions` hashtable.
A file can provide more than one function:

```powershell
@{ Path = 'src/SSH/SSHDetection.ps1'; Functions = @{ CheckClient = 'Test-SSHClient'; CheckKeygen = 'Test-SSHKeygen' } }
```

The loader dot-sources each file once and uses `Get-Command -CommandType Function`
to resolve its function names into `$commands`. `GetEnumerator()` loops over
the function map's key/value pairs. The workflow then calls an action using
`& $commands.CheckClient`. The function names live in the array, while the
workflow explicitly controls parameters, results, and execution order. Loading
all functions from a file does not mean they should all run immediately.

## Files and preserving content

`Get-Content -LiteralPath $PublicKeyPath -Raw` reads the whole file as one
string. Without `-Raw`, it emits individual lines. `Trim()` removes surrounding
whitespace before validating the public key.

The duplicate-alias test uses:

```powershell
Add-Content $config "`nHost WORK`n HostName other"
```

`Add-Content` appends text; the backtick escape `` `n `` is a newline. Encoding
defaults differ between Windows PowerShell and modern PowerShell. Production
config writing therefore uses the .NET method
`[System.IO.File]::AppendAllText` with an explicit UTF-8 encoding without a BOM.
This appends bytes without re-encoding the original file. Existing files are
first checked for compatible encoding. `[Type]::Method(...)` calls a static
.NET method, similar to static methods in C# or Java.

## Pipelines, the call operator, and native programs

`|` passes output into the next command. PowerShell commands normally exchange
objects; native applications receive text via their standard input. Installation
uses this distinction deliberately:

```powershell
$publicKey | & $SshPath -T -o StrictHostKeyChecking=ask -o "HostName=$Server" -p 22 -o ConnectTimeout=10 -o ConnectionAttempts=1 -l $Username $Server $remoteCommand | Out-Host
```

`&` is the call operator. A string variable containing an executable path does
not run by itself; `& $SshPath` invokes it. Separate arguments preserve paths
with spaces without building and evaluating a PowerShell command string.
`-o` here belongs to SSH, not PowerShell. The key travels as input data, never
as interpolated remote shell source.

Native argument passing differs across versions. Windows PowerShell 5.1 uses
legacy Windows quoting; installation explicitly escapes embedded double quotes
in the remote command for this case. PowerShell 7 on Linux passes argument
strings directly. The remote command removes carriage returns from piped input
because Windows text pipelines can send CRLF instead of LF.

`$LASTEXITCODE` records the most recent native process exit code. Zero normally
means success. Save it immediately, as `Test-SSHConnection` does, before another
native command can replace it. Native nonzero exits do not normally throw a
PowerShell exception, so `try/catch` alone cannot detect SSH failure.

## Errors and workflow control

```powershell
if ($LASTEXITCODE -ne 0) { throw 'SSH key generation failed. Inspect partial files before retrying.' }
```

`throw` raises a terminating error. `try` contains work that may fail; `catch`
handles terminating errors, similar to exception handling in other languages.
`$_` inside `catch` is the error record; `$_.Exception.Message` is its message.
`-ErrorAction Stop` converts cmdlet errors into terminating errors.

Helpers throw or return structured results, while `devops.ps1` alone uses
`exit 1` to signal failure to the invoking shell. Alias reuse returns `Reused`;
it does not exit the entry script or skip connection testing. Failed connection
tests return an object so callers can inspect `Success`, `ExitCode`, and
`Message` without parsing colored console text.

## Here-strings and two different languages

Installation's remote command is a single-quoted here-string: it starts with
`@'` and ends with `'@` on its own line. It holds multiple lines literally,
including POSIX `$HOME` and `$key` variables that only the remote shell expands.
Configuration generation uses a double-quoted here-string, starting with
`@"` and ending with `"@`, so PowerShell expands `$Alias` and `$identity` locally.

The remote snippet uses POSIX shell syntax, not PowerShell. Keep the two
languages separate: local PowerShell validates inputs and invokes SSH, while
remote shell commands preserve permissions and append the key on Linux.

## Testing without touching your keys

Tests use Pester's `Describe` and `It` blocks to describe expected behavior.
`Mock Get-Command` simulates installed/missing tools. Local fake functions
simulate native commands and their exit codes. Temporary key/config paths
exercise preservation without touching `$HOME/.ssh`. The optional POSIX test
runs the extracted installer script locally with an isolated HOME; it is not
proof of SSH connectivity. Live validation is a separate, explicit manual step.
