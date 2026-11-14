function Get-SSHKey {
    <#
    .SYNOPSIS
        Lists SSH public keys and their fingerprints.

    .DESCRIPTION
        Reads public key files from the SSH directory.
        Does not read or display private key contents.
    #>

    [CmdletBinding()]
    param(
        [string]$SSHDirectory = (Join-Path $HOME ".ssh")
    )

    # STEP 1: Check whether the SSH directory exists.
    if (-not (Test-Path -LiteralPath $SSHDirectory -PathType Container)) {
        Write-Warning "SSH directory does not exist: $SSHDirectory"
        return
    }

    # STEP 2: Find the ssh-keygen executable.
    $keygen = Get-Command ssh-keygen `
        -CommandType Application `
        -ErrorAction Stop

    # STEP 3: Find public key files.
    $publicKeys = Get-ChildItem `
        -LiteralPath $SSHDirectory `
        -Filter "*.pub" `
        -File

    foreach ($publicKey in $publicKeys) {

        # STEP 4: Determine the matching private key path.
        $privateKeyPath = $publicKey.FullName.Substring(
            0,
            $publicKey.FullName.Length - 4
        )

        $hasPrivate = Test-Path `
            -LiteralPath $privateKeyPath `
            -PathType Leaf

        # STEP 5: Read fingerprint metadata.
        $fingerprintOutput = & $keygen.Source `
            -l `
            -f $publicKey.FullName `
            2>$null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Cannot read fingerprint: $($publicKey.Name)"
            continue
        }

        # Example:
        # 256 SHA256:abc123... comment (ED25519)

        $fingerprint = $null
        $keyType = $null
        $keySize = $null

        $outputText = ($fingerprintOutput -join " ").Trim()

        if ($outputText -match '^(\d+)\s+(\S+)\s+.+\s+\(([^)]+)\)$') {
            $keySize = [int]$Matches[1]
            $fingerprint = $Matches[2]
            $keyType = $Matches[3]
        }

        # STEP 6: Return key metadata.
        [PSCustomObject]@{
            Name        = $publicKey.BaseName
            Type        = $keyType
            KeySize     = $keySize
            Fingerprint = $fingerprint
            HasPrivate  = $hasPrivate
            HasPublic   = $true
            PublicPath  = $publicKey.FullName
            PrivatePath = $privateKeyPath
        }
    }
}