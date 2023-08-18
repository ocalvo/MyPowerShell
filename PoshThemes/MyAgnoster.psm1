. ($PSScriptRoot+'\VSO-Helpers.ps1')

function Write-Theme {

    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )

    $atSymbol = "@"
    if (Test-IsUnix) { $atSymbol = "🐧" }

    $Host.UI.RawUI.WindowTitle = Get-MyWindowTitle
}

