function Install-SSHPublicKey {
    <#
    .SYNOPSIS
        Adds a public key to a Linux account while preserving existing entries.
    .PARAMETER Server
        Linux server hostname or IP address.
    .PARAMETER Username
        Remote Linux account name.
    .PARAMETER Alias
        Setup alias, validated with the other input values.
    .PARAMETER PublicKeyPath
        Local ED25519 public key file.
    .PARAMETER SshPath
        Native SSH executable path.
    .OUTPUTS
        None. A failure throws.
    .EXAMPLE
        Install-SSHPublicKey -Server host.example -Username alice -Alias work -PublicKeyPath "$HOME/.ssh/id_ed25519.pub" -SshPath (Get-Command ssh).Source
    #>
    param([string]$Server, [string]$Username, [string]$Alias,
          [Parameter(Mandatory=$true)][string]$PublicKeyPath,
          [Parameter(Mandatory=$true)][string]$SshPath)
    $null = Test-SSHSetupInput -Server $Server -Username $Username -Alias $Alias
    $publicKey = (Get-Content -LiteralPath $PublicKeyPath -Raw -ErrorAction Stop).Trim()
    if ($publicKey -cnotmatch '\Assh-ed25519 ([A-Za-z0-9+/]+={0,2})(?:[ \t]+[^\r\n]*)?\z') {
        throw 'Expected one ED25519 public key line.'
    }
    $blob = $Matches[1]
    $bytes = [Convert]::FromBase64String($blob)
    $prefix = [Convert]::FromBase64String('AAAAC3NzaC1lZDI1NTE5AAAAIA==')
    if ($bytes.Length -ne 51 -or [Convert]::ToBase64String($bytes[0..18]) -ne [Convert]::ToBase64String($prefix)) {
        throw 'Invalid ED25519 public key data.'
    }
    # Comments are unnecessary remote data; send only the algorithm and blob.
    $publicKey = 'ssh-ed25519 ' + $blob
    # Single-quoted here-strings are literal. PowerShell must not expand the
    # remote shell's variables. Linux commands stay isolated in this function.
    $remoteCommand = @'
umask 077
mkdir -p "$HOME/.ssh" || exit 1
touch "$HOME/.ssh/authorized_keys" || exit 1
chmod 700 "$HOME/.ssh" || exit 1
chmod 600 "$HOME/.ssh/authorized_keys" || exit 1
IFS= read -r key || [ -n "$key" ] || exit 1
# Windows PowerShell may send CRLF through the native input pipeline.
key=$(printf '%s' "$key" | tr -d '\r')
[ -n "$key" ] || exit 1
blob=${key#* }
# Compare material, even in entries with options or different comments.
awk -v blob="$blob" ' { for (i=1; i<NF; i++) if ($i == "ssh-ed25519" && $(i+1) == blob) found=1 } END { exit (found ? 0 : 2) }' "$HOME/.ssh/authorized_keys"
status=$?
if [ "$status" -eq 2 ]; then
    # Leading newline handles files without a final newline.
    printf '\n%s\n' "$key" >> "$HOME/.ssh/authorized_keys" || exit 1
elif [ "$status" -ne 0 ]; then
    exit 1
fi
'@
    $remoteCommand = $remoteCommand.Replace("`r", '')
    # Windows PowerShell 5.1 uses legacy native argument quoting. Escape the
    # embedded quotes so ssh receives them instead of the Windows argv parser
    # consuming them. PowerShell 7 on Linux passes arguments directly.
    if ($PSVersionTable.PSVersion.Major -le 5 -and $env:OS -eq 'Windows_NT') {
        $remoteCommand = $remoteCommand.Replace('"', '\"')
    }
    # Input data never becomes shell source. Keep host key verification enabled.
    $publicKey | & $SshPath -T -o StrictHostKeyChecking=ask -o "HostName=$Server" -p 22 -o ConnectTimeout=10 -o ConnectionAttempts=1 -l $Username $Server $remoteCommand | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Public key installation failed. Check fingerprint, network, authentication, and Linux permissions.' }
}
