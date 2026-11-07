function Test-SSHClient {
    <#
    .SYNOPSIS
        Checks PATH for the native SSH client.
    .OUTPUTS
        System.Boolean.
    .EXAMPLE
        Test-SSHClient
    #>
    # Application excludes functions and aliases that happen to be named ssh.
    return ($null -ne (Get-Command ssh -CommandType Application -ErrorAction SilentlyContinue))
}

function Test-SSHKeygen {
    <#
    .SYNOPSIS
        Checks PATH for the native SSH key generator.
    .OUTPUTS
        System.Boolean.
    .EXAMPLE
        Test-SSHKeygen
    #>
    return ($null -ne (Get-Command ssh-keygen -CommandType Application -ErrorAction SilentlyContinue))
}
