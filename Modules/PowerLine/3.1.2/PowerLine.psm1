#!/usr/bin/env powershell
using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace PoshCode.Pansies

Add-Type @'
using System;
using System.Management.Automation;
public class EmptyStringAsNullAttribute : ArgumentTransformationAttribute
{
    public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
    {
        if (inputData is string && ((string)inputData).Length == 0)
        {
            return null;
        }
        else
        {
            return inputData;
        }
    }
}
'@

# Ensure the global prompt variable exists and is typed the way we expect
[System.Collections.Generic.List[ScriptBlock]]$Global:Prompt = [ScriptBlock[]]@(
    if(Test-Path Variable:Prompt) {
        $Prompt | ForEach-Object { $_ }
    }
)

Add-MetadataConverter @{ [char] = { "'$_'" } }
function InitializeColor {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[PoshCode.Pansies.RgbColor]]$Colors = $Global:Prompt.Colors,

        [switch]$Passthru
    )

    if(!$PSBoundParameters.ContainsKey("Colors")){
        [System.Collections.Generic.List[PoshCode.Pansies.RgbColor]]$Colors = if($global:Prompt.Colors) {
            $global:Prompt.Colors
        } else {
            "Cyan","DarkCyan","Gray","DarkGray","Gray"
        }
    }
    if($Passthru) {
        $Colors
    }

    if(!(Get-Member -InputObject $Global:Prompt -Name Colors)) {
        Add-Member -InputObject $Global:Prompt -MemberType NoteProperty -Name Colors -Value $Colors
    } else {
        $Global:Prompt.Colors = $Colors
    }
}
function WriteExceptions {
    [CmdletBinding()]
    param(
        # A dictionary mapping script blocks to the exceptions which threw them
        [System.Collections.Specialized.OrderedDictionary]$ScriptExceptions
    )
    $ErrorString = ""

    if($PromptErrors.Count -gt 0) {
        $global:PromptErrors = [ordered]@{} + $ScriptExceptions
        Write-Warning "Exception thrown from prompt block. Check `$PromptErrors. To suppress this message, Set-PowerLine -HideError"
        #$PromptErrors.Insert(0, "0 Preview","Exception thrown from prompt block. Check `$PromptErrors:`n")
        if(@($Host.PrivateData.PSTypeNames)[0] -eq "Microsoft.PowerShell.ConsoleHost+ConsoleColorProxy") {
            foreach($e in $ScriptExceptions.Values) {
                $ErrorString += [PoshCode.Pansies.Text]@{
                    ForegroundColor = $Host.PrivateData.ErrorForegroundColor
                    BackgroundColor = $Host.PrivateData.ErrorBackgroundColor
                    Object = $e
                }
                $ErrorString += "`n"
            }
        } else {
            foreach($e in $ScriptExceptions) {
                $ErrorString += [PoshCode.Pansies.Text]@{
                    ForegroundColor = "Red"
                    BackgroundColor = "Black"
                    Object = $e
                }
                $ErrorString += "`n"
            }
        }
    }

    $ErrorString
}
function Add-PowerLineBlock {
    <#
        .Synopsis
            Insert text or a ScriptBlock into the $Prompt
        .Description
            This function exists primarily to ensure that modules are able to modify the prompt easily without repeating themselves.
        .Example
            Add-PowerLineBlock { "`nI &hearts; PS" }

            Adds the classic "I ♥ PS" to your prompt on a new line. We actually recommend having a simple line in pure 16-color mode on the last line of your prompt, to ensures that PSReadLine won't mess up your colors. PSReadline overwrites your prompt line when you type -- and it can only handle 16 color mode.
        .Example
            Add-PowerLineBlock {
                New-PromptText { Get-Elapsed } -ForegroundColor White -BackgroundColor DarkBlue -ErrorBackground DarkRed -ElevatedForegroundColor Yellow
            } -Index -2

            # This example uses Add-PowerLineBlock to insert a block into the prommpt _before_ the last block
            # It calls Get-Elapsed to show the duration of the last command as the text of the block
            # It uses New-PromptText to control the color so that it's highlighted in red if there is an error, but otherwise in dark blue (or yellow if it's an elevated host).
    #>
    [CmdletBinding(DefaultParameterSetName="Error")]
    param(
        # The text, object, or scriptblock to show as output
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [Alias("Text")]
        $InputObject,

        # The position to insert the InputObject at, by default, inserts in the same place as the last one
        [int]$Index = -1,

        [Switch]$AutoRemove,

        # If set, adds the input to the prompt without checking if it's already there
        [Switch]$Force
    )
    process {
        Write-Debug "Add-PowerLineBlock $InputObject"
        if(!$PSBoundParameters.ContainsKey("Index")) {
            $Index = $Script:PowerLineConfig.DefaultAddIndex++
        }

        $Skip = @($Global:Prompt).ForEach{$_.ToString().Trim()} -eq $InputObject.ToString().Trim()

        if($Force -or !$Skip) {
            if($Index -eq -1 -or $Index -ge $Global:Prompt.Count) {
                Write-Verbose "Appending '$InputObject' to the end of the prompt"
                $Global:Prompt.Add($InputObject)
                $Index = $Global:Prompt.Count
            } elseif($Index -lt 0) {
                $Index = $Global:Prompt.Count - $Index
                Write-Verbose "Inserting '$InputObject' at $Index of the prompt"
                $Global:Prompt.Insert($Index, $InputObject)
            } else {
                Write-Verbose "Inserting '$InputObject' at $Index of the prompt"
                $Global:Prompt.Insert($Index, $InputObject)
            }
            $Script:PowerLineConfig.DefaultAddIndex = $Index + 1
        } else {
            Write-Verbose "Prompt already contained the InputObject block"
        }

        if($AutoRemove) {
            if(($CallStack = Get-PSCallStack).Count -ge 2) {
                if($Module = $CallStack[1].InvocationInfo.MyCommand.Module) {
                    $Module.OnRemove = { Remove-PowerLineBlock $InputObject }.GetNewClosure()
                }
            }
        }
    }
}
function Export-PowerLinePrompt {
    [CmdletBinding()]
    param()

    $Local:Configuration = $Script:PowerLineConfig
    $Configuration.Prompt = [ScriptBlock[]]$global:Prompt
    $Configuration.Colors = [PoshCode.Pansies.RgbColor[]]$global:Prompt.Colors


    @{
        ExtendedCharacters = [PoshCode.Pansies.Entities]::ExtendedCharacters
        EscapeSequences    = [PoshCode.Pansies.Entities]::EscapeSequences
        PowerLineConfig    = $Script:PowerLineConfig
    } | Export-Configuration -AsHashtable

}
function Get-Elapsed {
    <#
    .Synopsis
        Get the time span elapsed during the execution of command (by default the previous command)
    .Description
        Calls Get-History to return a single command and returns the difference between the Start and End execution time
    #>
    [CmdletBinding()]
    param(
        # The command ID to get the execution time for (defaults to the previous command)
        [Parameter()]
        [int]$Id,

        # A Timespan format pattern such as "{0:ss\.ffff}"
        [Parameter()]
        [string]$Format = "{0:h\:mm\:ss\.ffff}"
    )
    $null = $PSBoundParameters.Remove("Format")
    $LastCommand = Get-History -Count 1 @PSBoundParameters
    if(!$LastCommand) { return "" }
    $Duration = $LastCommand.EndExecutionTime - $LastCommand.StartExecutionTime
    $Format -f $Duration
}
function Get-ErrorCount {
    <#
    .Synopsis
        Get a count of new errors from previous command
    .Description
        Detects new errors generated by previous command based on tracking last seen count of errors.
        MUST NOT be run inside New-PromptText.
    #>
    [CmdletBinding()]
    param()

    $global:Error.Count - $script:LastErrorCount
    $script:LastErrorCount = $global:Error.Count
}
function Get-SegmentedPath {
    <#
    .Synopsis
        Gets PowerLine Blocks for each folder in the path
    .Description
        Returns an array of hashtables which can be cast to PowerLine Blocks.
        Includes support for limiting the number of segments or total length of the path, but defaults to 3 segments max
    #>
    [CmdletBinding(DefaultParameterSetName="Segments")]
    param(
        # The path to segment. Defaults to $pwd
        [Parameter(Position=0)]
        [string]
        $Path = $pwd,

        # The maximum number of segments. Defaults to 3
        [Parameter(ParameterSetName="Segments")]
        $SegmentLimit = 3,

        # The maximum length. Defaults to 0 (no max)
        [Parameter(ParameterSetName="Length")]
        [int]
        $LengthLimit = 0,

        # The foreground color to use when the last command succeeded
        [PoshCode.Pansies.RgbColor]$ForegroundColor,

        # The background color to use when the last command succeeded
        [PoshCode.Pansies.RgbColor]$BackgroundColor,

        # The foreground color to use when the process is elevated (running as administrator)
        [PoshCode.Pansies.RgbColor]$ElevatedForegroundColor,

        # The background color to use when the process is elevated (running as administrator)
        [PoshCode.Pansies.RgbColor]$ElevatedBackgroundColor,

        # The foreground color to use when the last command failed
        [PoshCode.Pansies.RgbColor]$ErrorForegroundColor,

        # The background color to use when the last command failed
        [PoshCode.Pansies.RgbColor]$ErrorBackgroundColor
    )

    $buffer = @()

    if($Path.ToLower().StartsWith($Home.ToLower())) {
        $Path = '~' + $Path.Substring($Home.Length)
    }
    Write-Verbose $Path
    while($Path) {
        $buffer += if($Path -eq "~") {
            @{ Object = $Path }
        } else {
            @{ Object = (Split-Path $Path -Leaf) -replace "[\\/]$" }
        }
        $Path = Split-Path $Path

        Write-Verbose $Path

        if($Path -and $SegmentLimit -le $buffer.Count) {
            if($buffer.Count -gt 1) {
                $buffer[-1] = @{ Object = [char]0x2026; }
            } else {
                $buffer += @{ Object = [char]0x2026; }
            }
            break
        }

        if($LengthLimit) {
            $CurrentLength = ($buffer.Object | Measure-Object Length -Sum).Sum + $buffer.Count - 1
            $Tail = if($Path) { 2 } else { 0 }

            if($LengthLimit -lt $CurrentLength + $Tail) {
                if($buffer.Count -gt 1) {
                    $buffer[-1] = @{ Object = [char]0x2026; }
                } else {
                    $buffer += @{ Object = [char]0x2026; }
                }
                break
            }
        }
    }
    [Array]::Reverse($buffer)

    foreach($output in $buffer) {
        # Always set the defaults first, if they're provided
        if($PSBoundParameters.ContainsKey("ForegroundColor")) {
            $output.ForegroundColor = $ForegroundColor
        }
        if($PSBoundParameters.ContainsKey("BackgroundColor")) {
            $output.BackgroundColor = $BackgroundColor
        }

        # If it's elevated, and they passed the elevated color ...
        if(Test-Elevation) {
            if($PSBoundParameters.ContainsKey("ElevatedForegroundColor")) {
                $output.ForegroundColor = $ElevatedForegroundColor
            }
            if($PSBoundParameters.ContainsKey("ElevatedBackgroundColor")) {
                $output.BackgroundColor = $ElevatedBackgroundColor
            }
        }

        # If it failed, and they passed an error color ...
        if(!(Test-Success)) {
            if($PSBoundParameters.ContainsKey("ErrorForegroundColor")) {
                $output.ForegroundColor = $ErrorForegroundColor
            }
            if($PSBoundParameters.ContainsKey("ErrorBackgroundColor")) {
                $output.BackgroundColor = $ErrorBackgroundColor
            }
        }
    }
    [PoshCode.Pansies.Text[]]$buffer
}
function Get-ShortenedPath {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]
        $Path = $pwd,

        [Parameter()]
        [switch]
        $RelativeToHome,

        [Parameter()]
        [int]
        $MaximumLength = [int]::MaxValue,

        [Parameter()]
        [switch]
        $SingleCharacterSegment        
    )

    if ($MaximumLength -le 0) {
        return [string]::Empty
    }

    if ($RelativeToHome -and $Path.ToLower().StartsWith($Home.ToLower())) {
        $Path = '~' + $Path.Substring($Home.Length)
    }

    if (($MaximumLength -gt 0) -and ($Path.Length -gt $MaximumLength)) {
        $Path = $Path.Substring($Path.Length - $MaximumLength)
        if ($Path.Length -gt 3) {
            $Path = "..." + $Path.Substring(3)
        }
    }

    # Credit: http://www.winterdom.com/powershell/2008/08/13/mypowershellprompt.html
    if ($SingleCharacterSegment) {
        # Remove prefix for UNC paths
        $Path = $Path -replace '^[^:]+::', ''
        # handle paths starting with \\ and . correctly
        $Path = ($Path -replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2')
    }

    $Path
}
function New-PromptText {
    <#
        .Synopsis
            Create PoshCode.Pansies.Text with variable background colors
        .Description
            Allows changing the foreground and background colors based on elevation or success.

            Tests elevation fist, and then whether the last command was successful, so if you pass separate colors for each, the Elevated*Color will be used when PowerShell is running as administrator and there is no error. The Error*Color will be used whenever there's an error, whether it's elevated or not.
        .Example
            New-PromptText { Get-Elapsed } -ForegroundColor White -BackgroundColor DarkBlue -ErrorBackground DarkRed -ElevatedForegroundColor Yellow

            This example shows the time elapsed executing the last command in White on a DarkBlue background, but switches the text to yellow if elevated, and the background to red on error.
    #>
    [CmdletBinding(DefaultParameterSetName="Error")]
    [Alias("New-PowerLineBlock")]
    [Alias("New-TextFactory")]
    param(
        # The text, object, or scriptblock to show as output
        [Alias("Text", "Object")]
        [AllowNull()][EmptyStringAsNull()]
        [Parameter(Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)] # , Mandatory=$true
        $InputObject,

        # The foreground color to use when the last command succeeded
        [Alias("Foreground", "Fg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$ForegroundColor,

        # The background color to use when the last command succeeded
        [Alias("Background", "Bg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$BackgroundColor,

        # The foreground color to use when the process is elevated (running as administrator)
        [Alias("AFg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$ElevatedForegroundColor,

        # The background color to use when the process is elevated (running as administrator)
        [Alias("ABg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$ElevatedBackgroundColor,

        # The foreground color to use when the last command failed
        [Alias("EFg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$ErrorForegroundColor,

        # The background color to use when the last command failed
        [Alias("EBg")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][EmptyStringAsNull()]
        [PoshCode.Pansies.RgbColor]$ErrorBackgroundColor
    )
    process {
        # Try to fix the parameter binding
        if($InputObject.InputObject) {
            $InputObject = $InputObject.InputObject
        } elseif($InputObject.Object) {
            $InputObject = $InputObject.Object
        }elseif($InputObject.Text) {
            $InputObject = $InputObject.Text
        }

        $output = [PoshCode.Pansies.Text]@{
            Object = $InputObject
        }
        # Always set the defaults first, if they're provided
        if($PSBoundParameters.ContainsKey("ForegroundColor") -and $ForegroundColor -ne $Null) {
            $output.ForegroundColor = $ForegroundColor
        }
        if($PSBoundParameters.ContainsKey("BackgroundColor") -and $BackgroundColor -ne $Null) {
            $output.BackgroundColor = $BackgroundColor
        }

        # If it's elevated, and they passed the elevated color ...
        if(Test-Elevation) {
            if($PSBoundParameters.ContainsKey("ElevatedForegroundColor") -and $ElevatedForegroundColor -ne $Null) {
                $output.ForegroundColor = $ElevatedForegroundColor
            }
            if($PSBoundParameters.ContainsKey("ElevatedBackgroundColor") -and $ElevatedBackgroundColor -ne $Null) {
                $output.BackgroundColor = $ElevatedBackgroundColor
            }
        }

        # If it failed, and they passed an error color ...
        if(!(Test-Success)) {
            if($PSBoundParameters.ContainsKey("ErrorForegroundColor") -and $ErrorForegroundColor -ne $Null) {
                $output.ForegroundColor = $ErrorForegroundColor
            }
            if($PSBoundParameters.ContainsKey("ErrorBackgroundColor") -and $ErrorBackgroundColor -ne $Null) {
                $output.BackgroundColor = $ErrorBackgroundColor
            }
        }

        $output
    }
}
function Remove-PowerLineBlock {
    <#
        .Synopsis
            Remove text or a ScriptBlock from the $Prompt
        .Description
            This function exists primarily to ensure that modules are able to clean up the prompt easily when they're removed
        .Example
            Remove-PowerLineBlock {
                New-PromptText { Get-Elapsed } -ForegroundColor White -BackgroundColor DarkBlue -ErrorBackground DarkRed -ElevatedForegroundColor Yellow
            }

            Removes the specified block. Note that it must be _exactly_ the same as when you added it.
    #>
    [CmdletBinding(DefaultParameterSetName="Error")]
    param(
        # The text, object, or scriptblock to show as output
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [Alias("Text")]
        $InputObject
    )
    process {

        $Index = @($Global:Prompt).ForEach{$_.ToString().Trim()}.IndexOf($InputObject.ToString().Trim())
        if($Index -ge 0) {
            $null = $Global:Prompt.RemoveAt($Index)
        }
        if($Index -lt $Script:PowerLineConfig.DefaultAddIndex) {
            $Script:PowerLineConfig.DefaultAddIndex--
        }
    }
}
function Set-PowerLinePrompt {
    #.Synopsis
    #   Set the default PowerLine prompt function which uses the $Prompt variable
    #.Description
    #   Overwrites the current prompt function with one that uses the $Prompt variable
    #   Note that this doesn't try to preserve any changes already made to the prompt by modules like ZLocation
    #.Example
    #   Set-PowerLinePrompt -SetCurrentDirectory
    #
    #   Sets the powerline prompt and activates and option supported by this prompt function to update the .Net environment with the current directory each time the prompt runs.
    #.Example
    #   Set-PowerLinePrompt -PowerLineFont
    #
    #   Sets the powerline prompt using the actual PowerLine font characters, and ensuring that we're using the default characters. Note that you can still change the characters used to separate blocks in the PowerLine output after running this, by setting the static members of [PowerLine.Prompt] like Separator and ColorSeparator...
    #.Example
    #   Set-PowerLinePrompt -ResetSeparators
    #
    #   Sets the powerline prompt and forces the use of "safe" separator characters. You can still change the characters used to separate blocks in the PowerLine output after running this, by setting the static members of [PowerLine.Prompt] like Separator and ColorSeparator...
    #.Example
    #   Set-PowerLinePrompt -FullColor
    #
    #   Sets the powerline prompt and forces the assumption of full RGB color support instead of 16 color
    [CmdletBinding(DefaultParameterSetName = "PowerLine")]
    param(
        # A script which outputs a string used to update the Window Title each time the prompt is run
        [scriptblock]$Title,

        # Keep the .Net Current Directory in sync with PowerShell's
        [Alias("CurrentDirectory")]
        [switch]$SetCurrentDirectory,

        # If true, set the [PowerLine.Prompt] static members to extended characters from PowerLine fonts
        [Parameter(ParameterSetName = "PowerLine")]
        [switch]$PowerLineFont,

        # If true, set the [PowerLine.Prompt] static members to characters available in Consolas and Courier New
        [Parameter(ParameterSetName = "Reset")]
        [switch]$ResetSeparators,

        # If true, assume full color support, otherwise normalize to 16 ConsoleColor
        [Parameter()]
        [switch]$FullColor,

        # If true, adds ENABLE_VIRTUAL_TERMINAL_PROCESSING to the console output mode. Useful on PowerShell versions that don't restore the console
        [Parameter()]
        [switch]$RestoreVirtualTerminal,

        # Add a "I ♥ PS" on a line by itself to it's prompt (using ConsoleColors, to keep it safe from PSReadLine)
        [switch]$Newline,

        # Add a right-aligned timestamp before the newline (implies Newline)
        [switch]$Timestamp,

        [switch]$HideErrors,

        # One or more scriptblocks you want to use as your new prompt
        [System.Collections.Generic.List[ScriptBlock]]$Prompt,

        # One or more colors you want to use as the prompt background
        [System.Collections.Generic.List[PoshCode.Pansies.RgbColor]]$Colors,

        # If set, calls Export-PowerLinePrompt
        [Switch]$Save

    )
    if ($null -eq $script:OldPrompt) {
        $script:OldPrompt = $function:global:prompt
        $MyInvocation.MyCommand.Module.OnRemove = {
            $function:global:prompt = $script:OldPrompt
        }
    }

    # These switches aren't stored in the config
    $null = $PSBoundParameters.Remove("Save")
    $null = $PSBoundParameters.Remove("Newline")
    $null = $PSBoundParameters.Remove("Timestamp")

    $Configuration = Import-Configuration

    # Upodate the saved PowerLinePrompt with the parameters
    if(!$Configuration.PowerLineConfig) {
        $Configuration.PowerLineConfig = @{}
    }
    $PowerLineConfig = $Configuration.PowerLineConfig | Update-Object $PSBoundParameters

    if($Configuration.ExtendedCharacters) {
        foreach($key in $Configuration.ExtendedCharacters.Keys) {
            [PoshCode.Pansies.Entities]::ExtendedCharacters.$key = $Configuration.ExtendedCharacters.$key
        }
    }

    if($Configuration.EscapeSequences) {
        foreach($key in $Configuration.EscapeSequences.Keys) {
            [PoshCode.Pansies.Entities]::EscapeSequences.$key = $Configuration.EscapeSequences.$key
        }
    }

    if ($PowerLineConfig.FullColor -eq $Null -and $Host.UI.SupportsVirtualTerminal) {
        $PowerLineConfig.FullColor = (Get-Process -Id $global:Pid).MainWindowHandle -ne 0
    }

    # For Prompt and Colors we want to support modifying the global variable outside this function
    if($PSBoundParameters.ContainsKey("Prompt")) {
        [System.Collections.Generic.List[ScriptBlock]]$global:Prompt = $Local:Prompt

    } elseif($global:Prompt.Count -eq 0 -and $PowerLineConfig.Prompt.Count -gt 0) {
        [System.Collections.Generic.List[ScriptBlock]]$global:Prompt = [ScriptBlock[]]@($PowerLineConfig.Prompt)

    } elseif($global:Prompt.Count -eq 0) {
        # The default PowerLine Prompt
        [ScriptBlock[]]$PowerLineConfig.Prompt = { $MyInvocation.HistoryId }, { Get-SegmentedPath }
        [System.Collections.Generic.List[ScriptBlock]]$global:Prompt = $PowerLineConfig.Prompt
    }

    # Prefer the existing colors over the saved colors, but not over the colors parameter
    if($PSBoundParameters.ContainsKey("Colors")) {
        InitializeColor $Colors
    } elseif($global:Prompt.Colors) {
        InitializeColor $global:Prompt.Colors
    } elseif($PowerLineConfig.Colors) {
        InitializeColor $PowerLineConfig.Colors
    } else {
        InitializeColor
    }

    if ($ResetSeparators -or ($PSBoundParameters.ContainsKey("PowerLineFont") -and !$PowerLineFont) ) {
        # Use characters that at least work in Consolas
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ColorSeparator'] = [char]0x258C
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ReverseColorSeparator'] = [char]0x2590
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Separator'] = [char]0x25BA
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ReverseSeparator'] = [char]0x25C4
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Branch'] = [char]0x00A7
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Gear'] = [char]0x263C
    }
    if ($PowerLineFont) {
        # Make sure we're using the PowerLine custom use extended characters:
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ColorSeparator'] = [char]0xe0b0
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ReverseColorSeparator'] = [char]0xe0b2
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Separator'] = [char]0xe0b1
        [PoshCode.Pansies.Entities]::ExtendedCharacters['ReverseSeparator'] = [char]0xe0b3
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Branch'] = [char]0xE0A0
        [PoshCode.Pansies.Entities]::ExtendedCharacters['Gear'] = [char]0x26EF
    }

    if($null -eq $PowerLineConfig.DefaultAddIndex) {
        $PowerLineConfig.DefaultAddIndex    = -1
    }

    $Script:PowerLineConfig = $PowerLineConfig

    if($Newline -or $Timestamp) {
        $Script:PowerLineConfig.DefaultAddIndex = $global:Prompt.Count

        @(
            if($Timestamp) {
                { "`t" }
                { Get-Elapsed }
                { Get-Date -f "T" }
            }
            { "`n" }
            { New-PromptText { "I $(New-PromptText -Fg Red -EFg White "&hearts;$([char]27)[30m") PS" } -Bg White -EBg Red -Fg Black }
        ) | Add-PowerLineBlock

        $Script:PowerLineConfig.DefaultAddIndex = @($Global:Prompt).ForEach{ $_.ToString().Trim() }.IndexOf('"`t"')
    } elseif ($PSBoundParameters.ContainsKey("Prompt")) {
        $Script:PowerLineConfig.DefaultAddIndex = -1
    }

    # Finally, update the prompt function
    $function:global:prompt = { Write-PowerlinePrompt }
    [PoshCode.Pansies.RgbColor]::ResetConsolePalette()

    # If they asked us to save, or if there's nothing saved yet
    if($Save -or ($PSBoundParameters.Count -and !(Test-Path (Join-Path (Get-StoragePath) Configuration.psd1)))) {
        Export-PowerLinePrompt
    }
}

Set-PowerLinePrompt
function Test-Elevation {
    <#
    .Synopsis
        Get a value indicating whether the process is elevated (running as administrator or root)
    #>
    [CmdletBinding()]
    param()
    if(-not ($IsLinux -or $IsOSX)) {
        [Security.Principal.WindowsIdentity]::GetCurrent().Owner.IsWellKnown("BuiltInAdministratorsSid")
    } else {
        0 -eq (id -u)
    }
}
function Test-Success {
    <#
    .Synopsis
        Get a value indicating whether the last command succeeded or not
    #>
    [CmdletBinding()]
    param()

    $script:LastSuccess
}
function Write-PowerlinePrompt {
    [CmdletBinding()]
    param()

    try {
        # FIRST, make a note if there was an error in the previous command
        [bool]$script:LastSuccess = $?
        $PromptErrors = [ordered]@{}

        # Then handle PowerLinePrompt Features:
        if ($Script:PowerLineConfig.Title) {
            try {
                $Host.UI.RawUI.WindowTitle = [System.Management.Automation.LanguagePrimitives]::ConvertTo( (& $Script:PowerLineConfig.Title), [string] )
            } catch {
                $PromptErrors.Add("0 {$($Script:PowerLineConfig.Title)}", $_)
                Write-Error "Failed to set Title from scriptblock { $($Script:PowerLineConfig.Title) }"
            }
        }
        if ($Script:PowerLineConfig.SetCurrentDirectory) {
            try {
                # Make sure Windows & .Net know where we are
                # They can only handle the FileSystem, and not in .Net Core
                [System.IO.Directory]::SetCurrentDirectory( (Get-Location -PSProvider FileSystem).ProviderPath )
            } catch {
                $PromptErrors.Add("0 { SetCurrentDirectory }", $_)
                Write-Error "Failed to set CurrentDirectory to: (Get-Location -PSProvider FileSystem).ProviderPath"
            }
        }
        if ($Script:PowerLineConfig.RestoreVirtualTerminal -and (-not $IsLinux -and -not $IsMacOS)) {
            [PoshCode.Pansies.Console.WindowsHelper]::EnableVirtualTerminalProcessing()
        }

        # Evaluate all the scriptblocks in $prompt
        $UniqueColorsCount = 0
        $PromptText = @(
            for($b = 0; $b -lt $Prompt.Count; $b++) {
                $block = $Global:Prompt[$b]
                try {
                    $outputBlock = . {
                        [CmdletBinding()]param()
                         & $block
                    } -ErrorVariable logging
                    $buffer = $(
                        if($outputBlock -as [PoshCode.Pansies.Text[]]) {
                            [PoshCode.Pansies.Text[]]$outputBlock
                        } else {
                            [PoshCode.Pansies.Text[]][string[]]$outputBlock
                        }
                    ).Where{ ![string]::IsNullOrEmpty($_.Object) }
                    # Each $buffer gets a color, if it needs one (it's not whitespace)
                    $UniqueColorsCount += [bool]$buffer.Where({ !([string]::IsNullOrWhiteSpace($_.Object)) -and !$_.BackgroundColor -and !$_.ForegroundColor }, 1)
                    , $buffer

                    # Capture errors from blocks. We'll find a way to display them...
                    if ($logging) {
                        $PromptErrors.Add("$b {$block}", $logging)
                    }
                } catch {
                    $PromptErrors.Add("$b {$block}", $_)
                }
            }
        ).Where{ $_.Object }

        # When someone sets $Prompt, they loose the colors.
        # To fix that, we cache the colors whenever we get a chance
        # And if it's not set, we re-initialize from the cache
        if(!$Global:Prompt.Colors) {
            InitializeColor
        }
        # Based on the number of text blocks, get a color gradient or the user's color choices
        [PoshCode.Pansies.RgbColor[]]$Colors = @(
            if ($Global:Prompt.Colors.Count -ge $UniqueColorsCount) {
                $Global:Prompt.Colors
            } elseif ($Global:Prompt.Colors.Count -eq 2) {
                Get-Gradient ($Global:Prompt.Colors[0]) ($Global:Prompt.Colors[1]) -Count $UniqueColorsCount -Flatten
            } else {
                $Global:Prompt.Colors * ([Math]::Ceiling($UniqueColorsCount/$Global:Prompt.Colors.Count))
            }
        )

        # Loop through the text blocks and set colors
        $ColorIndex = 0
        foreach ($block in $PromptText) {
            $ColorUsed = $False
            foreach ($b in @($block)) {
                if (![string]::IsNullOrWhiteSpace($b.Object) -and $null -eq $b.BackgroundColor) {
                    $b.BackgroundColor = $Colors[$ColorIndex]
                    $ColorUsed = $True
                }
            }
            $ColorIndex += $ColorUsed

            foreach ($b in @($block)) {
                if ($null -ne $b.BackgroundColor -and $null -eq $b.ForegroundColor) {
                    if($Script:PowerLineConfig.FullColor) {
                        $b.ForegroundColor = Get-Complement $b.BackgroundColor -ForceContrast
                    } else {
                        $b.BackgroundColor, $b.ForegroundColor = Get-Complement $b.BackgroundColor -ConsoleColor -Passthru
                    }
                }
            }
        }

        ## Finally, unroll all the output and join into one string (using separators and spacing)
        $Buffer = $PromptText | ForEach-Object { $_ }
        $extraLineCount = 0
        $line = ""
        $result = ""
        $RightAligned = $False
        $BufferWidth = [Console]::BufferWidth
        $ColorSeparator = "&ColorSeparator;"
        $Separator = "&Separator;"
        $LastBackground = $null
        for ($b = 0; $b -lt $Buffer.Count; $b++) {
            $block = $Buffer[$b]
            $string = $block.ToString()
            # Write-Debug "STEP $b of $($Buffer.Count) [$(($String -replace "\u001B.*?\p{L}").Length)] $($String -replace "\u001B.*?\p{L}" -replace "`n","{newline}" -replace "`t","{tab}")"

            ## Allow `t to split into (2) columns:
            if ($string -eq "`t") {
                if($LastBackground) {
                    ## Before the (column) break, add a cap
                    #Write-Debug "Pre column-break, add a $LastBackground cap"
                    $line += [PoshCode.Pansies.Text]@{
                        Object          = "$ColorSeparator "
                        ForegroundColor = $LastBackground
                        BackgroundColor = $Host.UI.RawUI.BackgroundColor
                    }
                }
                $result += $line
                $line = ""
                $RightAligned = $True
                $ColorSeparator = "&ReverseColorSeparator;"
                $Separator = "&ReverseSeparator;"
                $LastBackground = $Host.UI.RawUI.BackgroundColor
            ## Allow `n to create multi-line prompts
            } elseif ($string -in "`n", "`r`n") {
                if($RightAligned) {
                    ## This is a VERY simplistic test for escape sequences
                    $lineLength = ($line -replace "\u001B.*?\p{L}").Length
                    $Align = $BufferWidth - $lineLength
                    #Write-Debug "The buffer is $($BufferWidth) wide, and the line is $($lineLength) long so we're aligning to $($Align)"
                    $result += [PoshCode.Pansies.Text]::new("&Esc;$($Align)G ")
                    $RightAligned = $False
                } else {
                    $line += [PoshCode.Pansies.Text]@{
                        Object          = "$ColorSeparator"
                        ForegroundColor = $LastBackground
                        BackgroundColor = $Host.UI.RawUI.BackgroundColor
                    }
                }
                $extraLineCount++
                $result += $line + "`n"
                $line = ""
                $ColorSeparator = "&ColorSeparator;"
                $Separator = "&Separator;"
                $LastBackground = $null
            } elseif(![string]::IsNullOrWhiteSpace($string)) {
                ## If the output is just color sequences, toss it
                if(($String -replace "\u001B.*?\p{L}").Length -eq 0) {
                    #Write-Debug "Skip empty output, staying $LastBackground"
                    continue
                }
                if($LastBackground -or $RightAligned) {
                    $line += if($block.BackgroundColor -ne $LastBackground) {
                        [PoshCode.Pansies.Text]@{
                            Object          = $ColorSeparator
                            ForegroundColor = ($LastBackground, $block.BackgroundColor)[$RightAligned]
                            BackgroundColor = ($block.BackgroundColor, $LastBackground)[$RightAligned]
                        }
                    } else {
                        [PoshCode.Pansies.Text]@{
                            Object          = $Separator
                            BackgroundColor = $block.BackgroundColor
                            ForegroundColor = $block.ForegroundColor
                        }
                    }
                }
                $line += $string
                $LastBackground = $block.BackgroundColor
                #Write-Debug "Normal output ($($string -replace "\u001B.*?\p{L}")) ($($($string -replace "\u001B.*?\p{L}").Length)) on $LastBackground"
            }
        }

        [string]$PromptErrorString = if (-not $Script:PowerLineConfig.HideErrors) {
            WriteExceptions $PromptErrors
        }
        # At the end, output everything as one single string
        # create the number of lines we need for output up front:
        ("`n" * ($extraLineCount+1)) + ("$([char]27)M" * ($extraLineCount+1)) +
        $PromptErrorString + $result + $line + ([PoshCode.Pansies.Text]@{
            Object          = "$([char]27)[49m$ColorSeparator&Clear;"
            ForegroundColor = $LastBackground
        })
    } catch {
        Write-Warning "Exception in PowerLinePrompt`n$_"
        "${PWD}>"
    }
}

# SIG # Begin signature block
# MIIXzgYJKoZIhvcNAQcCoIIXvzCCF7sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3e3epU/t/NVmvIGSTdoka71S
# 7mKgghMBMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggUwMIIEGKADAgEC
# AhALDZkX0sdOvwJhwzQTbV+7MA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMTgwNzEyMDAwMDAwWhcNMTkwNzE2MTIwMDAwWjBtMQswCQYDVQQG
# EwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3QgSGVucmlldHRh
# MRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pvZWwgSC4gQmVu
# bmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMJb3Cf3n+/pFJiO
# hQqN5m54FpyIktMRWe5VyF8465BnAtzw3ivMyN+3k8IoXQhMxpCsY1TJbLyydNR2
# QzwEEtGfcTVnlAJdFFlBsgIdK43waaML5EG7tzNJKhHQDiN9bVhLPTXrit80eCTI
# RpOA7435oVG8erDpxhJUK364myUrmSyF9SbUX7uE09CJJgtB7vqetl4G+1j+iFDN
# Xi3bu1BFMWJp+TtICM+Zc5Wb+ZaYAE6V8t5GCyH1nlAI3cPjqVm8y5NoynZTfOhV
# bHiV0QI2K5WrBBboR0q6nd4cy6NJ8u5axi6CdUhnDMH20NN2I0v+2MBkgLAzxPrX
# kjnaEGECAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZl
# dQ5YMB0GA1UdDgQWBBTiwur/NVanABEKwjZDB3g6SZN1mTAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGG
# L2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MEwGA1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcw
# AoZCaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3Vy
# ZWRJRENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
# BQADggEBADNNHuRAdX0ddONqaUf3H3pwa1K016C02P90xDIyMvw+hiUb4Z/xewnY
# jyplspD0NQB9ca2pnNIy1KwjJryRgq8gl3epSiWTbViVn6VDK2h0JXm54H6hczQ8
# sEshCW53znNVUUUfxGsVM9kMcwITHYftciW0J+SsGcfuuAIuF1g47KQXKWOMcUQl
# yrP5t0ywotTVcg/1HWAPFE0V0sFy+Or4n81+BWXOLaCXIeeryLYncAVUBT1DI6lk
# peRUj/99kkn+hz1q4hHTtfNpMTOApP64EEFGKICKkJdvhs1PjtGa+QdAkhcInTxk
# t/hIJPUb1nO4CsKp1gaVsRkkbcStJ2kxggQ3MIIEMwIBATCBhjByMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBT
# aWduaW5nIENBAhALDZkX0sdOvwJhwzQTbV+7MAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSIopGH
# jMMtQoSJpdlGkhbe3T9sxzANBgkqhkiG9w0BAQEFAASCAQC/81yjMkyolyGaiL22
# pKzfZp589M0yhg4nx65JPPDKlCbOFv+aqc/YlprnPjh3NiS2OR29dxyLMQpl6XWM
# 9w3F7YFio60M3BeyessQiT2X3V/4CQQV+gXQfCvjGpvigCIw+0MWFOrYk99hr5Pw
# 5r9d9b9zCbi0OXTxDgdZynpEIvY6l0Wrc7N9W84AwwzMHjKhvAtjYQDKr2yBKHwb
# g5s0rtxzgx196CEMTEJo1r5iRS01RaWQoXc8qt3APwFXMzCCYX+TlvvG4T731T8m
# ZReGVVeynkHCkB3CkpPP4yHudCikMrjLlBauXc17Ig8gQPGrdjrtU+hN3dwtUGbi
# oG6roYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE5MDQyNzA0MzIxNVowIwYJKoZIhvcNAQkEMRYEFPPx3+hH
# h8YK5bOydOd/b1ESEybSMA0GCSqGSIb3DQEBAQUABIIBAEPvYs9MKxLWaLsXPwUv
# UqTy3Q8/YibHlooHHFXAgN1TkL3Yp5N36seEanpwB6iaMOYVufbJ1okE97bSK92E
# If0oIDtYh9//0pCQUVrGYhair0jiroEO0e/WJhPosh3ckTdbZynfj6kEc+MUJHpV
# 4mrcJ1fXwHfVjEh6Lj2PByG4Sj1pS09YWJS8CIeS5SdQcytnv/Gveaq/S222yZur
# QvyDXfqODEVAzZjc5hFwdg5/wi1poakZ3CEfbmWxfb+Cz5hYrU/F5fYzJcLh+w+T
# RfUvKRKAuFZZTXwvKMYsCFpb0nr88JR4uwpF4zJOFfJBeFWQ4ooLEkKhntOzd57O
# nXc=
# SIG # End signature block
