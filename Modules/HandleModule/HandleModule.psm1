# Module created by Microsoft.PowerShell.Crescendo
# Version: 1.1.0
# Schema: https://aka.ms/Crescendo/Schema.json
# Generated at: 08/22/2024 12:50:55
class PowerShellCustomFunctionAttribute : System.Attribute {
    [bool]$RequiresElevation
    [string]$Source
    PowerShellCustomFunctionAttribute() { $this.RequiresElevation = $false; $this.Source = "Microsoft.PowerShell.Crescendo" }
    PowerShellCustomFunctionAttribute([bool]$rElevation) {
        $this.RequiresElevation = $rElevation
        $this.Source = "Microsoft.PowerShell.Crescendo"
    }
}

# Returns available errors
# Assumes that we are being called from within a script cmdlet when EmitAsError is used.
function Pop-CrescendoNativeError {
param ([switch]$EmitAsError)
    while ($__CrescendoNativeErrorQueue.Count -gt 0) {
        if ($EmitAsError) {
            $msg = $__CrescendoNativeErrorQueue.Dequeue()
            $er = [System.Management.Automation.ErrorRecord]::new([system.invalidoperationexception]::new($msg), $PSCmdlet.Name, "InvalidOperation", $msg)
            $PSCmdlet.WriteError($er)
        }
        else {
            $__CrescendoNativeErrorQueue.Dequeue()
        }
    }
}
# this is purposefully a filter rather than a function for streaming errors
filter Push-CrescendoNativeError {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        $__CrescendoNativeErrorQueue.Enqueue($_)
    }
    else {
        $_
    }
}

function Get-OpenFile
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding()]

param(
[Parameter(Position=0)]
[string]$FileName
    )

BEGIN {
    $PSNativeCommandUseErrorActionPreference = $false
    $__CrescendoNativeErrorQueue = [System.Collections.Queue]::new()
    $__PARAMETERMAP = @{
         FileName = @{
               OriginalName = ''
               OriginalPosition = '0'
               Position = '0'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $False
               ArgumentTransform = '$args'
               ArgumentTransformType = 'inline'
               }
    }

    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'Parse-HandleOutput' }
    }
}

PROCESS {
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Where-Object {!$__PARAMETERMAP[$_].ExcludeAsArgument}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                # if a transform is specified, use it and the construction of the values is up to the transform
                if($param.ArgumentTransform -ne '$args') {
                    $transform = $param.ArgumentTransform
                    if($param.ArgumentTransformType -eq 'inline') {
                        $transform = [scriptblock]::Create($param.ArgumentTransform)
                    }
                    $__commandArgs += & $transform $value
                }
                else {
                    $pFmt = "{0}{1}"
                    # quote the strings if they have spaces
                    if($value -match "\s") { $pFmt = "{0}""{1}""" }
                    $__commandArgs += $pFmt -f $param.OriginalName, $value
                }
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                if($param.ArgumentTransformType -eq 'inline') {
                   $transform = [scriptblock]::Create($param.ArgumentTransform)
                }
                else {
                   $transform = $param.ArgumentTransform
                }
                $__commandArgs += & $transform $value
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message "handle.exe"
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("handle.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "handle.exe")) {
          throw "Cannot find executable 'handle.exe'"
        }
        if ( $__handlerInfo.StreamOutput ) {
            if ( $null -eq $__handler ) {
                & "handle.exe" $__commandArgs
            }
            else {
                & "handle.exe" $__commandArgs 2>&1| Push-CrescendoNativeError | & $__handler
            }
        }
        else {
            $result = & "handle.exe" $__commandArgs 2>&1| Push-CrescendoNativeError
            & $__handler $result
        }
    }
    # be sure to let the user know if there are any errors
    Pop-CrescendoNativeError -EmitAsError
  } # end PROCESS

<#
.SYNOPSIS

Nthandle v5.0 - Handle viewer
Copyright (C) 1997-2022 Mark Russinovich
Sysinternals - www.sysinternals.com

usage: handle [[-a [-l]] [-v|-vt] [-u] | [-c <handle> [-y]] | [-s]] [-p <process>|<pid>] [name] [-nobanner]
  -a         Dump all handle information.
  -l         Just show pagefile-backed section handles.
  -c         Closes the specified handle (interpreted as a hexadecimal number).
             You must specify the process by its PID. Requires administrator
             rights.
             WARNING: Closing handles can cause application or system instability.
  -g         Print granted access.
  -y         Don't prompt for close handle confirmation.
  -s         Print count of each type of handle open.
  -u         Show the owning user name when searching for handles.
  -v         CSV output with comma delimiter.
  -vt        CSV output with tab delimiter.
  -p         Dump handles belonging to process (partial name accepted).
  name       Search for handles to objects with <name> (fragment accepted).
  -nobanner  Do not display the startup banner and copyright message.

No arguments will dump all file references.

.DESCRIPTION See help for handle.exe

.PARAMETER FileName




#>
}


function Parse-HandleOutput {
    param (
        [string]$output
    )
    # Split the output into lines
    $lines = $output -split "`n"
    # Filter out the banner lines (assuming the banner is the first few lines)
    $filteredLines = $lines | Where-Object { $_ -notmatch "^\s*Handle v" -and $_ -notmatch "^\s*Copyright" -and $_ -notmatch "^\s*Sysinternals" }
    # Parse the remaining lines and convert them to PowerShell objects
    $filteredLines | ForEach-Object {
        # Assuming the output format is "ProcessName PID HandleType HandleValue FilePath"
        if ($_ -match "^(?<ProcessName>\S+)\s+(?<PID>\d+)\s+(?<HandleType>\S+)\s+(?<HandleValue>\S+)\s+(?<FilePath>.+)$") {
            [pscustomobject]@{
                ProcessName = $matches['ProcessName']
                PID         = $matches['PID']
                HandleType  = $matches['HandleType']
                HandleValue = $matches['HandleValue']
                FilePath    = $matches['FilePath']
            }
        }
    }
}
