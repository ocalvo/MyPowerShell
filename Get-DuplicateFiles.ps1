#requires -version 3
[CmdletBinding()]
param (
    [string]
    $Path
)

function Get-MD5 {
    param (
        [Parameter(Mandatory)]
        [string] 
        $Path
    )
    # This Get-MD5 function sourced from:
    # http://blogs.msdn.com/powershell/archive/2006/04/25/583225.aspx
    $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $Stream = [System.IO.File]::OpenRead($Path)
    try {
        $HashByteArray = $HashAlgorithm.ComputeHash($Stream)
    } finally {
        $Stream.Dispose()
    }

    return [System.BitConverter]::ToString($HashByteArray).ToLowerInvariant() -replace '-',''
}

if (-not $Path) {
    if ((Get-Location).Provider.Name -ne 'FileSystem') {
        Write-Error 'Specify a file system path explicitly, or change the current location to a file system path.'
        return
    }
    $Path = (Get-Location).ProviderPath
}

Get-ChildItem -Path $Path -Recurse -File |
    Where-Object { $_.Length -gt 0 } |
    Group-Object -Property Length |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
        $_.Group |
            ForEach-Object {
                $_ |
                    Add-Member -MemberType NoteProperty -Name ContentHash -Value (Get-MD5 -Path $_.FullName)
            }

        $_.Group |
            Group-Object -Property ContentHash |
            Where-Object { $_.Count -gt 1 }
    }