# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License
# this contains code common for all generators
# OM VERSION 1.2
# =========================================================================
using namespace System.Collections.Generic
class UsageInfo { # used for .SYNOPSIS of the comment-based help
    [string]$Synopsis
    [bool]$SupportsFlags
    [bool]$HasOptions
    hidden [string[]]$OriginalText

    UsageInfo() { }
    UsageInfo([string] $synopsis)
    {
        $this.Synopsis = $synopsis
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        return ((".SYNOPSIS",$this.synopsis) -join "`n")
    }
}

class ExampleInfo { # used for .EXAMPLE of the comment-based help
    [string]$Command # ps-command
    [string]$OriginalCommand # original native tool command
    [string]$Description

    ExampleInfo() { }

    ExampleInfo([string]$Command, [string]$OriginalCommand, [string]$Description)
    {
        $this.Command = $Command
        $this.OriginalCommand = $OriginalCommand
        $this.Description = $description
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        $sb = [text.stringbuilder]::new()
        $sb.AppendLine(".EXAMPLE")
        $sb.AppendLine("PS> " + $this.Command)
        $sb.AppendLine("")
        $sb.AppendLine($this.Description)
        if ($this.OriginalCommand) {
            $sb.AppendLine("Original Command: " + $this.OriginalCommand)
        }
        return $sb.ToString()
    }
}

class ParameterInfo {
    [string]$Name # PS-function name
    [string]$OriginalName # original native parameter name

    [string]$OriginalText
    [string]$Description
    [string]$DefaultValue
    # some parameters are -param or +param which can be represented with a switch parameter
    # so we need way to provide for this
    [string]$DefaultMissingValue
    # this is in case that the parameters apply before the OriginalCommandElements
    [bool]$ApplyToExecutable
    [bool]$ExcludeAsArgument # when true, we don't pass this parameter to the native application at all
    [string]$ParameterType = 'object' # PS type

    [string[]]$AdditionalParameterAttributes

    [bool] $Mandatory
    [string[]] $ParameterSetName
    [string[]] $Aliases
    [int] $Position = [int]::MaxValue
    [int] $OriginalPosition
    [bool] $ValueFromPipeline
    [bool] $ValueFromPipelineByPropertyName
    [bool] $ValueFromRemainingArguments
    [bool] $NoGap # this means that we need to construct the parameter as "foo=bar"

    # This is a scriptblock, file or function which will transform the value(s) of the parameter
    # If the value needs to be transformed, this is the scriptblock to do it
    [string]$ArgumentTransform
    # this can be inline, file, or function
    # the default is inline, but we will follow the same logic as for output handlers
    # if 'function' we will inspect the current environment for the function and embed it in the module
    # if 'file' we will hunt for the file in the current environment and copy it to the module location
    # the value as a single object will be passed as an argument to the scriptblock/file/function
    [string]$ArgumentTransformType

    ParameterInfo() {
        $this.Position = [int]::MaxValue
    }
    ParameterInfo ([string]$Name, [string]$OriginalName)
    {
        $this.Name = $Name
        $this.OriginalName = $OriginalName
        $this.Position = [int]::MaxValue
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        if ($this.Name -eq [string]::Empty) {
            return $null
        }
        $sb = [System.Text.StringBuilder]::new()
        if ( $this.AdditionalParameterAttributes )
        {
            foreach($s in $this.AdditionalParameterAttributes) {
                $sb.AppendLine($s)
            }
        }

        if ( $this.Aliases ) {
            $paramAliases = $this.Aliases -join "','"
            $sb.AppendLine("[Alias('" + $paramAliases + "')]")
        }

        # TODO: This logic does not handle parameters in multiple sets correctly

        $elements = @()
        if ( $this.ParameterSetName.Count -eq 0) {
            $sb.Append('[Parameter(')
            if ( $this.Position -ne [int]::MaxValue ) { $elements += "Position=" + $this.Position }
            if ( $this.ValueFromPipeline ) { $elements += 'ValueFromPipeline=$true' }
            if ( $this.ValueFromPipelineByPropertyName ) { $elements += 'ValueFromPipelineByPropertyName=$true' }
            if ( $this.Mandatory ) { $elements += 'Mandatory=$true' }
            if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
            if ($elements.Count -gt 0) { $sb.Append(($elements -join ",")) }
            $sb.AppendLine(')]')
        }
        else {
            foreach($parameterSetName in $this.ParameterSetName) {
                $sb.Append('[Parameter(')
                if ( $this.Position -ne [int]::MaxValue ) { $elements += "Position=" + $this.Position }
                if ( $this.ValueFromPipeline ) { $elements += 'ValueFromPipeline=$true' }
                if ( $this.ValueFromPipelineByPropertyName ) { $elements += 'ValueFromPipelineByPropertyName=$true' }
                if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
                if ( $this.Mandatory ) { $elements += 'Mandatory=$true' }
                $elements += "ParameterSetName='{0}'" -f $parameterSetName
                if ($elements.Count -gt 0) { $sb.Append(($elements -join ",")) }
                $sb.AppendLine(')]')
                $elements = @()
            }
        }

        #if ( $this.ParameterSetName.Count -gt 1) {
        #    $this.ParameterSetName.ForEach({$sb.AppendLine(('[Parameter(ParameterSetName="{0}")]' -f $_))})
        #}
        # we need a way to find those parameters which have default values
        # because they need to be added to the command arguments. We can
        # search through the parameters for this attribute.
        # We may need to handle collections as well.
        if ( $null -ne $this.DefaultValue ) {
                $sb.AppendLine(('[PSDefaultValue(Value="{0}")]' -f $this.DefaultValue))
        }
        $sb.Append(('[{0}]${1}' -f $this.ParameterType, $this.Name))
        if ( $this.DefaultValue ) {
            $sb.Append(' = "' + $this.DefaultValue + '"')
        }

        return $sb.ToString()
    }

    [string]GetParameterHelp()
    {
        $parameterSb = [System.Text.StringBuilder]::new()
        $null = $parameterSb.Append(".PARAMETER ")
        $null = $parameterSb.AppendLine($this.Name)
        $null = $parameterSb.AppendLine($this.Description)
        $null = $parameterSb.AppendLine()
        return $parameterSb.ToString()
    }
}

class OutputHandler {
    [string]$ParameterSetName
    [string]$Handler # This is a scriptblock which does the conversion to an object
    [string]$HandlerType # Inline, Function, Script, or ByPass
    [bool]$StreamOutput # this indicates whether the output should be streamed to the handler
    OutputHandler() {
        $this.HandlerType = "Inline" # default is an inline script
    }
    [string]ToString() {
        $s = '        '
        if ($this.HandlerType -eq "ByPass") {
            $s += '{0} = @{{ StreamOutput = $true; Handler = $null }}' -f $this.ParameterSetName
        }
        elseif ($this.HandlerType -eq "Inline") {
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = {{ {2} }} }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        elseif ($this.HandlerType -eq "Script") {
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = "${{PSScriptRoot}}/{2}" }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        else { # function
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = ''{2}'' }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        return $s
    }
}

class Elevation {
    [string]$Command
    [List[ParameterInfo]]$Arguments
}

class Command {
    [string]$Verb # PS-function name verb
    [string]$Noun # PS-function name noun


    [string]$OriginalName # e.g. "cubectl get user" -> "cubectl"
    [string[]]$OriginalCommandElements # e.g. "cubectl get user" -> "get", "user"
    [string[]]$Platform # can be any (or all) of "Windows","Linux","MacOS"

    [Elevation]$Elevation

    [string[]] $Aliases
    [string] $DefaultParameterSetName
    [bool] $SupportsShouldProcess
    [string] $ConfirmImpact
    [bool] $SupportsTransactions
    [bool] $NoInvocation # certain scenarios want to use the generated code as a front end. When true, the generated code will return the arguments only.

    [string]$Description
    [UsageInfo]$Usage
    [List[ParameterInfo]]$Parameters
    [List[ExampleInfo]]$Examples
    [string]$OriginalText
    [string[]]$HelpLinks

    [OutputHandler[]]$OutputHandlers

    Command() {
        $this.Platform = "Windows","Linux","MacOS"
    }
    Command([string]$Verb, [string]$Noun)
    {
        $this.Verb = $Verb
        $this.Noun = $Noun
        $this.Parameters = [List[ParameterInfo]]::new()
        $this.Examples = [List[ExampleInfo]]::new()
        $this.Platform = "Windows","Linux","MacOS"
    }

    [string]GetDescription() {
        if ( $this.Description ) {
            return (".DESCRIPTION",$this.Description -join "`n")
        }
        else {
            return (".DESCRIPTION",("See help for {0}" -f $this.OriginalName))
        }
    }

    [string]GetSynopsis() {
        if ( $this.Description ) {
            return ([string]$this.Usage)
        }
        else { # try running the command with -?
            if ( Get-Command $this.OriginalName -ErrorAction ignore ) {
                try {
                    $origOutput = & $this.OriginalName -? 2>&1
                    $nativeHelpText = $origOutput -join "`n"
                }
                catch {
                    $nativeHelpText = "error running " + $this.OriginalName + " -?."
                }
            }
            else {
                $nativeHelpText = "Could not find " + $this.OriginalName + " to generate help."

            }
            return (".SYNOPSIS",$nativeHelpText) -join "`n"
        }
    }

    # collect the output handler functions and the argument transform functions
    [void]TestFunctionHandlers()
    {
        # TODO: check for duplicate names
        if ( $this.OutputHandlers ) {
            foreach ($handler in $this.OutputHandlers ) {
                if ( $handler.HandlerType -eq "Function" ) {
                    $handlerName = $handler.Handler
                    $functionHandler = Get-Content function:$handlerName -ErrorAction Ignore
                    if ( $null -eq $functionHandler ) {
                        throw "Cannot find output handler function '$handlerName'."
                    }
                }
            }
        }
        if ( $this.Parameters ) {
            $transformFunctions = $this.Parameters.Where({$_.ArgumentTransformType -eq "Function"}) | Sort-Object -Unique -Property ArgumentTransform
            foreach ($transform in $transformFunctions) {
                $tName = $transform.ArgumentTransform
                $transformHandler = Get-Content function:$tName -ErrorAction Ignore
                if ( $null -eq $transformHandler ) {
                    throw "Cannot find argument transform function '$tName'."
                }
            }
        }
    }

    [string]ToString()
    {
        return $this.ToString($false)
    }

    [string]GetBeginBlock()
    {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("BEGIN {")
        # create a queue for the errors, and turn off the native error action preference
        $sb.AppendLine('    $PSNativeCommandUseErrorActionPreference = $false')
        $sb.AppendLine('    $__CrescendoNativeErrorQueue = [System.Collections.Queue]::new()')
        # get the parameter map, this may be null if there are no parameters
        $parameterMap = $this.GetParameterMap()
        if ( $parameterMap ) {
            $sb.AppendLine($parameterMap)
        }
        # Provide for the scriptblocks which handle the output
        if ( $this.OutputHandlers ) {
            $sb.AppendLine('    $__outputHandlers = @{')
            foreach($handler in $this.OutputHandlers) {
                $sb.AppendLine($handler.ToString())
            }
            $sb.AppendLine('    }')
        }
        else {
            $sb.AppendLine('    $__outputHandlers = @{ Default = @{ StreamOutput = $true; Handler = { $input; Pop-CrescendoNativeError -EmitAsError } } }')
        }
        $sb.AppendLine("}") # END BEGIN
        return $sb.ToString()
    }

    [string]GetProcessBlock()
    {
        # construct the command invocation
        # this must exist and should never be null
        # otherwise we won't actually be invoking anything
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("PROCESS {")
        $sb.AppendLine('    $__boundParameters = $PSBoundParameters')
        # now add those parameters which have default values excluding the ubiquitous parameters
        $sb.AppendLine('    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name')
        $sb.AppendLine('    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})')
        $sb.AppendLine('    $__commandArgs = @()')
        $sb.AppendLine('    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})')
        $sb.AppendLine('    if ($__boundParameters["Debug"]){wait-debugger}')
        if ($this.Parameters.Where({$_.ApplyToExecutable -and ! $_.ExcludeAsArgument})) {
            $sb.AppendLine('    # look for those parameter values which apply to the executable and must be before the original command elements')
            $sb.AppendLine('    foreach ($paramName in $__boundParameters.Keys|Where-Object {$__PARAMETERMAP[$_].ApplyToExecutable}) {') # take those parameters which apply to the executable
            $sb.AppendLine('        $value = $__boundParameters[$paramName]')
            $sb.AppendLine('        $param = $__PARAMETERMAP[$paramName]')
            $sb.AppendLine('        if ($param) {')
            $sb.AppendLine('            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }')
            $sb.AppendLine('            elseif ( $param.NoGap ) { $__commandArgs += "{0}{1}" -f $param.OriginalName, $value }')
            $sb.AppendLine('            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}')
            $sb.AppendLine('        }')
            $sb.AppendLine('    }')
        }
        # now the original command elements may be added
        if ($this.OriginalCommandElements.Count -ne 0) {
            foreach($element in $this.OriginalCommandElements) {
                # we use single quotes here to reduce injection attacks
                $sb.AppendLine(('    $__commandArgs += ''{0}''' -f $element))
            }
        }
        $sb.AppendLine($this.GetInvocationCommand())

        # add the help
        $help = $this.GetCommandHelp()
        if ($help) {
            $sb.AppendLine($help)
        }
        # finish the block
        $sb.AppendLine("}")
        return $sb.ToString()
    }

    # emit the function, if EmitAttribute is true, the Crescendo attribute will be included
    [string]ToString([bool]$EmitAttribute)
    {
        # Test output handler and argument transforms for availability.
        # These are fatal errors if one is missing since we have to 
        # code it into the .psm1.
        $this.TestFunctionHandlers()

        $sb = [System.Text.StringBuilder]::new()
        # get the command declaration
        $sb.AppendLine($this.GetCommandDeclaration($EmitAttribute))
        # We will always provide a parameter block, even if it's empty
        $sb.AppendLine($this.GetParameters())

        # get the begin block
        $sb.AppendLine($this.GetBeginBlock())

        # get the process block
        $sb.AppendLine($this.GetProcessBlock())

        # return $this.Verb + "-" + $this.Noun
        return $sb.ToString()
    }

    [string]GetParameterMap() {
        $sb = [System.Text.StringBuilder]::new()
        if ( $this.Parameters.Count -eq 0 ) {
            return '    $__PARAMETERMAP = @{}'
        }
        $sb.AppendLine('    $__PARAMETERMAP = @{')
        foreach($parameter in $this.Parameters) {
            $sb.AppendLine(('         {0} = @{{' -f $parameter.Name))
            $sb.AppendLine(('               OriginalName = ''{0}''' -f $parameter.OriginalName))
            $sb.AppendLine(('               OriginalPosition = ''{0}''' -f $parameter.OriginalPosition))
            $sb.AppendLine(('               Position = ''{0}''' -f $parameter.Position))
            $sb.AppendLine(('               ParameterType = ''{0}''' -f $parameter.ParameterType))
            $sb.AppendLine(('               ApplyToExecutable = ${0}' -f $parameter.ApplyToExecutable))
            $sb.AppendLine(('               NoGap = ${0}' -f $parameter.NoGap))
            if ($parameter.ExcludeAsArgument) {
                $sb.AppendLine(('               ExcludeAsArgument = ${0}' -f $parameter.ExcludeAsArgument))
            }
            if($parameter.DefaultMissingValue) {
                $sb.AppendLine(('               DefaultMissingValue = ''{0}''' -f $parameter.DefaultMissingValue))
            }
            # Add the transform if present
            if($parameter.ArgumentTransform) {
                $sb.AppendLine(('               ArgumentTransform = ''{0}''' -f $parameter.ArgumentTransform))
                $trType = $parameter.ArgumentTransformType
                $sb.AppendLine(('               ArgumentTransformType = ''{0}''' -f (($null -eq $trType) ? 'inline' : $trType)))
            }
            else {
                # by default, pass the arguments as is - we stream it (which used to happen in the code below)
                $sb.AppendLine(('               ArgumentTransform = ''$args'''))
                $sb.AppendLine(('               ArgumentTransformType = ''inline'''))
            }
            $sb.AppendLine('               }')
        }
        # end parameter map
        $sb.AppendLine("    }")
        return $sb.ToString()
    }

    [string]GetCommandHelp() {
        $helpSb = [System.Text.StringBuilder]::new()
        $helpSb.AppendLine("<#")
        $helpSb.AppendLine($this.GetSynopsis())
        $helpSb.AppendLine()
        $helpSb.AppendLine($this.GetDescription())
        $helpSb.AppendLine()
        if ( $this.Parameters.Count -gt 0 ) {
            foreach ( $parameter in $this.Parameters) {
                $helpSb.AppendLine($parameter.GetParameterHelp())
            }
            $helpSb.AppendLine();
        }
        if ( $this.Examples.Count -gt 0 ) {
            foreach ( $example in $this.Examples ) {
                $helpSb.AppendLine($example.ToString())
                $helpSb.AppendLine()
            }
        }
        if ( $this.HelpLinks.Count -gt 0 ) {
            $helpSB.AppendLine(".LINK");
            foreach ( $link in $this.HelpLinks ) {
                $helpSB.AppendLine($link.ToString())
            }
            $helpSb.AppendLine()
        }
        $helpSb.Append("#>")
        return $helpSb.ToString()
    }

    # this is where the logic of actually calling the command is created
    [string]GetInvocationCommand() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('    foreach ($paramName in $__boundParameters.Keys|')
        $sb.AppendLine('            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|') # skip those parameters which apply to the executable
        $sb.AppendLine('            Where-Object {!$__PARAMETERMAP[$_].ExcludeAsArgument}|') # skip those parameters which are to be excluded
        $sb.AppendLine('            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {')
        $sb.AppendLine('        $value = $__boundParameters[$paramName]')
        $sb.AppendLine('        $param = $__PARAMETERMAP[$paramName]')
        $sb.AppendLine('        if ($param) {')
        $sb.AppendLine('            if ($value -is [switch]) {')
        $sb.AppendLine('                 if ($value.IsPresent) {')
        $sb.AppendLine('                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }')
        $sb.AppendLine('                 }')
        $sb.AppendLine('                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }')
        $sb.AppendLine('            }')
        $sb.AppendLine('            elseif ( $param.NoGap ) {')
        $sb.AppendLine('                # if a transform is specified, use it and the construction of the values is up to the transform')
        $sb.AppendLine('                if($param.ArgumentTransform -ne ''$args'') {')
        $sb.AppendLine('                    $transform = $param.ArgumentTransform')
        $sb.AppendLine('                    if($param.ArgumentTransformType -eq ''inline'') {')
        $sb.AppendLine('                        $transform = [scriptblock]::Create($param.ArgumentTransform)')
        $sb.AppendLine('                    }')
        $sb.AppendLine('                    $__commandArgs += & $transform $value')
        $sb.AppendLine('                }')
        $sb.AppendLine('                else {')
        $sb.AppendLine('                    $pFmt = "{0}{1}"')
        $sb.AppendLine('                    # quote the strings if they have spaces')
        $sb.AppendLine('                    if($value -match "\s") { $pFmt = "{0}""{1}""" }')
        $sb.AppendLine('                    $__commandArgs += $pFmt -f $param.OriginalName, $value')
        $sb.AppendLine('                }')
        $sb.AppendLine('            }')
        $sb.AppendLine('            else {')
        $sb.AppendLine('                if($param.OriginalName) { $__commandArgs += $param.OriginalName }')
        $sb.AppendLine('                if($param.ArgumentTransformType -eq ''inline'') {')
        $sb.AppendLine('                   $transform = [scriptblock]::Create($param.ArgumentTransform)')
        $sb.AppendLine('                }')
        $sb.AppendLine('                else {')
        $sb.AppendLine('                   $transform = $param.ArgumentTransform')
        $sb.AppendLine('                }')
        $sb.AppendLine('                $__commandArgs += & $transform $value')
        $sb.AppendLine('            }')
        $sb.AppendLine('        }')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}') # strip only nulls
        if ( $this.NoInvocation ) {
        $sb.AppendLine('    return $__commandArgs')
        }
        else {
        $sb.AppendLine('    if ($__boundParameters["Debug"]){wait-debugger}')
        $sb.AppendLine('    if ( $__boundParameters["Verbose"]) {')
        $sb.AppendLine('         Write-Verbose -Verbose -Message "' + $this.OriginalName + '"')
        $sb.AppendLine('         $__commandArgs | Write-Verbose -Verbose')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]')
        $sb.AppendLine('    if (! $__handlerInfo ) {')
        $sb.AppendLine('        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__handler = $__handlerInfo.Handler')
        $sb.AppendLine('    if ( $PSCmdlet.ShouldProcess("' + $this.OriginalName + ' $__commandArgs")) {')
        $sb.AppendLine('    # check for the application and throw if it cannot be found')
        $sb.AppendLine('        if ( -not (Get-Command -ErrorAction Ignore "' + $this.OriginalName + '")) {')
        $sb.AppendLine('          throw "Cannot find executable ''' + $this.OriginalName + '''"')
        $sb.AppendLine('        }')
        $sb.AppendLine('        if ( $__handlerInfo.StreamOutput ) {')
        $__bypassCmdLine = '                & "{0}" $__commandArgs' -f $this.OriginalName
        if ( $this.Elevation.Command ) {
            $__elevationArgs = $($this.Elevation.Arguments | Foreach-Object { "{0} {1}" -f $_.OriginalName, $_.DefaultValue }) -join " "
            $__cmdLine =  '                & "{0}" {1} "{2}" $__commandArgs' -f $this.Elevation.Command, $__elevationArgs, $this.OriginalName
        }
        else {
            $__cmdLine =  '                & "{0}" $__commandArgs 2>&1| Push-CrescendoNativeError | & $__handler' -f $this.OriginalName
        }
        $sb.AppendLine('            if ( $null -eq $__handler ) {')
        $sb.AppendLine("$__bypassCmdLine")
        $sb.AppendLine('            }')
        $sb.AppendLine('            else {')
        $sb.AppendLine("$__cmdLine")
        $sb.AppendLine('            }')

        $sb.AppendLine('        }')
        $sb.AppendLine('        else {')
        if ( $this.Elevation.Command ) {
            $__elevationArgs = $($this.Elevation.Arguments | Foreach-Object { "{0} {1}" -f $_.OriginalName, $_.DefaultValue }) -join " "
            $sb.AppendLine(('            $result = & "{0}" {1} "{2}" $__commandArgs 2>&1| Push-CrescendoNativeError' -f $this.Elevation.Command, $__elevationArgs, $this.OriginalName))
        }
        else {
            $sb.AppendLine(('            $result = & "{0}" $__commandArgs 2>&1| Push-CrescendoNativeError' -f $this.OriginalName))
        }
        $sb.AppendLine('            & $__handler $result')
        $sb.AppendLine('        }')
        $sb.AppendLine("    }")
        }
        $sb.AppendLine("    # be sure to let the user know if there are any errors")
        $sb.AppendLine("    Pop-CrescendoNativeError -EmitAsError")
        $sb.AppendLine("  } # end PROCESS") # always present
        return $sb.ToString()
    }
    [string]GetCrescendoAttribute()
    {
        return('[PowerShellCustomFunctionAttribute(RequiresElevation=${0})]' -f (($null -eq $this.Elevation.Command) ? $false : $true))
    }
    [string]GetCommandDeclaration([bool]$EmitAttribute) {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendFormat("function {0}`n", $this.FunctionName)
        $sb.AppendLine("{") # }
        if ( $EmitAttribute ) {
            $sb.AppendLine($this.GetCrescendoAttribute())
        }
        $sb.Append("[CmdletBinding(")
        $addlAttributes = @()
        if ( $this.SupportsShouldProcess ) {
            $addlAttributes += 'SupportsShouldProcess=$true'
        }
        if ( $this.ConfirmImpact ) {
            if ( @("high","medium","low","none") -notcontains $this.ConfirmImpact) {
                throw ("Confirm Impact '{0}' is invalid. It must be High, Medium, Low, or None." -f $this.ConfirmImpact)
            }
            $addlAttributes += 'ConfirmImpact=''{0}''' -f $this.ConfirmImpact
        }
        if ( $this.DefaultParameterSetName ) {
            $addlAttributes += 'DefaultParameterSetName=''{0}''' -f $this.DefaultParameterSetName
        }
        $sb.Append(($addlAttributes -join ','))
        $sb.AppendLine(")]")
        return $sb.ToString()
    }
    [string]GetParameters() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append("param(")
        if ($this.Parameters.Count -gt 0) {
            $sb.AppendLine()
            $params = $this.Parameters|ForEach-Object {$_.ToString()}
            $sb.AppendLine(($params -join ",`n"))
        }
        $sb.AppendLine("    )")
        return $sb.ToString()
    }

    [void]ExportConfigurationFile([string]$filePath) {
        $sOptions = [System.Text.Json.JsonSerializerOptions]::new()
        $sOptions.WriteIndented = $true
        $sOptions.MaxDepth = 10
        $sOptions.IgnoreNullValues = $true
        $obj = @{
            '$schema' = 'https://aka.ms/PowerShell/Crescendo/Schemas/2022-06#'
            Commands = @($this)
        }
        $text = [System.Text.Json.JsonSerializer]::Serialize($obj, $sOptions)
        Set-Content -Path $filePath -Value $text
    }

    [string]GetCrescendoConfiguration() {
        $sOptions = [System.Text.Json.JsonSerializerOptions]::new()
        $sOptions.WriteIndented = $true
        $sOptions.MaxDepth = 10
        $sOptions.IgnoreNullValues = $true
        $text = [System.Text.Json.JsonSerializer]::Serialize($this, $sOptions)
        return $text
    }

}
# =========================================================================

# function to test whether there is a parser error in the output handler
function Test-Handler {
    param (
        [Parameter(Mandatory=$true)][string]$script,
        [Parameter(Mandatory=$true)][ref]$parserErrors
    )
    $null = [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$null, $parserErrors)
    (0 -eq $parserErrors.Value.Count)
}

# functions to create the classes since you can't access the classes outside the module
function New-ParameterInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$Name,
        [Parameter(Position=1,Mandatory=$true)][AllowEmptyString()][string]$OriginalName
    )
    [ParameterInfo]::new($Name, $OriginalName)
}

function New-UsageInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$usage
        )
    [UsageInfo]::new($usage)
}

function New-ExampleInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$command,
        [Parameter(Position=1,Mandatory=$true)][string]$description,
        [Parameter(Position=2)][string]$originalCommand = ""
        )
    [ExampleInfo]::new($command, $originalCommand, $description)
}

function New-OutputHandler {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param ( )
    [OutputHandler]::new()

}

function New-CrescendoCommand {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$Verb,
        [Parameter(Position=1,Mandatory=$true)][string]$Noun,
        [Parameter(Position=2)][string]$OriginalName
    )
    $cmd = [Command]::new($Verb, $Noun)
    $cmd.OriginalName = $OriginalName
    $cmd
}

function Export-CrescendoCommand {
    [CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="MultipleFile")]
    param (
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [Command[]]$command,
        [Parameter(ParameterSetName="MultipleFile")][string]$targetDirectory = ".",
        [Parameter(ParameterSetName="SingleFile", Mandatory=$true)][string]$fileName = "",
        [Parameter(ParameterSetName="SingleFile")][switch]$Force
    )

    BEGIN
    {
        if ( $PSCmdlet.ParameterSetName -eq "SingleFile") {
            $commandConfigurations = @()
            $outputFile = Get-Item -Path $filename -ErrorAction Ignore

            if ( @($outputFile).Count -gt 1) {
                throw ("'$fileName' must resolve to a single file")
            }

            # output file does not exist
            if ( ! $outputFile ) {
                $outputFile = $fileName
            }
            else {
                # check to see if the path is a directory
                if ( $outputFile.PSIsContainer ) {
                    throw ("'$fileName' is a directory, it must resolve to a single file")
                }
                if ( $Force ) {
                    $outputFile.Delete()
                } 
                else {
                    throw ("File '$fileName' already exists. Use -Force to overwrite")
                }
            }
        }
    }

    PROCESS
    {
        foreach($crescendoCommand in $command) {
            if($PSCmdlet.ShouldProcess($crescendoCommand.FunctionName)) {
                if ($PSCmdlet.ParameterSetName -eq "MultipleFile") {
                    $fileName = "{0}-{1}.crescendo.json" -f $crescendoCommand.Verb, $crescendoCommand.Noun
                    $exportPath = Join-Path $targetDirectory $fileName
                    $crescendoCommand.ExportConfigurationFile($exportPath)
                }
                else {
                    $commandConfigurations += $crescendoCommand
                }
            }
        }
    }

    END
    {
        # there's nothing to do for this parameter set.
        if ($PSCmdlet.ParameterSetName -eq "MultipleFile") {
            return
        }

        # now save all the command configurations to a single file.
        $multiConfiguration = [System.Collections.Specialized.OrderedDictionary]::new()
        $multiConfiguration.Add('$schema', 'https://aka.ms/PowerShell/Crescendo/Schemas/2022-06')
        $multiConfiguration.Add('commands', $commandConfigurations)
        $sOptions = [System.Text.Json.JsonSerializerOptions]::new()
        $sOptions.WriteIndented = $true
        $sOptions.MaxDepth = 10
        $sOptions.IgnoreNullValues = $true
        $text = [System.Text.Json.JsonSerializer]::Serialize($multiConfiguration, $sOptions)
        if ($PSCmdlet.ShouldProcess($outputFile)) {
            Out-File -LiteralPath $outputFile -InputObject $text
        }
    }
}

function Import-CommandConfiguration {
[CmdletBinding()]
param (
    [Parameter(Position=0,Mandatory=$true)][string]$file
    )
    $options = [System.Text.Json.JsonSerializerOptions]::new()
    # this dance is to support multiple configurations in a single file
    # The deserializer doesn't seem to support creating [command[]]
    Get-Content $file |
        ConvertFrom-Json -depth 10|
        Foreach-Object {$_.Commands} |
        ForEach-Object { $_ | ConvertTo-Json -depth 10 |
            Foreach-Object {
                $configuration = [System.Text.Json.JsonSerializer]::Deserialize($_, [command], $options)
                $errs = $null
                if (!(Test-Configuration -configuration $configuration -errors ([ref]$errs))) {
                    $errs | Foreach-Object { Write-Error -ErrorRecord $_ }
                }

                # emit the configuration even if there was an error
                $configuration
            }
        }
}

function Test-Configuration {
    param ([Command]$Configuration, [ref]$errors)

    $configErrors = @()
    $configurationOK = $true

    # Validate the Platform types
    $allowedPlatforms = "Windows","Linux","MacOS"
    foreach($platform in $Configuration.Platform) {
        if ($allowedPlatforms -notcontains $platform) {
            $configurationOK = $false
            $e = [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("Platform '$platform' is not allowed. Use 'Windows', 'Linux', or 'MacOS'"),
                "ParserError",
                "InvalidArgument",
                "Import-CommandConfiguration:Platform")
            $configErrors += $e
        }
    }

    # Validate the output handlers in the configuration
    foreach ( $handler in $configuration.OutputHandlers ) {
        if ( $handler.HandlerType -eq "bypass") {
            continue
        }
        $parserErrors = $null
        if ( -not (Test-Handler -Script $handler.Handler -ParserErrors ([ref]$parserErrors))) {
            $configurationOK = $false
            $exceptionMessage = "OutputHandler Error in '{0}' for ParameterSet '{1}'" -f $configuration.FunctionName, $handler.ParameterSetName
            $e = [System.Management.Automation.ErrorRecord]::new(
                ([Exception]::new($exceptionMessage)),
                "Import-CommandConfiguration:OutputHandler",
                "ParserError",
                $parserErrors)
            $configErrors += $e
        }
    }
    if ($configErrors.Count -gt 0) {
        $errors.Value = $configErrors
    }

    return $configurationOK

}

function Export-Schema() {
    $sGen = [Newtonsoft.Json.Schema.JsonSchemaGenerator]::new()
    $sGen.Generate([command])
}

function Get-ModuleHeader {
    param ([string]$schemaVersion, [datetime]$generationTime)
    $ModuleVersion = $MyInvocation.MyCommand.Version
    "# Module created by Microsoft.PowerShell.Crescendo"
    "# Version: $ModuleVersion"
    "# Schema: $SchemaVersion"
    "# Generated at: ${generationTime}"
    'class PowerShellCustomFunctionAttribute : System.Attribute {'
    '    [bool]$RequiresElevation'
    '    [string]$Source'
    '    PowerShellCustomFunctionAttribute() { $this.RequiresElevation = $false; $this.Source = "Microsoft.PowerShell.Crescendo" }'
    '    PowerShellCustomFunctionAttribute([bool]$rElevation) {'
    '        $this.RequiresElevation = $rElevation'
    '        $this.Source = "Microsoft.PowerShell.Crescendo"'
    '    }'
    '}'
    ''
}

function Get-CrescendoNativeErrorHelper {
    '# Returns available errors'
    '# Assumes that we are being called from within a script cmdlet when EmitAsError is used.'
    'function Pop-CrescendoNativeError {'
    'param ([switch]$EmitAsError)'
    '    while ($__CrescendoNativeErrorQueue.Count -gt 0) {'
    '        if ($EmitAsError) {'
    '            $msg = $__CrescendoNativeErrorQueue.Dequeue()'
    '            $er = [System.Management.Automation.ErrorRecord]::new([system.invalidoperationexception]::new($msg), $PSCmdlet.Name, "InvalidOperation", $msg)'
    '            $PSCmdlet.WriteError($er)'
    '        }'
    '        else {'
    '            $__CrescendoNativeErrorQueue.Dequeue()'
    '        }'
    '    }'
    '}'

    '# this is purposefully a filter rather than a function for streaming errors'
    'filter Push-CrescendoNativeError {'
    '    if ($_ -is [System.Management.Automation.ErrorRecord]) {'
    '        $__CrescendoNativeErrorQueue.Enqueue($_)'
    '    }'
    '    else {'
    '        $_'
    '    }'
    '}'
    ''
}

function Export-CrescendoModule {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Position=1,Mandatory=$true,ValueFromPipelineByPropertyName=$true)][SupportsWildcards()][string[]]$ConfigurationFile,
        [Parameter(Position=0,Mandatory=$true)][string]$ModuleName,
        [Parameter(HelpMessage="Overwrite the psm1 and psd1 files.")][switch]$Force,
        [Parameter(HelpMessage="Do not overwrite the module manifest.")][switch]$NoClobberManifest,
        [Parameter(HelpMessage="Emit an object with the path to the .psm1 and the arguments to New-ModuleManifest.")][switch]$PassThru
        )
    BEGIN {
        $TIMEGENERATED = Get-Date

        [array]$crescendoCollection = @()
        if ($ModuleName -notmatch "\.psm1$") {
            $ModuleName += ".psm1"
        }
        if (-not $PSCmdlet.ShouldProcess("Creating Module '$ModuleName'"))
        {
            return
        }
        if ((Test-Path $ModuleName) -and -not $Force) {
            throw "$ModuleName already exists"
        }

        # static parts of the crescendo module
        # the schema will be taken from the first configuration file
        $SchemaVersion = (Get-Content (Resolve-Path $ConfigurationFile[0])[0] | ConvertFrom-Json).'$schema'
        if ( ! $SchemaVersion ) {
            $SchemaVersion = "unknown"
        }

        $moduleBase = [System.IO.Path]::GetDirectoryName($ModuleName)
        $TransformAndHandlerFunctions = [System.Collections.Generic.HashSet[string]]::new()
        $TransformAndHandlerScripts = [System.Collections.Generic.HashSet[string]]::new()
    }
    PROCESS {
        if ( $PSBoundParameters['WhatIf'] ) {
            return
        }
        $resolvedConfigurationPaths = (Resolve-Path $ConfigurationFile).Path
        foreach($file in $resolvedConfigurationPaths) {
            Write-Verbose "Adding $file to Crescendo collection"
            $crescendoCollection += Import-CommandConfiguration -file $file
        }
    }
    END {
        if ( $PSBoundParameters['WhatIf'] ) {
            return
        }
        [string[]]$cmdletNames = @()
        [string[]]$aliases = @()
        [string[]]$SetAlias = @()
        [bool]$IncludeWindowsElevationHelper = $false

        foreach ($configuration in $crescendoCollection) {
            # by calling ToString() here we can check for fatal errors
            # (if a function handler or transform is not available)
            # TODO: create a configuration validator
            $null = $configuration.ToString()
        }

        # Put the schema and native error helper in the module
        Get-ModuleHeader -schemaVersion $schemaVersion -generationTime $TIMEGENERATED > $ModuleName
        Get-CrescendoNativeErrorHelper >> $ModuleName

        # if a proxy calls for elevation with the builtin,
        # be sure to put it in the module.
        foreach($proxy in $crescendoCollection) {
            if ($proxy.Elevation.Command -eq "Invoke-WindowsNativeAppWithElevation") {
                $IncludeWindowsElevationHelper = $true
            }
            $cmdletNames += $proxy.FunctionName
            if ( $proxy.Aliases ) {
                # we need the aliases without value for the psd1
                $proxy.Aliases.ForEach({$aliases += $_})
                # the actual set-alias command will be emited before the export-modulemember
                $proxy.Aliases.ForEach({$SetAlias += "Set-Alias -Name '{0}' -Value '{1}'" -f $_,$proxy.FunctionName})
            }
            # This emits the proxy code which is put in the .psm1 file,
            # when set to true, we will also emit the Crescendo attribute
            $proxy.ToString($true) >> $ModuleName
        
            # put the functions and script in place
            # we will handle putting these in the module after
            foreach($outputHandler in $proxy.OutputHandlers) {
                if ($outputHandler.HandlerType -eq "ByPass") {
                    continue
                }
                elseif ($outputHandler.HandlerType -eq "Function") {
                    $null = $TransformAndHandlerFunctions.Add($outputHandler.Handler)
                }
                elseif ($outputHandler.HandlerType -eq "Script") {
                    $null = $TransformAndHandlerScripts.Add($outputHandler.Handler)
                }
            }
            foreach($parameter in $proxy.Parameters) {
                if ($parameter.ArgumentTransformType -eq "Function") {
                    $null = $TransformAndHandlerFunctions.Add($parameter.ArgumentTransform)
                }
                elseif ($parameter.ArgumentTransformType -eq "Script") {
                    $null = $TransformAndHandlerScripts.Add($parameter.ArgumentTransform)
                }
            }
        }
        $SetAlias >> $ModuleName

        # now copy the output handler and argument transform functions 
        foreach($functionName in $TransformAndHandlerFunctions) {
            $functionContent = Get-Content function:$functionName -ErrorAction Ignore
            if ( $null -eq $functionContent ) {
                throw "Cannot find OutputHandler/ArgumentTransform function '$functionName'."
            }
            # don't let any of the functions pollute the global space
            $functionContent.Ast.Extent.Text -replace "^function global:","function " >> $ModuleName
        }
        # now copy the output handler and argument transform scripts to the module base
        # this is a non-fatal error
        foreach($scriptName in $TransformAndHandlerScripts) {
            $scriptInfo = Get-Command -ErrorAction Ignore -CommandType ExternalScript $scriptName
            if ($scriptInfo) {
                Copy-Item -Path $scriptInfo.Source -Destination $moduleBase
            }
            else {
                $errArgs = @{
                    Category = "ObjectNotFound"
                    TargetObject = $scriptInfo.Source
                    Message = "Handler '$scriptName' not found."
                    RecommendedAction = "Copy the handler/transform to the module directory before packaging."
                }
                Write-Error @errArgs
            }
        }

        # include the windows helper if it has been included
        if ($IncludeWindowsElevationHelper) {
            "function Invoke-WindowsNativeAppWithElevation {" >> $ModuleName
            $InvokeWindowsNativeAppWithElevationFunction >> $ModuleName
            "}" >> $ModuleName
        }

        $ModuleManifestArguments = @{
            Path = $ModuleName -Replace "psm1$","psd1"
            RootModule = [io.path]::GetFileName(${ModuleName})
            Tags = "CrescendoBuilt"
            PowerShellVersion = "5.1.0"
            CmdletsToExport = @()
            AliasesToExport = @()
            VariablesToExport = @()
            FunctionsToExport = @()
            PrivateData = @{
                CrescendoGenerated = $TIMEGENERATED
                CrescendoVersion = (Get-Module Microsoft.PowerShell.Crescendo).Version
                }
        }
        if ( $cmdletNames ) {
            $ModuleManifestArguments['FunctionsToExport'] = $cmdletNames
        }
        if ( $aliases ) {
            $ModuleManifestArguments['AliasesToExport'] = $aliases
        }

        # only create the manifest if we are not in no-update-manifest mode
        if (! $NoClobberManifest) {
            New-ModuleManifest @ModuleManifestArguments
        }

        if ($PassThru) {
            [PSCustomObject]@{
                ModulePath = $ModuleName
                ManifestArguments = $ModuleManifestArguments
            }
        }
    }
}

# This is an elevation function for Windows which may be distributed with a crescendo module
$InvokeWindowsNativeAppWithElevationFunction = @'
    [CmdletBinding(DefaultParameterSetName="username")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$command,
        [Parameter(ParameterSetName="credential")][PSCredential]$Credential,
        [Parameter(ParameterSetName="username")][string]$User = "Administrator",
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$cArguments
    )

    $app = "cmd.exe"
    $nargs = @("/c","cd","/d","%CD%","&&")
    $nargs += $command
    if ( $cArguments.count ) {
        $nargs += $cArguments
    }
    $__OUTPUT = Join-Path ([io.Path]::GetTempPath()) "CrescendoOutput.txt"
    $__ERROR  = Join-Path ([io.Path]::GetTempPath()) "CrescendoError.txt"
    if ( $Credential ) {
        $cred = $Credential
    }
    else {
        $cred = Get-Credential $User
    }

    $spArgs = @{
        Credential = $cred
        File = $app
        ArgumentList = $nargs
        RedirectStandardOutput = $__OUTPUT
        RedirectStandardError = $__ERROR
        WindowStyle = "Minimized"
        PassThru = $True
        ErrorAction = "Stop"
    }
    $timeout = 10000
    $sleepTime = 500
    $totalSleep = 0
    try {
        $p = start-process @spArgs
        while(!$p.HasExited) {
            Start-Sleep -mill $sleepTime
            $totalSleep += $sleepTime
            if ( $totalSleep -gt $timeout )
            {
                throw "'$(cArguments -join " ")' has timed out"
            }
        }
    }
    catch {
        # should we report error output?
        # It's most likely that there will be none if the process can't be started
        # or other issue with start-process. We catch actual error output from the
        # elevated command below.
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
        $msg = "Error running '{0} {1}'" -f $command,($cArguments -join " ")
        throw "$msg`n$_"
    }

    try {
        if ( test-path $__OUTPUT ) {
            $output = Get-Content $__OUTPUT
        }
        if ( test-path $__ERROR ) {
            $errorText = (Get-Content $__ERROR) -join "`n"
        }
    }
    finally {
        if ( $errorText ) {
            $exception = [System.Exception]::new($errorText)
            $errorRecord = [system.management.automation.errorrecord]::new(
                $exception,
                "CrescendoElevationFailure",
                "InvalidOperation",
                ("{0} {1}" -f $command,($cArguments -join " "))
                )
            # errors emitted during the application are not fatal
            Write-Error $errorRecord
        }
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
    }
    # return the output to the caller
    $output
'@

class CrescendoCommandInfo {
    [string]$Module
    [string]$Source
    [string]$Name
    [bool]$IsCrescendoCommand
    [bool]$RequiresElevation
    CrescendoCommandInfo([string]$module, [string]$name, [Attribute]$attribute) {
        $this.Module = $module
        $this.Name = $name
        $this.IsCrescendoCommand = $null -eq $attribute ? $false : ($attribute.Source -eq "Microsoft.PowerShell.Crescendo")
        $this.RequiresElevation = $null -eq $attribute ? $false : $attribute.RequiresElevation
        $this.Source = $null -eq $attribute ? "" : $attribute.Source
    }
}

function Test-IsCrescendoCommand {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)]
        [object[]]$Command
    )
    PROCESS {
        # loop through the commands and determine whether it is a Crescendo Function
        foreach( $cmd in $Command) {
            $fInfo = $null
            if ($cmd -is [System.Management.Automation.FunctionInfo]) {
                $fInfo = $cmd
            }
            elseif ($cmd -is [string]) {
                $fInfo = Get-Command -Name $cmd -CommandType Function -ErrorAction Ignore
            }
            if(-not $fInfo) {
                Write-Error -Message "'$cmd' is not a function" -TargetObject "$cmd" -RecommendedAction "Be sure that the command is a function"
                continue
            }
            #  check for the PowerShellFunctionAttribute and report on findings
            $crescendoAttribute = $fInfo.ScriptBlock.Attributes|Where-Object {$_.TypeId.Name -eq "PowerShellCustomFunctionAttribute"} | Select-Object -Last 1
            [CrescendoCommandInfo]::new($fInfo.Source, $fInfo.Name, $crescendoAttribute)
        }
    }
}

# SIG # Begin signature block
# MIIn0AYJKoZIhvcNAQcCoIInwTCCJ70CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCvaKXcnjuCTEHd
# DHK/0ETwuNNnJ1+Fo8dhFaNBC+27DKCCDYUwggYDMIID66ADAgECAhMzAAADTU6R
# phoosHiPAAAAAANNMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI4WhcNMjQwMzE0MTg0MzI4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDUKPcKGVa6cboGQU03ONbUKyl4WpH6Q2Xo9cP3RhXTOa6C6THltd2RfnjlUQG+
# Mwoy93iGmGKEMF/jyO2XdiwMP427j90C/PMY/d5vY31sx+udtbif7GCJ7jJ1vLzd
# j28zV4r0FGG6yEv+tUNelTIsFmmSb0FUiJtU4r5sfCThvg8dI/F9Hh6xMZoVti+k
# bVla+hlG8bf4s00VTw4uAZhjGTFCYFRytKJ3/mteg2qnwvHDOgV7QSdV5dWdd0+x
# zcuG0qgd3oCCAjH8ZmjmowkHUe4dUmbcZfXsgWlOfc6DG7JS+DeJak1DvabamYqH
# g1AUeZ0+skpkwrKwXTFwBRltAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUId2Img2Sp05U6XI04jli2KohL+8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMDUxNzAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# ACMET8WuzLrDwexuTUZe9v2xrW8WGUPRQVmyJ1b/BzKYBZ5aU4Qvh5LzZe9jOExD
# YUlKb/Y73lqIIfUcEO/6W3b+7t1P9m9M1xPrZv5cfnSCguooPDq4rQe/iCdNDwHT
# 6XYW6yetxTJMOo4tUDbSS0YiZr7Mab2wkjgNFa0jRFheS9daTS1oJ/z5bNlGinxq
# 2v8azSP/GcH/t8eTrHQfcax3WbPELoGHIbryrSUaOCphsnCNUqUN5FbEMlat5MuY
# 94rGMJnq1IEd6S8ngK6C8E9SWpGEO3NDa0NlAViorpGfI0NYIbdynyOB846aWAjN
# fgThIcdzdWFvAl/6ktWXLETn8u/lYQyWGmul3yz+w06puIPD9p4KPiWBkCesKDHv
# XLrT3BbLZ8dKqSOV8DtzLFAfc9qAsNiG8EoathluJBsbyFbpebadKlErFidAX8KE
# usk8htHqiSkNxydamL/tKfx3V/vDAoQE59ysv4r3pE+zdyfMairvkFNNw7cPn1kH
# Gcww9dFSY2QwAxhMzmoM0G+M+YvBnBu5wjfxNrMRilRbxM6Cj9hKFh0YTwba6M7z
# ntHHpX3d+nabjFm/TnMRROOgIXJzYbzKKaO2g1kWeyG2QtvIR147zlrbQD4X10Ab
# rRg9CpwW7xYxywezj+iNAc+QmFzR94dzJkEPUSCJPsTFMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGaEwghmdAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAANNTpGmGiiweI8AAAAA
# A00wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIM3p
# MrZvGO0LOUSAbxhDbFbhpJVJMYjUsoblMOdxYfiQMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAuGbnk7fb0qL5PNOF3+9OmSOjMZxJTQqgMG/Q
# VlyJO2oZcJv2VMcwCLB178glDe9Gb/Cmsm52wWUnwdmHLHkz95/7cTd1oNe+ltv8
# O+4y/NiMjJ7FTas7PdzZl1KX4NJBKofsT0EvbAhgoUqT96Yhc71aBHqbbJs1JA0f
# uYr+I3Ep/kqv5oSzcXhdJtfDXrfwRJaCa0PEFG9es7fyoW4l9AcHMxFmb5x2LI/2
# nLUGfjk0LvoEBVljBSsj+DXqFb/WNPvJJAhLEmXwS+LZDAxLIAviFme9C+Sp1/jy
# rBTGLozFJ8q3LdJQxn8qhL8RK1p4jagD+KGJyvs8IStB59a/vaGCFyswghcnBgor
# BgEEAYI3AwMBMYIXFzCCFxMGCSqGSIb3DQEHAqCCFwQwghcAAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFYBgsqhkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCDVsTiewx6uJqaeudaDhLiHZwjQikCUg9ZF
# cSAy/0VkOgIGZN5e5FXmGBIyMDIzMDkwNjE3Mzg1MC44NFowBIACAfSggdikgdUw
# gdIxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsT
# JE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMd
# VGhhbGVzIFRTUyBFU046OEQ0MS00QkY3LUIzQjcxJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFNlcnZpY2WgghF7MIIHJzCCBQ+gAwIBAgITMwAAAbP+Jc4p
# GxuKHAABAAABszANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMDAeFw0yMjA5MjAyMDIyMDNaFw0yMzEyMTQyMDIyMDNaMIHSMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3Nv
# ZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjhENDEtNEJGNy1CM0I3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHwP
# uuYYgK4ssGCCsr2N7eElKlz0JPButr/gpvZ67kNlHqgKAW0JuKAy4xxjfVCUev/e
# S5aEcnTmfj63fvs8eid0MNvP91T6r819dIqvWnBTY4vKVjSzDnfVVnWxYB3IPYRA
# ITNN0sPgolsLrCYAKieIkECq+EPJfEnQ26+WTvit1US+uJuwNnHMKVYRri/rYQ2P
# 8fKIJRfcxkadj8CEPJrN+lyENag/pwmA0JJeYdX1ewmBcniX4BgCBqoC83w34Sk3
# 7RMSsKAU5/BlXbVyDu+B6c5XjyCYb8Qx/Qu9EB6KvE9S76M0HclIVtbVZTxnnGws
# Sg2V7fmJx0RP4bfAM2ZxJeVBizi33ghZHnjX4+xROSrSSZ0/j/U7gYPnhmwnl5Sc
# tprBc7HFPV+BtZv1VGDVnhqylam4vmAXAdrxQ0xHGwp9+ivqqtdVVDU50k5LUmV6
# +GlmWyxIJUOh0xzfQjd9Z7OfLq006h+l9o+u3AnS6RdwsPXJP7z27i5AH+upQron
# semQ27R9HkznEa05yH2fKdw71qWivEN+IR1vrN6q0J9xujjq77+t+yyVwZK4kXOX
# AQ2dT69D4knqMlFSsH6avnXNZQyJZMsNWaEt3rr/8Nr9gGMDQGLSFxi479Zy19aT
# /fHzsAtu2ocBuTqLVwnxrZyiJ66P70EBJKO5eQECAwEAAaOCAUkwggFFMB0GA1Ud
# DgQWBBTQGl3CUWdSDBiLOEgh/14F3J/DjTAfBgNVHSMEGDAWgBSfpxVdAF5iXYP0
# 5dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB
# /wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOC
# AgEAWoa7N86wCbjAAl8RGYmBZbS00ss+TpViPnf6EGZQgKyoaCP2hc01q2AKr6Me
# 3TcSJPNWHG14pY4uhMzHf1wJxQmAM5Agf4aO7KNhVV04Jr0XHqUjr3T84FkWXPYM
# O4ulQG6j/+/d7gqezjXaY7cDqYNCSd3F4lKx0FJuQqpxwHtML+a4U6HODf2Z+KMY
# gJzWRnOIkT/od0oIXyn36+zXIZRHm7OQij7ryr+fmQ23feF1pDbfhUSHTA9IT50K
# CkpGp/GBiwFP/m1drd7xNfImVWgb2PBcGsqdJBvj6TX2MdUHfBVR+We4A0lEj1rN
# bCpgUoNtlaR9Dy2k2gV8ooVEdtaiZyh0/VtWfuQpZQJMDxgbZGVMG2+uzcKpjeYA
# NMlSKDhyQ38wboAivxD4AKYoESbg4Wk5xkxfRzFqyil2DEz1pJ0G6xol9nci2Xe8
# LkLdET3u5RGxUHam8L4KeMW238+RjvWX1RMfNQI774ziFIZLOR+77IGFcwZ4Fmot
# eX1x9+Bg9ydEWNBP3sZv9uDiywsgW40k00Am5v4i/GGiZGu1a4HhI33fmgx+8blw
# R5nt7JikFngNuS83jhm8RHQQdFqQvbFvWuuyPtzwj5q4SpjO1SkOe6roHGkEhQCU
# XdQMnRIwbnGpb/2EsxadokK8h6sRZMWbriO2ECLQEMzCcLAwggdxMIIFWaADAgEC
# AhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQg
# Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVa
# Fw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7V
# gtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeF
# RiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3X
# D9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoP
# z130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+
# tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5Jas
# AUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/b
# fV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuv
# XsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg
# 8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzF
# a/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqP
# nhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEw
# IwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSf
# pxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBB
# MD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0Rv
# Y3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmg
# R4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWlj
# Um9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEF
# BQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29D
# ZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEs
# H2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHk
# wo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinL
# btg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCg
# vxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsId
# w2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2
# zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23K
# jgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beu
# yOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/
# tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjm
# jJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBj
# U02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIC1zCCAkACAQEwggEAoYHYpIHVMIHS
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRN
# aWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRo
# YWxlcyBUU1MgRVNOOjhENDEtNEJGNy1CM0I3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBxi0Tolt0eEqXCQl4q
# gJXUkiQOYaCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBBQUAAgUA6KKPyDAiGA8yMDIzMDkwNjEzNDIzMloYDzIwMjMwOTA3
# MTM0MjMyWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDooo/IAgEAMAoCAQACAgCl
# AgH/MAcCAQACAhHSMAoCBQDoo+FIAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQAD
# gYEAxme3izXsJspXwR53kaqIZ+fsKz1+h0WDdn+hMYEDQQufar8Ta8ABK9kFG3nJ
# b8+67bbCLB1CLNU1YyFcM9wr8/74wemzk61nE9eUqCDJpZivZwNvC1uaTHGnagSl
# 4GFj5iif+O+1fjBdUl4wasGxGfeujNidtvtxxavgrOJD9nkxggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAbP+Jc4pGxuKHAAB
# AAABszANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCBriBNIHH9ulo8PuPr62uLDoUUyBFvwrihpGOW2
# 3oZHADCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIIahM9UqENIHtkbTMlBl
# QzaOT+WXXMkaHoo6GfvqT79CMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAGz/iXOKRsbihwAAQAAAbMwIgQg99+9049t0lxSzA2AapO1
# 0NHRPvOMW2OJz0F3tW1yXYkwDQYJKoZIhvcNAQELBQAEggIAA9bGRiME/uAKES4R
# 0CMXrHCGAQWZUhZWLGLRvjJOn7l3YCq1N5Q24iTHfjGjZRnd3hIEMdlgO/7qT90w
# 81tP8FfnG4qfmcq/zqem0fWntI4+q+37yy1pmny0/Nll+uzrgWnTq2NVo24vR/Aj
# xqhZttRSrYw6YOWzoNfMxJpYOlt47bsvMzGL+Gi9qEaY2Qu/5zsljZyk2RvCGAi6
# OQURmrq6IFiUF8g1MbiqI0iTsL6h8dLgx6UjeS1VsFv+OMygLskPETT+ec5OlveF
# e37I3+7wBviLa4jkW3s4vf2lQEfOQFkARHas20+g03dRC61FunfcLFRdASuk/LPZ
# rb0V+NXRc6+VaSrSl8qKoHj3UPKLr+pwmHVn+mJyf16Fi0pg2WNpW4pSuZ4SrKD5
# RmRGTdllPaxrYSlUTHOV5/xbTVlsBnYQ3WmNsW6GyGwEqYYzmHiPaTjVs2CmLAYG
# onjZejrVdr+ZO/IaWHvW4rTR5o2w8NeEKhWmXKhZJ+AdacWn+SVoXb4l2YntRJ0d
# 1b79Aw3gBC3+tDW3gMMFeBWkoSsR4ry2IxpwxmliVf9hcmUklv6p4MA+W4mxZS6l
# MmG+ZjCD1ToG5VRQEi1sodyVbjhZ+FX6OnHhwNOr8j9to7aVcT0atdRMUkUU/l5M
# CF1J/nZYznEN+Vg2cCiWlaX1Hhw=
# SIG # End signature block
