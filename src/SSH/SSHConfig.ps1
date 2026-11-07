function Test-SSHConfig {
    <#
    .SYNOPSIS
        Checks whether a simple SSH alias is absent, reusable, or conflicting.
    .DESCRIPTION
        Conservatively reads explicit Host blocks. Advanced constructs are
        rejected rather than guessing OpenSSH inheritance or changing a file.
    .PARAMETER Server
        Requested hostname or address.
    .PARAMETER Username
        Requested Linux username.
    .PARAMETER Alias
        Requested SSH nickname.
    .PARAMETER KeyPath
        Requested private key path, including paths with spaces.
    .PARAMETER ConfigPath
        SSH configuration file to inspect.
    .OUTPUTS
        System.String. Absent or Reused. Conflicts throw.
    .EXAMPLE
        Test-SSHConfig -Server host.example -Username alice -Alias work -KeyPath "$HOME/.ssh/id_ed25519" -ConfigPath "$HOME/.ssh/config"
    #>
    param([string]$Server, [string]$Username, [string]$Alias,
          [Parameter(Mandatory=$true)][string]$KeyPath,
          [Parameter(Mandatory=$true)][string]$ConfigPath)
    $null = Test-SSHSetupInput -Server $Server -Username $Username -Alias $Alias
    $identity = $KeyPath.Replace('\', '/')
    # OpenSSH expands %, $ and ~ in paths. Quotes/newlines can change syntax.
    if ($identity -match '["\r\n%$~\x00]') { throw 'Identity path contains unsupported SSH expansion or quoting characters.' }
    if (-not [System.IO.Path]::IsPathRooted($KeyPath)) { throw 'Use an absolute identity path.' }
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return 'Absent' }
    # Strict UTF-8 also accepts ASCII. Reject UTF-16/legacy encodings rather
    # than mixing encodings or silently damaging the original file.
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    # ReadAllText auto-detects a UTF-16 BOM even with a UTF-8 encoding argument.
    # Decode bytes ourselves so incompatible encodings really are rejected.
    $text = $encoding.GetString([System.IO.File]::ReadAllBytes($ConfigPath)).TrimStart([char]0xFEFF)
    if ($text.Contains([char]0)) { throw 'SSH config must be UTF-8 or ASCII.' }
    $expected = @{ hostname = $Server; user = $Username; port = '22'; identityfile = $identity; identitiesonly = 'yes' }
    $found = @{}
    $inTarget = $false
    $seenHost = $false
    $count = 0
    foreach ($line in ($text -split '\r?\n')) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '\A([^\s=]+)[\s=]+(.+)\z') { throw 'Unsupported SSH config syntax; inspect it manually.' }
        $name = $Matches[1].ToLowerInvariant()
        $value = $Matches[2].Trim()
        if ($name -eq 'include' -or $name -eq 'match') { throw 'Config uses Include or Match; resolve this setup manually to preserve its semantics.' }
        if ($name -eq 'host') {
            $seenHost = $true
            # Restrict automated handling to literal aliases; patterns may
            # apply inherited values even when no exact alias is present.
            $names = $value -split '\s+'
            foreach ($hostName in $names) {
                if ($hostName -notmatch '\A[A-Za-z0-9][A-Za-z0-9_.-]*\z') { throw 'Config uses Host patterns or quoting; resolve this setup manually.' }
            }
            $inTarget = $names -contains $Alias
            if ($inTarget) {
                $count++
                if ($count -gt 1) { throw "Duplicate SSH alias '$Alias'; configuration was preserved." }
            }
            continue
        }
        if (-not $seenHost) { throw 'Config uses global directives; resolve this setup manually to preserve inheritance.' }
        if ($inTarget) {
            if (-not $expected.ContainsKey($name) -or $found.ContainsKey($name)) {
                throw "SSH alias '$Alias' has additional or repeated directives; inspect it manually."
            }
            if ($value.StartsWith('"') -and $value.EndsWith('"')) { $value = $value.Substring(1, $value.Length - 2) }
            $found[$name] = $value
        }
    }
    if ($count -eq 0) { return 'Absent' }
    foreach ($name in $expected.Keys) {
        # Missing Port/IdentitiesOnly are not assumed safe: explicit matching
        # settings make reuse understandable without evaluating system config.
        $same = $found.ContainsKey($name) -and $found[$name] -ceq $expected[$name]
        if ($name -eq 'hostname' -and $found.ContainsKey($name)) { $same = $found[$name] -ieq $expected[$name] }
        if (-not $same) { throw "SSH alias '$Alias' conflicts with requested $name; configuration was preserved." }
    }
    return 'Reused'
}

function New-SSHConfig {
    <#
    .SYNOPSIS
        Appends an absent alias or reuses an identical explicit configuration.
    .PARAMETER Server
        Requested Linux hostname or address.
    .PARAMETER Username
        Requested Linux username.
    .PARAMETER Alias
        SSH nickname to create or reuse.
    .PARAMETER KeyPath
        Absolute private key path.
    .PARAMETER ConfigPath
        Configuration file to preserve and append to.
    .OUTPUTS
        System.String. Created or Reused.
    .EXAMPLE
        New-SSHConfig -Server host.example -Username alice -Alias work -KeyPath "$HOME/.ssh/id_ed25519" -ConfigPath "$HOME/.ssh/config"
    #>
    param([string]$Server, [string]$Username, [string]$Alias,
          [Parameter(Mandatory=$true)][string]$KeyPath,
          [Parameter(Mandatory=$true)][string]$ConfigPath)
    $state = Test-SSHConfig -Server $Server -Username $Username -Alias $Alias -KeyPath $KeyPath -ConfigPath $ConfigPath
    if ($state -eq 'Reused') { return $state }
    $directory = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory -ErrorAction Stop }
    $identity = $KeyPath.Replace('\', '/')
    # Double-quoted here-strings interpolate values. Validation above ensures
    # those values cannot introduce new config lines or expand SSH path tokens.
    $entry = @"

Host $Alias
    HostName $Server
    User $Username
    Port 22
    IdentityFile "$identity"
    IdentitiesOnly yes

"@
    # Append UTF-8 bytes without rewriting existing content or adding a BOM.
    [System.IO.File]::AppendAllText($ConfigPath, $entry, (New-Object System.Text.UTF8Encoding($false)))
    return 'Created'
}
