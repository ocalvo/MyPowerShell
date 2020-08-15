#requires -Version 2 -Modules posh-git

function Write-Theme {
    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )

    $user=$sl.CurrentUser
    $prompt+= Write-Prompt  -Object ('@'+$user) -ForegroundColor $sl.Colors.WithForegroundColor 
    #check the last command state and indicate if failed and change the colors of the arrows
    If ($lastCommandFailed) {
        $prompt += Write-Prompt -Object (' '+$sl.PromptSymbols.PromptIndicator+'  ')  -ForegroundColor  $sl.Colors.WithForegroundColor   
    }else{
        $prompt += Write-Prompt -Object (' '+$sl.PromptSymbols.PromptIndicator+'  ') -ForegroundColor  $sl.Colors.PromptSymbolColor  
    }
    

    # Writes the drive portion
    $drive = $sl.PromptSymbols.HomeSymbol
    if ($pwd.Path -ne $HOME) {
        $drive = "$(Split-Path -path $pwd -Leaf)"
    }
    $prompt += Write-Prompt -Object $drive -ForegroundColor $sl.Colors.DriveForegroundColor

    $status = Get-VCSStatus
    if ($status) {
        $prompt += Write-Prompt -Object " git(" -ForegroundColor $sl.Colors.PromptHighlightColor
        $prompt += Write-Prompt -Object "$($status.Branch)" -ForegroundColor $sl.Colors.GitDefaultColor
        $prompt += Write-Prompt -Object ")" -ForegroundColor $sl.Colors.PromptHighlightColor
        if ($status.Working.Length -gt 0) {
            $prompt += Write-Prompt -Object (" " + $sl.PromptSymbols.GitDirtyIndicator) -ForegroundColor $sl.Colors.PromptSymbolColor
        }
    }

    if ($with) {
        $prompt += Write-Prompt -Object "$($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
    }

   

    $prompt += '  '
    $prompt
}


$sl = $global:ThemeSettings #local settings
$sl.PromptSymbols.PromptIndicator = [char]::ConvertFromUtf32(0x279C)
$sl.PromptSymbols.HomeSymbol = '~'
$sl.PromptSymbols.GitDirtyIndicator =[char]::ConvertFromUtf32(10007)
$sl.Colors.PromptSymbolColor = [ConsoleColor]::Green
$sl.Colors.PromptHighlightColor = [ConsoleColor]::Blue
$sl.Colors.DriveForegroundColor = [ConsoleColor]::Cyan
$sl.Colors.WithForegroundColor = [ConsoleColor]::Red
$sl.Colors.GitDefaultColor = [ConsoleColor]::Yellow
