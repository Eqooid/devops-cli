function New-SSHKey {
    <#
    .SYNOPSIS
        Reuses an existing pair or interactively generates ED25519 keys.
    .PARAMETER KeyPath
        Private key path. Its public partner uses the .pub suffix.
    .PARAMETER KeygenPath
        Executable path returned by Get-Command ssh-keygen.
    .OUTPUTS
        PSCustomObject with KeyPath, PublicKeyPath, and Created properties.
    .EXAMPLE
        New-SSHKey -KeyPath "$HOME/.ssh/id_ed25519" -KeygenPath (Get-Command ssh-keygen).Source
    #>
    param([Parameter(Mandatory=$true)][string]$KeyPath,
          [Parameter(Mandatory=$true)][string]$KeygenPath)
    $null = Get-Command $KeygenPath -CommandType Application -ErrorAction Stop
    $publicPath = "$KeyPath.pub"
    $privateExists = Test-Path -LiteralPath $KeyPath
    $publicExists = Test-Path -LiteralPath $publicPath
    if ($privateExists -ne $publicExists) {
        throw 'Incomplete SSH key pair: preserve the existing file and restore its matching partner before retrying.'
    }
    $created = $false
    if (-not $privateExists) {
        $directory = Split-Path -Parent $KeyPath
        if (-not (Test-Path -LiteralPath $directory)) {
            $null = New-Item -ItemType Directory -Path $directory -ErrorAction Stop
        }
        # & invokes an executable stored in a variable. Leave stdin attached so
        # ssh-keygen itself can ask for an optional passphrase.
        & $KeygenPath -t ed25519 -f $KeyPath | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'SSH key generation failed. Inspect partial files before retrying.' }
        $created = $true
    }
    if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $publicPath -PathType Leaf)) { throw 'SSH key pair must contain two regular files.' }
    return [pscustomobject]@{ KeyPath = $KeyPath; PublicKeyPath = $publicPath; Created = $created }
}
