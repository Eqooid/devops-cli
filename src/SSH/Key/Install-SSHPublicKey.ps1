function Install-SSHPublicKey {
    <#
    .SYNOPSIS
        Installs a validated public key through an existing SSH alias.
    .DESCRIPTION
        Preserves authorized_keys and compares key material, ignoring comments.
        OpenSSH handles authentication and host verification interactively.
    .EXAMPLE
        Install-SSHPublicKey -Alias ubuntu-dev -PublicKeyPath "$HOME/.ssh/id_ed25519.pub"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z')]
        [string]$Alias,

        [Parameter(Mandatory = $true)]
        [string]$PublicKeyPath
    )

    # Refuse an accidentally selected private key before reading any contents.
    if ([IO.Path]::GetExtension($PublicKeyPath) -ine '.pub') {
        throw 'Select a public key file with a .pub extension.'
    }
    if (-not (Test-Path -LiteralPath $PublicKeyPath -PathType Leaf)) {
        throw "Public key file not found: $PublicKeyPath"
    }
    $resolvedPath = (Resolve-Path -LiteralPath $PublicKeyPath -ErrorAction Stop).ProviderPath
    $keyLines = @(Get-Content -LiteralPath $resolvedPath -ErrorAction Stop)
    if ($keyLines.Count -ne 1 -or
        ([string]$keyLines[0]).Trim() -cnotmatch '\A(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(?:256|384|521))[ \t]+([A-Za-z0-9+/]+={0,2})(?:[ \t]+[^\r\n]*)?\z') {
        throw 'Expected one supported SSH public key line.'
    }
    # Comments never need to cross the shell or SSH boundary.
    $publicKey = $Matches[1] + ' ' + $Matches[2]
    $ssh = Get-Command ssh -CommandType Application -ErrorAction Stop
    $keygen = Get-Command ssh-keygen -CommandType Application -ErrorAction Stop
    $diagnosticPath = [IO.Path]::GetTempFileName()
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        # PS 5.1 otherwise turns native stderr into a terminating error before we read the exit code.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        $null = & $keygen.Source -l -f $resolvedPath 2> $diagnosticPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorActionPreference
        if ($null -eq $exitCode -or $exitCode -ne 0) {
            throw "Public key validation failed (exit $exitCode): $([IO.File]::ReadAllText($diagnosticPath))"
        }
        $encodedKey = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($publicKey))
        $remoteScript = @'
set -eu
step=initialization
trap 'code=$?; if [ "$code" -ne 0 ]; then printf "ERROR: %s failed (exit %s)\n" "$step" "$code" >&2; fi' 0
umask 077
step=decode_key
public_key=$(printf '%s' '__PUBLIC_KEY__' | base64 -d)
key_type=${public_key%% *}
key_data=${public_key#* }
ssh_dir="$HOME/.ssh"
auth_file="$ssh_dir/authorized_keys"
step=check_paths
if [ -L "$ssh_dir" ] || [ -L "$auth_file" ]; then
    echo 'ERROR: Symbolic links are not supported.' >&2
    exit 1
fi
if [ -e "$ssh_dir" ] && [ ! -d "$ssh_dir" ]; then
    echo 'ERROR: SSH directory is not a directory.' >&2
    exit 1
fi
if [ -e "$auth_file" ] && [ ! -f "$auth_file" ]; then
    echo 'ERROR: authorized_keys is not a regular file.' >&2
    exit 1
fi
step=prepare_files
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$auth_file"
chmod 600 "$auth_file"
step=check_duplicate
# Read only the key fields, respecting quoted spaces and escapes in options.
duplicate=$(awk -v type="$key_type" -v data="$key_data" '
function field(    i,c,quoted,escaped) {
    sub(/^[ \t]+/, "", rest)
    quoted=0; escaped=0
    for (i=1; i<=length(rest); i++) {
        c=substr(rest,i,1)
        if (escaped) escaped=0
        else if (c == "\\") escaped=1
        else if (c == "\"") quoted=!quoted
        else if (!quoted && c ~ /[ \t\r]/) break
    }
    if (quoted || escaped) { bad=1; return "" }
    value=substr(rest,1,i-1)
    rest=substr(rest,i)
    return value
}
{
    rest=$0; bad=0
    first=field()
    if (first == "" || substr(first,1,1) == "#") next
    if (first == type) second=field()
    else { first=field(); second=field() }
    if (!bad && first == type && second == data) found=1
}
END { print (found ? "yes" : "no") }
' "$auth_file")
if [ "$duplicate" = yes ]; then
    echo 'DEVOPS_CLI_STATUS:ALREADY_INSTALLED'
else
    step=append_key
    # shortcut: installs are sequential; add locking if concurrent installs are needed.
    # A leading newline keeps an unterminated existing entry intact.
    printf '\n%s\n' "$public_key" >> "$auth_file"
    echo 'DEVOPS_CLI_STATUS:INSTALLED'
fi
'@
        $remoteScript = $remoteScript.Replace('__PUBLIC_KEY__', $encodedKey).Replace("`r", '') + "`n"
        $encodedScript = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
        # No double quotes, expansion, stdin pipeline, or nested sh -c across Windows argv.
        $remoteCommand = "printf '%s' '$encodedScript' | base64 -d | sh -s"
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        $output = @(& $ssh.Source -T $Alias $remoteCommand 2> $diagnosticPath)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorActionPreference
        $diagnostics = [IO.File]::ReadAllText($diagnosticPath).Trim()
        $response = ($output | ForEach-Object { [string]$_ }) -join "`n"
        if ($null -eq $exitCode -or $exitCode -ne 0) {
            throw "SSH installation failed with exit code ${exitCode}.`n$diagnostics`n$response"
        }
        $statuses = @($output | Where-Object { [string]$_ -cmatch '^DEVOPS_CLI_STATUS:(INSTALLED|ALREADY_INSTALLED)$' })
        if ($statuses.Count -ne 1) {
            throw "Expected exactly one installation status marker.`n$diagnostics`n$response"
        }
        if ($diagnostics) { Write-Warning $diagnostics }
        Write-Verbose $response
        [PSCustomObject]@{
            Alias         = $Alias
            PublicKeyPath = $resolvedPath
            Status        = ([string]$statuses[0]).Substring('DEVOPS_CLI_STATUS:'.Length)
            Success       = $true
        }
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference
        Remove-Item -LiteralPath $diagnosticPath -Force -ErrorAction Stop
    }
}
