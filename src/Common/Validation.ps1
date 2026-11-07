function Test-SSHSetupInput {
    <#
    .SYNOPSIS
        Rejects missing values and unsafe destination or config syntax.
    .PARAMETER Server
        DNS hostname, IPv4 address, or unbracketed IPv6 address without a port.
    .PARAMETER Username
        Conventional Linux account name.
    .PARAMETER Alias
        Simple SSH nickname beginning with a letter or digit.
    .OUTPUTS
        System.Boolean. True on success; invalid input throws.
    .EXAMPLE
        Test-SSHSetupInput -Server server.example -Username alice -Alias work
    #>
    param([string]$Server, [string]$Username, [string]$Alias)
    foreach ($value in @($Server, $Username, $Alias)) {
        if ([string]::IsNullOrWhiteSpace($value)) { throw 'Server, username, and alias are required.' }
    }
    # Anchors require the entire value to match. Allowlists exclude newlines,
    # shell punctuation, leading SSH options, and injected config directives.
    if ($Alias -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9_-]*\z') { throw 'Invalid SSH alias.' }
    if ($Username -cnotmatch '\A[a-zA-Z_][a-zA-Z0-9_.-]*\z') { throw 'Invalid Linux username.' }
    if ($Server.Contains(':')) {
        $address = $null
        if (-not [System.Net.IPAddress]::TryParse($Server, [ref]$address)) { throw 'Invalid IPv6 address.' }
    }
    elseif ($Server.Length -gt 253 -or $Server -cnotmatch '\A[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\z' -or $Server.Contains('..')) {
        throw 'Invalid server hostname or IP address. Do not include a port.'
    }
    return $true
}
