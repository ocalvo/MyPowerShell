#requires -Version 2 -Modules posh-git

function Write-Theme {
    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )
    #$prompt += Write-Prompt -Object ($sl.PromptSymbols.PromptIndicator+" ") -ForegroundColor $sl.Colors.PromptBackgroundColor
    #check the last command state and indicate if failed
    $promtSymbolColor = [ConsoleColor]::Green
    If ($lastCommandFailed) {
        $promtSymbolColor = [ConsoleColor]::Red
    }
    
    $prompt += Write-Prompt -Object (
        [char]::ConvertFromUtf32(0x276F)) -ForegroundColor  $sl.Colors.GitNoLocalChangesAndAheadColor
    $prompt += Write-Prompt -Object (
        [char]::ConvertFromUtf32(0x276F)+" ") -ForegroundColor $promtSymbolColor
    # Writes the postfixes to the prompt
    

    $user = $sl.CurrentUser 
    $prompt += Write-Prompt -Object $user
    $prompt += Write-Prompt -Object " :: " 
    # Writes the drive portion
    $drive = $sl.PromptSymbols.HomeSymbol
    if ($pwd.Path -ne $HOME) {
        $drive = "$(Split-Path -path $pwd -Leaf)"
    }
    $prompt += Write-Prompt -Object $drive -ForegroundColor $sl.Colors.DriveForegroundColor

    $status = Get-VCSStatus
    if ($status) {
        $prompt += Write-Prompt -Object " git(" -ForegroundColor $sl.Colors.PromptHighlightColor
        $prompt += Write-Prompt -Object ($status.Branch) -ForegroundColor $sl.Colors.WithForegroundColor
        $prompt += Write-Prompt -Object ")" -ForegroundColor $sl.Colors.PromptHighlightColor
        if ($status.Working.Length -gt 0) {
            $prompt += Write-Prompt -Object (" "+$sl.PromptSymbols.GitDirtyIndicator) -ForegroundColor $sl.Colors.GitDefaultColor
        }
    } else {
        $prompt += Write-Prompt -Object (" ::") -ForegroundColor $sl.Colors.GitDefaultColor
    }

    if ($with) {
        $prompt += Write-Prompt -Object "$($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
    }
    $sTime = " $(Get-Date -Format HH:mm)"
    $prompt += Write-Prompt -Object $sTime   -ForegroundColor $sl.colors.PromptSymbolColor
    #$prompt += Set-Newline

    $prompt += '  '
    $prompt
}

function Get-TimeSinceLastCommit {
    return (git log --pretty=format:'%cr' -1)
}

$sl = $global:ThemeSettings #local settings
$sl.PromptSymbols.PromptIndicator = '+'
$sl.PromptSymbols.HomeSymbol = '🏠'
$sl.Colors.PromptSymbolColor = [ConsoleColor]::Green
$sl.Colors.PromptHighlightColor = [ConsoleColor]::Blue
$sl.Colors.DriveForegroundColor = [ConsoleColor]::Cyan
$sl.Colors.WithForegroundColor = [ConsoleColor]::Red
$sl.PromptSymbols.GitDirtyIndicator =[char]::ConvertFromUtf32(10007)
$sl.Colors.GitDefaultColor = [ConsoleColor]::Yellow
$sl.Colors.AdminIconForegroundColor = [ConsoleColor]::Blue
