#
# Copyright (c) Microsoft Corporation 2014.  All rights reserved.
#
Set-StrictMode -version 2.0

# Constant: Path to VSDebugD
$Script:VSDebugDPath = $PSScriptRoot

# Constant: for System root - usually "C:\"
$Script:SystemRoot = $env:SystemDrive + [System.IO.Path]::DirectorySeparatorChar

# Constant: "managed" 
$Script:ManagedType = "managed"

# Constant: "native"
$Script:NativeType = "native"

# Constant: "silverlight"
$Script:Silverlight = "silverlight"

# Constant: "modern"
$Script:Modern = "modern"

#  Constant: "action"
$Script:Action = "-action"

# Constant: "check"
$Script:CheckAction = "check"

# Constant: "detach"
$Script:Detach = "detach"

# Constant: regular expression constanct to extract a PID from a line of tlist output
$Script:pidExtractionRegEx = "^\s*(?<thisPid>[0-9]+)\s+(?<name>[^\s].*\.exe)(\s+Svcs\:\s+(?<svcs>[^\s].*$))?"

# Constant: this program launches silverlight apps.
$Script:Launcher = "c:\test\dbg\applauncher.exe"

# Constant: this program launches silverlight apps.
$Script:BlueLauncher = "c:\test\dbg\applauncher.orig.exe"

# Constant: this program tells if an EXE is managed.
$Script:IsManaged = "c:\test\dbg\ismanaged.exe"

# Constant: tool which enumerates AppX apps and returns EXE locations
$Script:AppXEnumerator = "c:\test\dbg\FindPackageInfo.exe"

# Constant: this program launches native apps.
$Script:UmjitCmd = "c:\Data\Test\bin\umjit.exe"

# Constant: this program kills off running processes
$Script:Kill = "c:\Windows\System32\kill.exe"

# Constant: this DLL is needed for managed debugging but may not be on the device.
$Script:MscoreeeHelper = "c:\Data\Test\bin\mscoreehelper.dll"

# Constant: we use this template to build the branch prefix so that we can iterate through all the branch builds.
$Script:PodBranchTemplate = "\\build\release\Threshold\{0}"
$Script:OldPodBranchTemplate = "\\build\release\Blue\{0}"

# Constant: we use this template to build the full path to mscoreeehelper.dll
$Script:DllPathTemplate = "{0}\{1}\MC.{2}chk\Binaries\bin\test\common\{2}\chk\mscoreehelper.dll"

## Constant: The VS vNext version number (Dev15).
#$Script:VsVNextVersion = "15.0"

# Constant: The VS 2015 version number (Dev14).
$Script:Vs2015Version = "14.0"

# Constant: The VS default port for remote debugging.
$Script:VsDefaultPort = "4016"

# Constant: Path to reg.exe.  It's the same path on the device and the desktop.
$Script:RegExePath = [System.IO.Path]::Combine($env:windir, "system32\reg.exe")

# Constant: Arguments to Reg.exe (desktop) to find if IpOverUsb is configured for port 4018 redirection.  
# I'm using reg.exe because Powershell doesn't appear to provide a way to read from the 64 registry,
# so there is no way to see the IpOverUsb values without reg.exe and the -reg:64 parameter.
$Script:IpOverUsbRegDestination = "query HKLM\SOFTWARE\Microsoft\IpOverUsb\Msvsmon -reg:64 -v DestinationPort"
$Script:IpOverUsbRegLocal       = "query HKLM\SOFTWARE\Microsoft\IpOverUsb\Msvsmon -reg:64 -v LocalPort"

# Consant: wpmain branch name
$Script:WpmainBranch = "WinMain"

# Consant: x86 target device architecture.
$Script:x86Arch = "x86"

# Consant: ARM  target device architecture.
$Script:ArmArch = "ARM"

# Record the target architecture here. Should be x86 or arm
$Script:TargetArch = "unk"

# Build information extracted primarily from \windows\system32\buildinfo.xml
$Script:BuildInfo = $null

# Windows build 
$Script:WindowsVersion = $null

# The starting home directory on the device.
$Script:HomeDir = $null

# This is the name of the helper app that automates Visual Studio.
$Script:Attacher = "AttachDebuggerToWPProcess.exe"

# When we install debugger files to the device, record that event here.
$Script:InstallCheck = $null

# Path to Visual Studio
$Script:VsPath = $null

# Visual Studio version number - set to Vs2015Version or VsVNextVersion (just below)
$Script:VsVersion = $null

# Visual Studio port number - 4016
$Script:VsPort = $null

# Msvsmon port number - 4016
$Script:MsvsmonPort = $null

# When VSDebugD uses or starts and instance of VS, we record the Process ID here.
$Script:VsPid = $null

# Undo actions to perform in the "finally" clause
[System.Collections.ArrayList]$Script:CleanUp = @()

# Constant: The installed packages are enumerated at this registry location.
$Script:pkgRoot = "HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package"

# We generate a list of the installed packages to associate the AUMID and ExePath
$Script:pkgList = New-Object 'System.Collections.Generic.Dictionary[String, object]'

# These packages haven't been processed to determine the AUMID and ExePath
$Script:rawPkgs = New-Object 'System.Collections.Generic.List[String]'

<#
.SYNOPSIS
Automates many of the details of the Windows Phone debugging experience.

.DESCRIPTION
VSDebugD is a powershell helper script that helps you debug Windows Phone processes using Visual Studio.
It performs the following tasks:

1) If needed, copies the required files for Visual Studio debugging to the connected device.
2) If msvsmon.exe isn't running on the device, VSDebugD starts msvsmon.exe
3) If the user specifies a process name or service name, VSDebugD determines the associated process id.
4) Starts Visual Studio
5) Automates Visual Studio to connect to the connected device and attach to the designated process.

.PARAMETER newVS
Tells VSDebugD to start a new version of VS.

.PARAMETER pn
Specifies a Windows Phone process name to debug.

.PARAMETER psn
Specifies a Windows Phone service name to debug.

.PARAMETER processId
Specifies a Windows Phone service process ID to debug.

.PARAMETER fileName
Specifies a filename or app ID to start and then attach to.

.PARAMETER appID
Specifies an application ID of a Silverlight application.

.PARAMETER AumID
Specifies an the Application User Model ID of a Silverlight 8.1 or Modren App.  Take
note that DebugVS only supports AumID that map to managed code and, even more specificly,
programs that load mscoree

.PARAMETER AppName
Specifies the name of a Silverlight, Silverlight 8.1 or Modern App.

.PARAMETER arguments
Specifies arguments to pass to the process we are starting with fileName parameter.

.PARAMETER symbols
Specifes the symbol path to employ for Visual Studio.

.PARAMETER type
Specifies native or managed debugging, defaulting to native except in the case where
the user specifies an -AppId when we default to silverlight . The debugging engine
doesn't support Mixed-mode debugging for our transport.

#.PARAMETER -VS2015
#Specifies the use of Visual Studio 2015 even if Visual Studio vNext is on the machine.

.PARAMETER -Update
Updates Launcher (AppLauncher.exe) from the POD, if possible.

.PARAMETER -VsPid
Specifies an existing instance of Visual Studio to use for attach

.EXAMPLE
VSDebug-Device -filename ping.exe -type
Starts ping.exe and attaches VS for native debugging.

.EXAMPLE
VSDebug-Device -filename ping.exe -type -vs2015
As above, Starts ping.exe and attaches VS for native debugging, but use VS 2015
#>
function VSDebug-Device(
    [Switch] $NewVS,
    [String] $Pn,
    [String] $Psn,
    [String] $ProcessId,
    [String] $FileName,
    [String] $AppId,
    [String] $AumId,
    [String] $AppName,
    [String] $Arguments,
    [String] $Symbols,
    [String] $Type,
    [Switch] $Update,
    #[Switch] $VS2015
    [String] $VsPid
    )
{
    $VS2015 = $true;
    
    try
    {
        $Script:HomeDir = CD-Device
        AllowLegacyUseOfFileName ([ref]$FileName) ([ref]$AppId) ([ref]$Type)
        $Type = ApplyTypeDefault -Type $Type -AppId $AppId -AumId $AumId -AppName $AppName        
        ValidateConnection
        DetermineArchitecture
        DetermineSystemDrive
        DetermineBuildInformation
        ValidateProcessDesignation -FileName $FileName -ProcessID $ProcessID -Pn $Pn -Psn $Psn -AppId $AppId -AumId $AumId -AppName $AppName -Type $Type
        SelectVisualStudioVersion $VS2015

        Write-Host "VsPath      = $($Script:VsPath)"
        Write-Host "VsVersion   = $($Script:VsVersion)"
        Write-Host "VsPort      = $($Script:VsPort)"
        Write-Host "MsvsmonPort = $($Script:MsvsmonPort)"
 
        if ($VsPid -ne "")
        {
            $Script:VsPid = $VsPid -As [int]
        }
 
        if ($NewVS -or $Script:VsPid -eq 0)
        {
            StartNewInstanceOfVisualStudio
        }
        else
        {
            DetermineProcessIdOfVisualStudio
        }
        
        # To proceed further, we need an instance of VS, if the user didn't pick

        # one, we are done.
        if ($Script:VsPid -ne 0)
        {
            if ($Type -ieq $Script:ManagedType)
            {
                CopyMscoreeHelperToDevice
            }
            
            CopyDebuggerFilesToDevice

            if($Update)
            {
                UpdateLauncherFromPOD
            }

	        DetermineAppFromName ([ref]$AppId) ([ref]$AumId) $AppName
	        
            Start-Msvsmon
            
            if ($Pn)
            {
                $ProcessId = DetermineProcessIdFromName $Pn
            }
            elseif ($Psn)
            {
                $ProcessId = DetermineProcessIdFromService $Psn
            }
            elseif ($FileName)
            {
                $actualType = DetermineExeType $FileName

                if ($actualType -ne $Type)
                {
                    Write-Warning "Overiding EXE type to the actual type of the EXE - $actualType"
                    $Type = $actualType
                }
                
                if ($Type -ieq $Script:ManagedType)
                {
                    $ProcessId = StartManagedProcess $FileName $Arguments
                }
                elseif ($Type -ieq $Script:NativeType)
                {
                    $ProcessId = StartNativeProcess $FileName $Arguments
                } 
            }
            elseif ($AppId)
            {
                $ProcessId = StartSilverLightProcess $AppId
            }
            elseif ($AumId)
            {
                # For -AumID, we allow -native as a type but warn that it is not
                # completely supported.  This means that you can start and attach
                # but the executable won't break.
                $ProcessId = StartModernProcess $AumId ([ref]$Type)
            }
            elseif (!$ProcessID)
            {
                throw "Can't determine what to do from your parameters."
            }
            
            if ($ProcessID -le 0)
            {
                throw "Unable to determine the process ID"
            }
            else
            {
                ConnectVisualStudioToWPProcess $Type $ProcessId $Symbols
                
                if ($Type -ieq $Script:NativeType -and $Filename)
                {
                    RemoveProcessFromHeldList $ProcessId 
                }
            }
        }               
    }         
    catch
    {
        Write-Error $_.Exception.Message
    }
    finally
    {
        $Script:InstallCheck = $Global:DeviceAddress

        CleanRegistry
        
        if ($Script:HomeDir)
        {
            CD-Device $Script:HomeDir
        }
    }
}

<#
.SYNOPSIS
Update the launcher, if possible.  If not, warn the user.

.DESCRIPTION
Determines the exact build and time stamp of this image and tries to copy that
from the POD.  If that fails, we try just match on the build.

.EXAMPLE
UpdateLauncherFromPOD
#>
function UpdateLauncherFromPOD
{
    Write-Warning "Ready to find the right version of the Launcher and put it on the device."
    Write-Warning "Older versions of the Launcher may match your Device but lack some functionality."
    $yesNo = Read-Host "Do you want to update the Launcher from the POD?[yes/no]"
    if ($yesNo.ToLower().StartsWith("n"))
    {
        return
    }

    $result = CopyExactMatchForExeFromPOD $Script:Launcher
        
    if ($result -eq $null)
    {
        $result = CopySameBuildForExeFromPOD $Script:Launcher
    }
        
    if ($result -eq $null)
    {
        Write-Warning "Not able to locate the exact version of AppLauncher.exe"
        Write-Warning "-aumid or -appid debugging may not work"
    }
}

<#
.SYNOPSIS
If user specified -FileName with an app://, allow it but set up parameters correctly

.DESCRIPTION
If $FileName is "app://...", set $AppID to that and $FileName to $null

.PARAMTER FileName
A reference to the -FileName parameter

.PARAMTER AppID
A reference to the -AppID paramter.

.EXAMPLE
AllowLegacyUseOfFileName ([ref]$FileName) ([ref]$AppId)
#>
function AllowLegacyUseOfFileName (
    [ref][string]$FileName,
    [ref][string]$AppId,
    [ref][string]$Type)
{
    if($FileName)
    {
        if(IsValidAppID($FileName.Value))
        {
            Write-Warning "-FileName app://... is deprecated. Now setting -AppID to $($FileName.Value) and $Type to Managed"
            $AppId.Value = $FileName.Value
            $FileName.Value = $null
        }
        elseif($Type -and $Type.Value -ieq $Script:Silverlight)
        {
            throw "To start a Silverlight App, you must provide an -AppId parameter."
        }
    }   
}

<#
.SYNOPSIS
Invokes a helper function to detach the VS debugger from the target.

.DESCRIPTION
Calls PerformVisualStudioAction to perform the Detach operation.

.EXAMPLE
Detach-VisualStudioDebugger
Will call PerformVisualStudioAction to detach the target process from the VS Debugger.
#>
function Detach-VisualStudioDebugger
{
    # There is nothing to do if VSDebugD didn't get VS going.
    if ($Script:VsPid -ne 0)
    {
        $results = PerformVisualStudioAction $Script:Detach
        
        if ($results.Count)
        {
            [String]$lastLine = $results[$results.Count - 1]
            if ($lastLine.StartsWith("Error:"))
            {
                throw $lastLine
            }
            else
            {
                Write-Host $lastLine
            }
        }
        else
        {
            throw "No output at all from Visual Studio status check"
        }
    }
}

<#
.SYNOPSIS
 PerformRevertableRegistrationAction performs a registration action and records the "undo"

.DESCRIPTION
Performs the action.  If the action is performed successfully, add the "undo" action to the $Script:CleanUp
collection.  All the "undo" actions are performed at the end of the script.

.PARAMETER action
An two-element array containing a registration action and the "undo" action.

.EXAMPLE 
PerformRevertableRegistrationAction @("add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 1 /f",
                                    "add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 0 /f")

Performs the action in element 0 and saves the undo action in element 1 to $Script:CleanUp
#>
function PerformRevertableRegistrationAction(
    [String[]] $Action)
{
    try
    {
        $result = Exec-Device -FileName $Script:RegExePath -Arguments $Action[0] -HideOutput
        $result = $Script:CleanUp.Add($Action[1])
    }
    
    catch
    {
        throw "Unable to perform required registration updated: $Action[0]"
    }
}

<#
.SYNOPSIS
Actually selects the version of VS

.DESCRIPTION
The main point of this function is to encapsulate two details of setting the VS
version if we are changing from one version to another:

1)  we need to clear
$Script:InstallCheck, so that we'll copy a fresh and compatible set
of device-side binaries to the device.

2) We need to clear $Script:VsPid so that we'll start an instance of
VS that is the correct version.

.PARAMETER Path
The path to the selected version of Visual Studio.

.PARAMETER Version
The selected version number.

.EXAMPLE
SelectVSVersion $Path $Version
Selects caller's version of VS for debugging.
#>
function SelectVSVersion(
    [String]$Path,
    [String]$Version)
{   
    if ($Script:VsVersion -and $Script:VsVersion -ne $Version)
    {
        $Script:InstallCheck = $null
        $Script:VsPid = $null
    }
    
    $Script:VsPath = $Path
    $Script:VsVersion = $Version

    # We need to pick a port.  We default to 4016, but for Arm we will read the IpOverUsb reg key to override port #'s
        
    $Script:VsPort = $Script:VsDefaultPort
    $Script:Msvsmon = $Script:VsDefaultPort

    if ($Script:TargetArch -ieq $Script:ArmArch -and $Global:DeviceAddress -ieq "127.0.0.1")
    {
        # read remote msvsmon IPOverUSB port from registry 
        $command = $Script:RegExePath + " " + $Script:IpOverUsbRegDestination
        try {
            $result = Invoke-Expression $command | Select-String -Pattern "REG_DWORD\s*(0x[a-f0-9]+)" | % { [Convert]::ToInt32($_.Matches[0].Groups[1].Value, 16)  }
            if ($result)
            {
                $Script:MsvsmonPort = $result
            }
        }
        catch { 
            Write-Host "Exception: $_.Exception.Message"
            Write-Warning Unable to read IPOverUSB reg key using $Script:IpOverUsbRegDestination 
        }

        # read local msvsmon IPOverUSB port from registry 
        $command = $Script:RegExePath + " " + $Script:IpOverUsbRegLocal
        try {
            $result = Invoke-Expression $command | Select-String -Pattern "REG_DWORD\s*(0x[a-f0-9]+)" | % { [Convert]::ToInt32($_.Matches[0].Groups[1].Value, 16)  }
            if ($result)
            {
                $Script:VsPort = $result
            }
        }
        catch { 
            Write-Host "Exception: $_.Exception.Message"
            Write-Warning Unable to read IPOverUSB reg key using $Script:IpOverUsbRegLocal 
        }
    }

}

<#
.SYNOPSIS
Selects Visual Studio vNext for debugging, if it's on the system.

.DESCRIPTION
If we find devenv in the appropriate directory, we remember the path and version,
then return $true.  If we don't find devenv, we return $false.

.EXAMPLE
TryVisualStudioVNext
If VS vNext is present, selects it for debugging and returns $true.
#>
function TryVisualStudioVNext
{
    $VsPath = [System.IO.Path]::Combine($Script:SystemRoot, "Program Files (x86)\Microsoft Visual Studio " + $Script:VsVNextVersion + "\Common7\IDE\devenv.exe")
    if (Test-Path $VsPath)
    {
        SelectVSVersion $VsPath $Script:VsVNextVersion
        return $true
    }
    return $false
}

<#
.SYNOPSIS
Selects Visual Studio 2015 for debugging, if it's on the system.

.DESCRIPTION
If we find devenv in the appropriate directory, we remember the path and version,
then return $true.  If we don't find devenv, we return $false.

.EXAMPLE
TryVisualStudio2015
If VS2015 is present, selects Visual Studio 2015 for debugging and returns $true.
#>
function TryVisualStudio2015
{
    $VsPath = [System.IO.Path]::Combine("C:\Program Files (x86)\Microsoft Visual Studio " + $Script:Vs2015Version + "\Common7\IDE\devenv.exe")
    if (Test-Path $VsPath)
    {
        SelectVSVersion $VsPath $Script:Vs2015Version
        return $true
    }
    return $false
}

<#
.SYNOPSIS
Selects a version of Visual Studio for debugging.

.DESCRIPTION
Selects either VS vNext or VS 2015 if installed by looking for devenv.exe in
the appropriate directories. If one is found we remember the path to it and 
the version.  However, if the user specifies -vs2015, we only look for VS
2015 and throw an exception if it's not on the system.

.PARAMETER UseVS2015
This boolean means to use VS 2015.

.EXAMPLE
SelectVisualStudioVersion
Either throws an exception or selects an eacceptable version of VS on this 
computer. We look for Visual Studio vNext first and then Visual Studio 2015,
throwing an exception if we don't find one of these versions.

.EXAMPLE
SelectVisualStudioVersion -UseVS2015 $true
Either selects Visual Studio 2015 for debugging or throws an exception if we can't find it.
#>
function SelectVisualStudioVersion(
    [bool]$UseVS2015)
{
    if ($UseVS2015)
    {
        if (TryVisualStudio2015)
        {
            return
        }
        
        throw "-VS2015 parameter specified but Visual Studio 2015 is not installed."
    }
    else
    {
        if (TryVisualStudioVNext)
        {
            return
        }
        elseif (TryVisualStudio2015)
        {
            return
        }
    }
    
    throw "VSDebugD requires Visual Studio vNext or 2015"
}

<#
.SYNOPSIS
 ValidateConnection - insures we have a device connection

.DESCRIPTION
When TShell connects to the device, it sets DeviceAddress, so this function
tests that variable and throws if it is not set.

.EXAMPLE
ValidateConnection
Either throws an exception or validates that there is a TShell connection.
#>
function ValidateConnection
{  
    if (-not (Test-Path Variable:DeviceAddress))
    {
        throw "VSDebugD requires a device connection"
    }
}

<#
.SYNOPSIS
Extract build information for later use.

.DESCRIPTION
Parses the buildinfo.xml file into the $Script:BuildInfo collection.
Also extracts the windows version from the registry and populates 
$Script:BuildInfo."windows-version".

.EXAMPLE
DetermineBuildInformation
Extracts info from buildinfo.xml
#>
function DetermineBuildInformation
{
    try
    {
        # Extract build information from buildinfo.xml
        $buildInfo = typed \windows\system32\buildinfo.xml
        $Script:BuildInfo =  ([xml]$buildInfo)."build-information"

        # Add the indows version to that.
        $winVerValue = regd query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v BuildLabEx
        $Script:WindowsVersion = ($winVerValue | Select-String "\b(\d+)\..*").Matches.Groups[1].Value
    }
    catch
    {
        Write-Warning "Unable to extract build information from buildinfo.xml"
        $Script:BuildInfo = $null
    }
}

<#
.SYNOPSIS
 Sets $Script:TargetArch to "x86" or $Script:ArmArch based on PROCESSOR_ARCHITECTURE
 environment variable on the device.

.DESCRIPTION
Uses the Cmd-Device cmdlet to get the value of the PROCESSOR_ARCHITECTURE environment
variable on the device and stores it into $Script:TargetArch

.EXAMPLE
DetermineArchitecture
Will validate that the architecture is "ARM" or "x86", throwing an exception if it is
not.
#>
function DetermineArchitecture
{
    $result = Cmd-Device "set PROCESSOR_ARCHITECTURE"
    
    if ($result.Output)
    {
        $Script:TargetArch = $result.Output.Split("=")[1].Substring(0, 3)
    }
    
    if ($Script:TargetArch -ne $Script:ArmArch -and $Script:TargetArch -ne $Script:x86Arch)
    {
        throw "Can't determine the architecture of the target"
    }
}

<#
.SYNOPSIS
 Determine the attached device''s system drive based on the SystemDrive
 environment variable. Sets $Script:$systemDrive

.DESCRIPTION
Uses the Cmd-Device cmdlet to get the value of the SystemDrive environment
variable on the device and stores it into $Script:TargetArch 

.EXAMPLE
DetermineSystemDrive
Will extract the system drive from the target device environment.  It will
throw if this action fails.
#>
function DetermineSystemDrive
{
    $result = Cmd-Device "set SystemDrive"
    $Script:SystemDrive = $result.Output.Split("=")[1].SubString(0, 2)
    
    if (-not $Script:systemDrive)
    {
        throw "Can't determine the system drive of the target"
    }
}

<#
.SYNOPSIS
 Determine if caller's path exists on the device

.DESCRIPTION
Performs a a dird on the targetPath parameter.  We use the fact thatdird will
throw if the path doesn't exist. returns: $true if the target path exists on the device.

.PARAMETER TargetPath 
The path to be tested.

.EXAMPLE
DoesTargetPathExist c:\test\tuxnet.exe
Returns $true if c:\test\tuxnet.exe exists, otherwise $false.
#>
function DoesTargetPathExist(
    [String] $TargetPath)
{
    try
    {
        dird /B $TargetPath | Out-Null
        return $true
    }
    catch
    {
        return $false
    }
}

<#
.SYNOPSIS
Copy caller's directory and descendants.

.DESCRIPTION
Copies a directory structure from the desktop to the device, creating any
needed directories on the device.

.EXAMPLE
CopyFilesRecursively c:\testsetup c:\test\mytest
Copies everything under c:\testsetup on the host computer to c:\test\mytest on the device.
#>
function CopyFilesRecursively(
    [String] $SourceBase,
    [String] $DestBase)
{
    if (!(DoesTargetPathExist $DestBase))
    {
        MkDir-Device $DestBase
    }
    
    Put-Device -Destination $DestBase\. -source $SourceBase\*.*
    
    $subDirs = Get-ChildItem $SourceBase | Where-Object {$_.PSIsContainer -eq $true}
    if (-not $subDirs)
    {
        return
    }
    
    foreach ($oneDir in $subDirs)
    {
        $newSource = $SourceBase + "\" + $oneDir.ToString()
        $newDest = $DestBase + "\" + $oneDir.ToString()
        CopyFilesRecursively -sourceBase $newSource -destBase $newDest
    }
}

<#
.SYNOPSIS
If needed, copy the needed file to the device

.DESCRIPTION
If $neededFile doesn't on the device, offer to copy it from the latest POD build
If the user  agrees, we attempt the copy using putd.  If there is an error with
the putd or the user enters "N", we throw and exception.

.PARAMETER debugType
The debugging time for display purposes.

.PARAMETER devicePath
Path on the device to the binary we want.

.PARAMETER podBranchTemplate
String template for start of POD path.

.PARAMETER podFilePathTemplate
String template for trailing part of POD path.
    
.EXAMPLE
CopyNeededFile $Script:ManagedType $Script:MscoreeeHelper $Script:PodBranchTemplate $Script:DllPathTemplate
Makes sure that MsCoreeHelper.dll is on the device for managed debugging. 
#>
function CopyNeededFile(
    [String]$debugType,
    [String]$devicePath,
    [String]$podBranchTemplate,
    [String]$podFilePathTemplate)
{
    $success = $false
    $displayName = [System.IO.Path]::GetFileName($devicePath)
    
    if (DoesTargetPathExist $devicePath)
    {
        return 
    }
    
    Write-Warning "$displayName is needed for $debugType debugging and is missing."
    
    # Determine branch to use.
    $branch = $Script:BuildInfo."release-label"
    if ([String]::IsNullOrEmpty($branch))
    {
        $branch = $Script:WpmainBranch
    }
    
    # Build path to the needed file on the POD build
    try
    {
        $fullPath = $null
        $podPath = [String]::Format($podBranchTemplate, $branch)
        if (-not (Test-Path $podPath)) {
            $podPath = [String]::Format($OldPodBranchTemplate, $branch)
        }
        $podFilter = [String]::Format("{0}.*", $branch)
        $podList = Get-ChildItem -Path $podPath -Filter $podFilter -ErrorAction SilentlyContinue | Sort CreationTime -Descending
        while (!$fullPath)
        {
            
            # Attempt to find a copy of the DLL on the POD
            $testPath = $null
            foreach ($podEntry in $podList)
            {
                $testPath = [String]::Format($podFilePathTemplate, $podPath, $podEntry.Name, $Script:TargetArch)
                if (Test-Path $testPath)
                {
                    $fullPath = $testPath
                    break;
                }
            }
            
            if (!$fullPath)
            {
                # If there is no POD build for this branch, try wpmain.  If we have already tried wpmain, it's time to quit.
                if ($branch -ine $Script:WpmainBranch)
                {
                    Write-Warning "Didn't find $displayName on the POD build for $branch, now looking at $($Script:WpmainBranch)."
                    $branch = $Script:WpmainBranch
                }
                else
                {
                    throw "Cannot find a copy of $dispolayName on the POD"
                }
            }
        }
        
        $yesNo = Read-Host "Copy it from $fullPath to $devicePath on the device?[yes/no]"
        if ($yesNo.ToLower().StartsWith("y"))
        {
            putd $fullPath $devicePath
            $success = $true;
        }
    }
    
    catch
    {
        Write-Warning $_.Exception.Message
        Write-Warning "Unable to copy $displayName from $branch."
    }
    
    if (!$success)
    {
        Write-Warning "To continue $debugType debugging, please copy $displayName to $devicePath"
        throw "Unable to continue $debugType debugging without $displayName"
    }
}

<#
.SYNOPSIS
Find a copy of the same build on the POD

.DESCRIPTION
Get the build information from the registry and the XML file, \windows\system32\buildinfo.xml.
Use the build information to construct a POD path and copy the file if its there.

.PARAMETER $DevicePath
Path to binary on the device.

.EXAMPLE
CopySameBuildForExeFromPOD "\test\dbg\applauncher.exe"
If possible, copies the correct copy of applauncher from the POD.
#>
function CopySameBuildForExeFromPOD(
    [string] $DevicePath)
{
    try
    {
        if ($Script:BuildInfo)
        {
            # Make a copy of $Script:BuildInfo to make the following a little more readable
            $bi = $Script:BuildInfo
            $sku = "{0}.{1}{2}" -f $bi."target-os", $bi."target-cpu", $bi."build-type"      

            $podPath = $podBranchTemplate -f $bi."release-label"

            if (-not (Test-Path $podPath)) {
                $podPath = $OldPodBranchTemplate -f $bi."release-label"
            }

            Write-Host "Looking for $([System.IO.Path]::GetFileName($DevicePath)) under $podPath..."

            $podFilter = [String]::Format("{0}.*.{1}.*", $bi."release-label", $bi."parent-branch-build")
            
            $podList = Get-ChildItem -Path $podPath -Filter $podFilter -ErrorAction SilentlyContinue | Sort CreationTime -Descending

            $testPath = $null
            foreach ($podEntry in $podList)
            {
                $testPath = "{0}\{1}\{2}\" -f $podPath, $podEntry.Name,$sku
                $testPath += "Binaries\bin\debugger\"
                $testPath += "{0}\{1}\{2}" -f $bi."target-cpu", $bi."build-type", [System.IO.Path]::GetFileName($DevicePath)
                
                if (Test-Path $testPath)
                {                    
                    $fullPath = $testPath
                    break;
                }
            }

            if (Test-Path $fullPath)
            {
                Write-Host "Copying $fullPath to $DevicePath"
                putd -Source $fullPath -Destination $DevicePath
                return $fullPath
            }
        }
        else
        {
            Write-Warning "Build information not found, unable find match for ([System.IO.Path]::GetFileName($DevicePath))"
        }
        
        return $null        
    }       
    catch
    {
        return $null
    }
}


<#
.SYNOPSIS
Copy the file denoted by $DevicePath from the matching directory on the POD. 

.DESCRIPTION
Get the build information from the registry and the XML file, \windows\system32\buildinfo.xml.
Use the build information to construct a POD path and copy the file if its there,.

.PARAMETER $DevicePath
Path to binary on the device.

.EXAMPLE
CopyExactMatchForExeFromPOD "\test\dbg\applauncher.exe"
If possible, copies the correct copy of applauncher from the POD.
#>
function CopyExactMatchForExeFromPOD(
    [string] $DevicePath)
{
    try
    {
        if ($Script:BuildInfo)
        {
            $bi = $Script:BuildInfo
            
            $targetCPU = $bi."target-cpu"
            $buildType = $bi."build-type"     
            $sku = "{0}.{1}{2}" -f $bi."target-os", $targetCPU, $buildType

            $podPath = "$($Script:PodBranchTemplate)\{0}.{1}.{2}.{3}\" -f $bi."release-label", $Script:WindowsVersion, $bi."parent-branch-build", $bi."build-time"

            if (-not (Test-Path $podPath)) {
                $podPath = "$($Script:OldPodBranchTemplate)\{0}.{1}.{2}.{3}\" -f $bi."release-label", $Script:WindowsVersion, $bi."parent-branch-build", $bi."build-time"
            }

            $podPath += "{0}\Binaries\bin\debugger\{1}\{2}\{3}" -f $sku, $targetCPU, $buildType, [System.IO.Path]::GetFileName($DevicePath)

            Write-Host "Looking for $([System.IO.Path]::GetFileName($DevicePath)) in $podPath"

            if (Test-Path $podPath)
            {
                Write-Host "Copying $podPath to $DevicePath"
                putd -Source $podPath -Destination $DevicePath
                return $podPath
            }
            Write-Host "Not found."
        }
        else
        {
            Write-Warning "Build information not found, unable to get exact match for ([System.IO.Path]::GetFileName($DevicePath))"
        }
        
        return $null        
    }       
    catch
    {
        return $null
    }
}

<#
.SYNOPSIS
If needed, copy MscoreeHelper.dll to device

.DESCRIPTION
 We need MscoreeHelper.dll for debugging managed EXEs (like Tuxnet).  If it doesn't
 exist at c:\data\test\bin, offer to copy it from the latest POD build. If the user
 agrees, we attempt the copy using putd.  If there is an error with the putd or
 the user enter "N", we throw and exception.

.EXAMPLE
CopyMscoreeHelperToDevice
Makes sure that MsCoreeHelper.dll is on the device for managed debugging. 
#>
function CopyMscoreeHelperToDevice
{
    CopyNeededFile $Script:ManagedType $Script:MscoreeeHelper $Script:PodBranchTemplate $Script:DllPathTemplate
}

<#
.SYNOPSIS
Copies required debugger files from the desktop to the device.

.DESCRIPTION
 Copies the files found at \VSDebugD\msvsmon\x86ret or \VSDebugD\msvsmon\armret 
 to c:\test\dbg on the Device.

.EXAMPLE
CopyDebuggerFilesToDevice
Copies all the needed debugger files from the msvsmon subdirectory (under VSDebugDPath)
to c:\test\dbg on the device. 
#>
function CopyDebuggerFilesToDevice
{
    if (-not $Script:VSDebugDPath)
    {
        throw "Need VSDebugDPath to install Windows Phone VS files to the target."
    }

    # The user may have changed devices - we would have no way of seeing that.
    if (-not (DoesTargetPathExist $Script:Launcher -and DoesTargetPathExist $Script:IsManaged -and DoesTargetPathExist $Script:AppXEnumerator))
    {
        $Script:InstallCheck = $null
    }
    
    if (-not $Script:InstallCheck -or $Script:InstallCheck -ne $Global:DeviceAddress)
    {
        $dest = $systemDrive + '\test\dbg'
        if ($Script:TargetArch -eq $Script:x86Arch)
        {
            $archDir = 'x86ret'
        }
        else
        {
            $archDir = 'armret'
        }
        
        $source = $Script:VSDebugDPath + '\msvsmon\' + $Script:VsVersion + '\' + $archDir
        
        Write-Host "Copying $source to $dest on target."
        
        # Just in case msvsmon or applauncher are running on the device.
        $result = Cmd-Device -Command $Script:Kill -Arguments "msvsmon"
        $result = Cmd-Device -Command $Script:Kill -Arguments "applauncher"
        
        CopyFilesRecursively -sourceBase "$source" -destBase $dest

    }
    else
    {
        Write-Host "Skipping update of device-side files, which have already been updated for this debug session."
    }
}

<#
.SYNOPSIS
 Start-Msvsmon - Start up msvsmon.exe on the device

.EXAMPLE
Start-Msvsmon
Executes the script \test\dbg\start_msvsmon.cmd on the device.
#>
function Start-Msvsmon
{
    $msvsmonCmd = "start_msvsmon.cmd"
    $testDbg = "$systemDrive\test\dbg"
    
    Write-Host "Starting $msvsmonCmd $Script:MsvsmonPort"
    
    # start_msvsmon.cmd needs to be run out of its directory, so we CD there 

    # but remember where we were.
    $here = CD-Device
    try
    {
        CD-Device $testDbg
        $result = Exec-Device -Asynchronous  -FileName $msvsmonCmd -Arguments $Script:MsvsmonPort | Out-Null
    }
    catch
    {
        throw "An error occurred trying to start msvsmon.exe: $Error"
    }
    finally
    {
        CD-Device $here
    }
}

<#
.SYNOPSIS
 GetRawProcessList returns an String array containing the output from
 Tlist-Device -s.

 .EXAMPLE
$processList = GetRawProcessList
Returns the complete raw process list on the device.
#>
function GetRawProcessList
{
    $rawList = TList-Device -s
    if (!$rawList -or [String]::IsNullOrEmpty($rawList))
    {
        Write-Error "Couldn't get the process list with Tlist-Device"
        exit
    }
    else
    {
        $rawArray = $rawList.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
        return $rawArray
    }
}

<#
.SYNOPSIS
Given a line of Tlist-Device output, extract the process ID if the name matches

.DESCRIPTION
Uses a regular expression to parse the Tlist-Device output and extract the process IDs from it.  Returns either -1
for "not found" or the process ID we found.

.PARAMETER ProcessLine
A line of Tlist-Device output.

.PARAMETER ProcessName
The name of the process we are looking for.

.EXAMPLE
$thisProcessPid = ExtractPidForMatchingName $processLine $processName
Sets $thisProcessPid to the process ID of $processName from $processLine,
if it is there.
#>
function ExtractPidForMatchingName(
    [String] $ProcessLine, 
    [String] $ProcessName)
{   
    $match = ($ProcessLine | Select-String $Script:pidExtractionRegEx)
    if ($match -and $match.Matches -and $match.Matches[0].Success)
    {
        $name = $match.Matches[0].Groups["name"].Value
        if ($ProcessName -ieq $name)
        {
            $refPid = -1
            $thisPid = $match.Matches[0].Groups["thisPid"].Value
            if ([Int]::TryParse($thisPid, [ref]$refPid))
            {
                return $refPid
            }
            else
            {
                throw "Unexpected error encountered in Tlist-Device response for $name."
            }
        }
    }
    return -1
}

<#
.SYNOPSIS
Adds to caller's collection of id/name pairs for SearchName

.DESCRITION
GetCurrentProcessCollection builds a collection of Process ID/Process name pairs
that match $SearchName

.PARAMETER SearchName 
The process name to search for. $null in this parameter means "all"

.PARAMETER $MatchingPids
A reference to a StringDictionary that this function fill with the entries 
matching SearchName.

.EXAMPLE
GetCurrentProcessCollection $NameExtension ([ref]$afterList)
Populates $afterList with 0 or more entries that match $NameExtension
#>
function GetCurrentProcessCollection(
    [String] $SearchName,
    [ref][System.Collections.Specialized.StringDictionary] $MatchingPids)
{
    $MatchingPids.Value.Clear()
    
    $processList = GetRawProcessList
    foreach ($process in $processList)
    {
        $match = ($process | Select-String $Script:pidExtractionRegEx)
        if ($match -and $match.Matches -and $match.Matches[0].Success)
        {
            $name = $match.Matches[0].Groups["name"].Value
            $refPid = -1
            $thisPid = $match.Matches[0].Groups["thisPid"].Value
            if ([Int]::TryParse($thisPid, [ref]$refPid))
            {
                if ($SearchName -ieq $name)
                {
                    $MatchingPids.Value.Add($thisPid.ToString(), $name)
                }
            }
        }
    }
}

<#
.SYNOPSIS
Returns the Process ID for the $ProcessName parameter. Zero means no process
found and -1 means duplicates were found.

.DESCRIPTION
DetermineProcessIdFromName cycles through the raw process list and extract every process
that matches processname. If there is more than one match and $ResolveDulicates is $true,
prompt the user to make a selection.

.PARAMETER ProcessName
The name of the process

.EXAMPLE
$ProcessId = DetermineProcessIdFromName $Name
Finds the process ID of the process named by $Name
#>
function DetermineProcessIdFromName(
    [String] $ProcessName)
{
    $matchingPids = New-Object -TypeName System.Collections.Specialized.StringDictionary
    $processList = GetRawProcessList
    $matchedProcessPid = -1
    $exeEnding = ".exe"
    
    if (-not $ProcessName.EndsWith($exeEnding, [System.StringComparison]::OrdinalIgnoreCase))
    {
        $ProcessName += $exeEnding
    }
    
    foreach ($process in $processList)
    {
        $thisProcessPid = ExtractPidForMatchingName $process $ProcessName
        if ($thisProcessPid -ne -1)
        {
            $matchedProcessPid = $thisProcessPid
            $matchingPids.Add($thisProcessPid.ToString(), $process)
        }
    }
    
    if ($matchingPids.Count -eq 0)
    {
        throw "Could not determine process ID from the process name $ProcessName"
    }
    
    if ($matchingPids.Count -eq 1)
    {
        return $matchedProcessPid
    }
    
    $thisProcessPid = -1
    
    while ($true)
    {
        $pidAsString = Read-Host "Enter the process ID to be debugged from the list above[blank entry to quit]"
        $pidAsString = $pidAsString.Trim()
        if ([String]::IsNullOrWhiteSpace($pidAsString))
        {
            throw "Blank entry detected, so quitting..."
        }
        elseif ([Int]::TryParse($pidAsString, [ref] $thisProcessPid))
        {
            $match = $matchingPids[$thisProcessPid.ToString()]
            if ($match)
            {
                return $thisProcessPid
            }
            else
            {
                Write-Host "$pidAsString doesn't match any of the above processes."
            }
        }
        else
        {
            Write-Host "$pidAsString isn't a valid process - enter a number from the list."
        }
    }
}

<#
.SYNOPSIS
Returns the ID of the process supported the service identified by the ServiceName paramter.

.DESCRIPTION
Handles one line of Tlist-Device outuput. If it contains a match on ServiceName, returns the ID
of that process else -1, indicating "not found".

.PARAMETER ProcessLine
A line of Tlist-Device output, possibly containing service information

.EXAMPLE
$thisProcessPid = ExtractPidForMatchingService $processLine $ServiceName
Sets $thisProcessPid to the process ID of $ServiceName if it is contained in the
line of raw process data in $processLine.
#>
function ExtractPidForMatchingService(
    [String] $processLine,
    [String] $serviceName)
{
    
    $match = ($processLine | Select-String "^\s*(?<pid>[0-9]+)\s+(?<name>[^\s].*\.exe)(\s+Svcs\:\s+(?<svcs>[^\s].*$))?")
    if ($match -and $match.Matches -and $match.Matches[0].Success)
    {
        $servicesWork = $match.Matches[0].Groups["svcs"].Value
        if ($servicesWork)
        {
            $services = $servicesWOrk.Split(',')
            foreach ($service in $services)
            {
                if ($service -ieq $serviceName)
                {
                    $pidAsInt = -1
                    $pidAsString = $match.Matches[0].Groups["pid"].Value
                    if ([Int]::TryParse($pidAsString, [ref] $pidAsInt))
                    {
                        return $pidAsInt
                    }
                    else
                    {
                        return -1
                    }
                }
            }
        }
    }
    return -1
}

<#
.SYNOPSIS
Returns the process ID supporting the service named by ServiceName

.DESCRIPTION
Interates over the processes running on the phone, Looking for a process that
provices the service named by $ServiceName

.PARAMETER ServiceName 
Designates the service of interest.

.EXAMPLE
$ProcessId = DetermineProcessIdFromService $Psn
Sets $ProcessId to the process support the service named by $Psn.
#>
function DetermineProcessIdFromService(
    [String] $ServiceName)
{
    $processList = GetRawProcessList
    foreach ($process in $processList)
    {
        $thisProcessPid = ExtractPidForMatchingService $process $ServiceName
        if ($thisProcessPid -ne -1)
        {
            return $thisProcessPid
        }
    }
    throw "Could not determine process ID from the service name 1"
}

<#
.SYNOPSIS
Returns an ID  in $NewProcesses that is not in $OldProcesses.

.DESCRIPTION
Iterates through $NewProcesses looking for an ID that is not in the
$OldProcess collection.

.PARAMETER NewProcesses
The most recent list of processes on the device.

.PARAMETER OldProcesses
The original list of processes on the device.

.EXAMPLE
$retPID = FindNew $afterList $beforeList
Sets $retPID to the first process ID in $afterList that is not in $beforeList.
#>
function FindNew(
    [System.Collections.ArrayList]$NewProcesses, 
    [System.Collections.ArrayList]$OldProcesses)
{
    if ($NewProcesses.Count -gt 0)
    {
        foreach ($id in $NewProcesses)
        {
            if ($OldProcesses.Contains($id) -ne $true)
            {
                return $id
            }
        }
    }
    return -1
}

<#
.SYNOPSIS
Parses UMJIT output and make a list of processes matching

.DESCRIPTION
Iterates through the UMJIT output, looking for a match on $MatchCriteria.
Adds any matches to the $MatchingList

.PARAMETER MatchCriteria
The critieria to match against in the UMJIT output.

.PARAMETER UmjitOutput
A String array containing the UMJIT output.

.PARAMETER MatchingList
The output of this function - a collection of matching process IDs.  

.EXAMPLE
GetMatchingPidsFromUmjitOutput $MatchCriteria $umjitOutput $MatchingList
Populates $MatchingList with all process IDs in the UMJIT output, that
match $MatchCriteria
#>
function GetMatchingPidsFromUmjitOutput(
    [String] $MatchCriteria,
    [String[]] $UmjitOutput,
    [ref][System.Collections.ArrayList] $MatchingList)
{
    
    [System.Text.RegularExpressions.Regex]$pidRegex = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList "^\s*(?<pid>[0-9]+):"
    [System.Text.RegularExpressions.Regex]$cmdRegex = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList "^\s*CommandLine=(?<cmd>.*)$"
    
    $thisPid = -1
    foreach ($umjitLine in $UmjitOutput)
    {
        [System.Text.RegularExpressions.Match]$pidMatch = $pidRegex.Match($umjitLine)
        if ($pidMatch.Success)
        {
            $thisPid = $pidMatch.Groups["pid"].Value
        }
        else
        {
            [System.Text.RegularExpressions.Match]$cmdMatch = $cmdRegex.Match($umjitLine)
            if ($cmdMatch.Success)
            {
                $thisCmd = $cmdMatch.Groups["cmd"].Value
                if ($thisPid -ne -1)
                {
                    if ($thisCmd -eq $MatchCriteria)
                    {
                        [Void]$MatchingList.Value.Add($thisPid)
                        $thisPid = -1
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
 GetMatchingPids runs UMIT to get list of matching process IDs

.PARAMETER MatchCriteria
The critieria to match

.PARAMETER MatchingList
The output of this function - a collection of matching process IDs.  

.EXAMPLE
GetMatchingPids "ping.exe" ([ref]$beforeList)
Runs umjit -l and populates $beforeList with process IDs of any processes
named "ping.exe".
#>
function GetMatchingPids(
    [String] $MatchCriteria,
    [ref][System.Collections.ArrayList] $MatchingList)
{
    $umjitArgs = "-l"
    
    try
    {
        $result = Exec-Device -FileName $Script:UmjitCmd -Arguments $umjitArgs -HideOutput
    }
    catch
    {
        throw "An error occurred trying to run umjit -l: $Error"
    }
    
    if ($result.Output -and $result.ExitCode -eq 0)
    {
        $umjitOutput = $result.Output.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        
        GetMatchingPidsFromUmjitOutput $MatchCriteria $umjitOutput $MatchingList
    }
}

<#
.SYNOPSIS
 GetNewProcess finds the process in the $CurrentProcessList than is not int he $InitialProcessList 

.DESCRIPTION
Iterates through the CurrentProcessList, looking for a process that is not on the $InitialProcessList.
Returns either a process ID or 0.

.PARAMETER InitialProcessList
The initiali list of processes before we started a new one.  This list is limited to processes
of the same name.

.PARAMETER CurrentProcessList
The current list of processes.

.EXAMPLE
$newProcess = GetNewProcess $InitialList $afterList
Sets $newProcess to the first process ID in $afterList that is not in $InitialList
#>
function GetNewProcess(
    [System.Collections.Specialized.StringDictionary] $InitialProcessList, 
    [System.Collections.Specialized.StringDictionary] $CurrentProcessList)
{
    if ($CurrentProcessList)
    {
        foreach ($oneProcess in $CurrentProcessList)
        {
            if ((-not $InitialProcessList) -or (-not $InitialProcessList.ContainsKey($oneProcess.Key)))
            {
                $retPid = -1
                if ([Int]::TryParse($oneProcess.Key, [ref]$retPid))
                {
                    Write-Host "Found $($oneProcess.Key)"
                    return $retPid
                }
                else
                {
                    throw "Unexpected conversion problem in GetNewProcess"
                }
            }
        }
    }
    return 0
}

<#
.SYNOPSIS
 WaitForProcessTilTimeout waits for a new process to appear or until timeout

.DESCRIPTION
Checks every two seconds for the named process to appear.  Returns the new
process ID

.PARAMETER NameExtension
The process filename and extension

.PARAMETER InitialList
The list of processes before we started a new one.

.PARAMETER RetryCount
The number of times to look for the new process. There is a two second delay
betweet attempts.

.EXAMPLE
$retPid = WaitForProcessTilTimeout "ping.exe" $beforeList 30
Waits up to 30 seconds for a new process to appear named "ping.exe" and sets
$retPid to its process ID.
#>
function WaitForProcessTilTimeout(
    [String] $NameExtension, 
    [System.Collections.Specialized.StringDictionary] $InitialList, 
    [Int32] $RetryCount)
{
    [TimeSpan]$errorRetryDelayInterval = New-Object System.TimeSpan(0, 0, 2)
    
    while ($RetryCount -gt 0)
    {
        [System.Threading.Thread]::Sleep($errorRetryDelayInterval)
        $afterList = New-Object -TypeName System.Collections.Specialized.StringDictionary
        GetCurrentProcessCollection $NameExtension ([ref]$afterList)
        $newProcess = GetNewProcess $InitialList $afterList
        
        if ($newProcess -ne 0)
        {
            return $newProcess
        }
        
        $RetryCount--
    }
    return 0
}

<#
.SYNOPSIS
Starts the named Silverlight process.

.DESCRIPTION
Sets a magic reg key to cause the Apps host to wait for a debugger attach on startup.
Disables the app timeout so that it the App doesn't timeout waiting for the attach.
Captures the current process collection.
Runs Applauncher.exe
Looks for the App host to appear.

.PARAMETER AppId
The Silverlight Apps ID, which will be something like:
app://619C483B-BA14-432C-8611-DD6A6AA08888/_default

.EXAMPLE
StartSilverLightProcess app://619C483B-BA14-432C-8611-DD6A6AA08888/_default
Starts the process designated by the app ID, app://619C483B-BA14-432C-8611-DD6A6AA08888/_default.
#>
function StartSilverLightProcess(
    [String] $AppId)
{   
    # The app will be a DLL called by taskhost.exe
    $host = "taskhost.exe"
    
    PerformRevertableRegistrationAction @("add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 1 /f",
        "add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 0 /f")
    
    PerformRevertableRegistrationAction @("add HKLM\System\ControlSet001\Services\CoreUI\Navigation\Timeouts /v Enabled /t REG_DWORD /d 0 /f",
        "add HKLM\System\ControlSet001\Services\CoreUI\Navigation\Timeouts /v Enabled /t REG_DWORD /d 1 /f")
    
    $beforeList = New-Object -TypeName System.Collections.Specialized.StringDictionary
    GetCurrentProcessCollection $host ([ref]$beforeList)
    
    Write-Host "Starting $AppId"
    
    $retry = $true
    $tryOldLauncher = $false
    $launcher = $Script:Launcher
    while ($retry) {
        $retPid = 0
        try {
            $result = Exec-Device -Asynchronous -FileName $launcher -Arguments "-appid $AppId"
            $retPid = WaitForProcessTilTimeout $host $beforeList 30
        }
        catch { }
        if ($retPid -eq 0) {
            if (-Not $tryOldLauncher) {
                $tryOldLauncher = $true
                $launcher = $Script:BlueLauncher
            } else {
                $retry = $false
            }
        }
        else {
            $retry = $false
        }
    }
    
    if ($retPid -eq 0)
    {
        Write-Warning "We can't seem to launch the App you specified. It may help to update the Launcher"
        Write-Warning "from the POD. You can try that with the -Update parameter."
        throw "Failed to start a new instance of $AppId"
    }
    
    return $retPid
}

<#
.SYNOPSIS
Starts the named Modern process.

.DESCRIPTION
Sets a magic reg key to cause the App host to wait for a debugger attach on startup.
Disables the App timeout so that it the App doesn't timeout waiting for the attach.
Captures the current process collection.
Runs Applauncher.exe
Looks for the App host to appear. This more difficult than in the case of Silverlight, since 
the App may be self-hosted or hosted by AgHost.exe.

.PARAMETER AumId
The Apps AumId, which will look something like:
    "PRWP81HubApp_95k6d2vatfycm!x84fc2644yfea9y47ecy806cy4d5035f7d375x"

.PARAMETER Type
A reference to the debugging type. StartModernProcess may change this.

.EXAMPLE
StartModernProcess PRWP81HubApp_95k6d2vatfycm!x84fc2644yfea9y47ecy806cy4d5035f7d375x $Type
Starts the process designated by PRWP81HubApp_95k6d2vatfycm!x84fc2644yfea9y47ecy806cy4d5035f7d375x ([ref]$Type)
#>
function StartModernProcess(
    [String] $aumId,
    [ref][string] $Type)
{   
    PerformRevertableRegistrationAction @("add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 1 /f",
        "add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 0 /f")
    
    PerformRevertableRegistrationAction @("add HKLM\System\ControlSet001\Services\CoreUI\Navigation\Timeouts /v Enabled /t REG_DWORD /d 0 /f",
        "add HKLM\System\ControlSet001\Services\CoreUI\Navigation\Timeouts /v Enabled /t REG_DWORD /d 1 /f")
    
    $beforeList = New-Object -TypeName System.Collections.Specialized.StringDictionary
    
    $package = GetFullPackageName $aumId
    $exeName = [System.IO.Path]::GetFileName($package.ExePath)
    
    GetCurrentProcessCollection $exeName ([ref]$beforeList)
    
    Write-Host "Starting $aumId and expecting $exeName to start."
    
    $result = Exec-Device -FileName $Script:Kill -Arguments $exeName
    
    $actualType = DetermineExeType -ExePath $package.ExePath

    if($actualType -ieq $Script:NativeType)
    {
        Write-Host "$exeName is a native App."
        if($Type.Value -ne $Script:NativeType)
        {
            Write-Warning "Overriding Type to  $Script:NativeType"
            $Type.Value = $Script:NativeType
        }
    }
    else
    {
        Write-Host "$exeName is a managed App."
        if($Type.Value -ne $Script:ManagedType)
        {
            Write-Warning "Overriding Type to  $Script:ManagedType"
            $Type.Value = $Script:ManagedType
        }
    }


    $retry = $true
    $tryOldLauncher = $false
    $launcher = $Script:Launcher
    while ($retry) {
        $retPid = 0
        try {
            if ($Type.Value -ieq $Script:NativeType) {
                Write-Host "$launcher /AumId $aumId /pkg $($package.PackageName) /native"
                $result = Exec-Device -Asynchronous -FileName $launcher -Arguments "/AumId $aumId /pkg $($package.PackageName) /native"
            } else {
                Write-Host "$launcher /AumId $aumId /pkg $($package.PackageName)"
                $result = Exec-Device -Asynchronous -FileName $launcher -Arguments "/AumId $aumId /pkg $($package.PackageName)"
            }

            $retPid = WaitForProcessTilTimeout $exeName $beforeList 30
        } 
        catch { }
        if ($retPid -eq 0) {
            if (-Not $tryOldLauncher) {
                $tryOldLauncher = $true
                $launcher = $Script:BlueLauncher
            } else {
                $retry = $false
            }
        }
        else {
            $retry = $false
        }
    }
    
    if ($retPid -eq 0)
    {
        Write-Warning "We can't seem to launch the App you specified. It may help to update the Launcher"
        Write-Warning "from the POD. You can try that with the -Update parameter."
        throw "Failed to start a new instance of $aumId"
    }
    
    return $retPid
}

<#
.SYNOPSIS
Starts a managed process.

.DESCRIPTION
Gets the current collection of processes.
Sets the mscoree_debug environment variable to 1, telling mscoree to wait for a debugger attach and
starts the EXE named by $ProcessNameExt passing the parameters in $Arguments.
Waits the new process to start up.

.PARAMETER processNameExt
The filename of the process

.PARAMETER arguments
The program's parameters.

.EXAMPLE
StartManagedProcess "\test\tuxnet.exe" "-h"
Starts the tuxnet with the -h parameter in suspended fasion so that it will wait
for a debugger attachment before proceeding.
#>
function StartManagedProcess(
    [String] $ProcessNameExt,
    [String] $Arguments)
{
    PerformRevertableRegistrationAction @("add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 1 /f",
        "add HKLM\Software\Microsoft\TaskHost /v TestDebuggerAttach /t REG_DWORD /d 0 /f")
    
    $nameExtension = [System.IO.Path]::GetFileName($ProcessNameExt)
    $beforeList = New-Object -TypeName System.Collections.Specialized.StringDictionary
    GetCurrentProcessCollection $nameExtension ([ref]$beforeList)
    
    Write-Host "Staring $ProcessNameExt"
    
    start powershell.exe "-command &{open-device $DeviceAddress; Cd-Device $($Script:HomeDir);Cmd-Device '$ProcessNameExt $Arguments';pause}"
    
    $retPid = WaitForProcessTilTimeout $NameExtension $beforeList 30
    
    if ($retPid -eq 0)
    {
        throw "Failed to start a new instance of $ProcessNameExt"
    }
    
    return $retPid
}

<#
.SYNOPSIS
 StartNativeProcess starts caller's native process on the phone returning its PID

.DESCRIPTION
Gets UMJITs current list of PIDs with the same process name.
Asks UMJIT to start the process in suspended mode.
Waits until a new PID shows in the UMJIT list.
Returns the new PID.

.PARAMETER ProcessNameExt
The filename and extenion of the process we want to start.

.PARAMETER Arguments
The arguments for the process we want to start.

.EXAMPLE
$ProcessId = StartNativeProcess "ping.exe" "127.0.0.1"
Starts ping.exe in suspended fashion and returs its process ID.
#>
function StartNativeProcess(
    [String] $ProcessNameExt,
    [String] $Arguments)
{
    $umjitCmdLine = "$ProcessNameExt $Arguments"
    
    [System.Collections.ArrayList]$beforeList = @()
    GetMatchingPids $umjitCmdLine ([ref]$beforeList)
    
    Write-Host "Starting $ProcessNameExt"
    try
    {
        # We need to use the -Asyncronous option.  Unfortunately that reduces our capacity
        # to detect errors.
        $result = Exec-Device -Asynchronous -FileName $Script:UmjitCmd -Arguments "-s $umjitCmdLine"
        if ($result.ExitCode -ne 0)
        {
            throw "$result.ExitCode: $result.Output"
        }
    }
    catch
    {
        throw "An error occurred trying to start $ProcessNameExt : $Error"
    }
    
    # Wait till there is a new PID in the $afterList
    $retPID = -1
    $msDelay = 5000
    $maxAttempts = 12
    [System.Collections.ArrayList] $afterList = @()
    while ($retPid -eq -1)
    {
        GetMatchingPids $umjitCmdLine ([ref] $afterList)
        $retPID = FindNew $afterList $beforeList
        if ($retPID -eq -1)
        {
            [System.Threading.Thread]::Sleep($msDelay)
            $maxAttempts--
            if ($maxAttempts -eq 0)
            {
                throw "Timed out waiting for $ProcessNameExt to appear on the umjit -l list."
            }
        }
    }
    return $retPid
}

<#
.SYNOPSIS
Returns a collection of all the devenv processes running.

.DESCRIPTION
Calls Get-Process for all the running processes with a name of devenv.  
If there is only one, Get-Process returns a "Process" object instead
of a collection, so we coerce it into a collection.

.EXAMPLE
$devenvProcs = GetVSProcessCollection
Set $devenvProcs to the collection of Process objects for the instances of VS
running on the desktop.
#>
function GetVSProcessCollection
{
    $retValue = $null
    
    $procs = Get-Process -Name devenv  -ErrorAction Ignore
    
    if ($procs -ne $null)
    {
        $type = $procs.GetType();
        if ($type.Name -eq "Process")
        {
            $retValue = @()
            $retValue += $procs
        }
        elseif ($type.Name -eq "Object[]")
        {
            $retValue = $procs
        }
        else
        {
            throw "Get-Process returned an unexpected type."
        }
    }
    
    # Don't let Powershell flatten a one-elment collection.
    return , $retValue
}

<#
.SYNOPSIS
Starts up Visual Studio and sets $global.VsPid to its process ID.

.DESCRIPTION
Uses Start-Process with the -PassThru option to start VS and gather its
Process object.  In the postive case, we record the process ID.  We
catch the exception to detect and report on errors.
#>
function StartNewInstanceOfVisualStudio
{
    try
    {
        $process = Start-Process $Script:VsPath -PassThru
        $Script:VsPid = $process.Id
    }
    catch
    {
        Write-Error $_.Exception.Message
        throw "Unable to start Visual Studio"
    }
}

<#
.SYNOPSIS
This function will either get the process ID of a running copy of Visual Studio or
 start a new instance.

 .DESCRIPTION
 Calls GetVSProcessCollection to get a collection of the running instances of VS.
 If there are no running insances, start a new one and record its ID. If VSDebugD
 previously started VS and that instance is still running, use that instance, 
 otherwise, start a new instance of VS and record it's process ID.
 
 .EXAMPLE
 DetermineProcessIdOfVisualStudio
 Sets $Script:VsPid to the right instance of VS to use for debugging.  If we
 are reusing an instance it makes sure that VS is in a good state to attach.
#>
function DetermineProcessIdOfVisualStudio
{
    $procs = GetVSProcessCollection
    
    # If no instance of VS is running, start one.
    if ($procs -eq $null)
    {
        StartNewInstanceOfVisualStudio
    }
    else
    {
        # Determine if the previously used version of VS has been closed.
        if ($Script:VsPid -ne 0)
        {
            $match = $procs | Where {$_.Id -eq $Script:VsPid}
            if ($match -eq $null)
            {
                $Script:VsPid = 0
                StartNewInstanceOfVisualStudio
            }
            else
            {
                CheckVisualStudioStatus         
            }
        }
    }
}

<#
.SYNOPSIS
Invokes a helper function to check the status of the VS Debugger.

.DESCRIPTION
Assembles the helper programs command line and invokes the helper program to 
see if that instance of Visual Studio is in a state to perform an Attach.

.EXAMPLE
CheckVisualStudioStatus
Throws an exception if VS is already debugging and not in a good state to
perform an Attach.
#>
function CheckVisualStudioStatus
{
    $results = PerformVisualStudioAction $Script:CheckAction
    
    if ($results.Count)
    {
        [String]$lastLine = $results[$results.Count - 1]
        if ($lastLine.StartsWith("Error:"))
        {
            throw $lastLine
        }
        else
        {
            Write-Host $lastLine
        }
    }
    else
    {
        throw "No output at all from Visual Studio status check"
    }
}

<#
.SYNOPSIS
Invokes a helper program to perform caller's action.

.DESCRIPTION
Assembles the helper programs command line and invokes the helper program to 
perform caller's action.

.PARAMETER Action
The action to add to the command line. 

.EXAMPLE
PerformVisualStudioAction "Detach"
Causes the current instance of VS to detach from the debuggee.

.EXAMPLE
PerformVisualStudioAction "Check"
Checks that the current instance of VS is in a good state to attach to a new
debuggee.
#>
function PerformVisualStudioAction(
    [String]$Action)
{
    $attacherPath = [System.IO.Path]::Combine($Script:VSDebugDPath , $Script:Attacher)
    
    if (Test-Path $attacherPath)
    {
        $attacherCommand = $attacherPath
        
        $attacherArgs = "-vspid " + $Script:VsPid 
        $attacherArgs += " -action " + $Action
        
        Write-Host "Determining if VS is in a good state to do the Attach."
        Write-Host "Start $attacherPath $attacherArgs"

        Invoke-Expression -Command  "$attacherCommand $attacherArgs" | Tee-Object -Variable result | Out-String
        
        return $result        
    }
    else
    {
        throw "Can't locate $Script:Attacher in $Script:VSDebugDPath."
    }
}

<#
.SYNOPSIS
Invokes a helper program to attach the VS Debugger to the process on the device.

.DESCRIPTION
Assembles the helper programs command line and invokes the helper program.

.EXAMPLE
ConnectVisualStudioToWPProcess "managed" 1209 "c:\mysymbols"
Causes VS to connect to managed process 1209 on the device, while adding 
"c:\mysymbols" to the symbol path (if not there already).
#>
function ConnectVisualStudioToWPProcess(
    [String] $Type,
    [String] $ProcessId,
    [String] $Symbols)
{
    $attacherPath = [System.IO.Path]::Combine($Script:VSDebugDPath , $Script:Attacher)
    
    if (Test-Path $attacherPath)
    {
        $done = $false
        
        $attacherCommand = $attacherPath
        
        if ($Type -ieq $Script:Modern -or $Type -ieq $Script:Silverlight -or $Type -ieq $Script:ManagedType)
        {
            $attacherType = $Script:ManagedType
        }
        else
        {
            $attacherType = $Script:NativeType
        }
        
        $attacherArgs = "-vspid " + $Script:VsPid 
        $attacherArgs += " -ip " + $Global:DeviceAddress + ":" + $Script:VsPort
        $attacherArgs += " -pid " + $ProcessId 
        $attacherArgs += " -type " + $attacherType
        
        if ($Symbols)
        {
            $attacherArgs += " -symbols $Symbols"
        }
        
        $errorRetryCount = 10
        [TimeSpan]$errorRetryDelayInterval = New-Object System.TimeSpan(0, 0, 10)
        
        Write-Host "Start $attacherPath $attacherArgs"
        
        while ($done -eq $false)
        {
            try
            {
                Invoke-Expression -Command  "$attacherCommand $attacherArgs" | Tee-Object -Variable result | Out-String
            }
            catch
            {
                Write-Warning "Encountered an error trying to run $attacher. Error=$LastExitCode "
            }
            
            if ($LASTEXITCODE -eq 0)
            {
                $done = $true
            }
            else
            {
                $errorRetryCount--
                if ($errorRetryCount -eq 0)
                {
                    throw "Retry attempts exhausted trying to run $attacher. Error=$LastExitCode "
                }    
                else
                {
                    [System.Threading.Thread]::Sleep($errorRetryDelayInterval)
                }
            }
        }
    }
    else
    {
        throw "Can't locate $($Script:Attacher) in $($Script:VSDebugDPath)."
    }
}

<#
.SYNOPSIS
Make one attempt to remove processId from UMJIT's held list and report the result.
Returns $true if successful, $false if not.

.DESCRIPTION
Runs Umjit.exe once with an "-rd=<pid>" comamnd line and collects the results.  The
one response that indicates success is "Released crashPid=", other responses mean
failure or "try again later".

.PARAMETER ProcessId
The ID of the process of interest.

.EXAMPLE
TryRemoveProcessFromHeldList 129
Attempts to remove process 129 from the UMJIT held list returning $true if successful
and $false if not successful.
#>
function TryRemoveProcessFromHeldList(
    [String] $ProcessId)
{
    if ($ProcessId -eq 0)
    {
        throw "Internal error in RemoveProcessFromHeldList.  Process should  not be zero."
    }
    
    $umjitArgs = "-rd=$ProcessId"
    $debuggerNotAttached = 690
    
    try
    {
        $result = Exec-Device -FileName $Script:UmjitCmd -Arguments $umjitArgs
    }
    
    catch
    {
        Write-Error "Encountered an exception when trying to remove $ProcessId from the held list. Error=$Error"
    }
    
    if ($result.ExitCode -eq $debuggerNotAttached)
    {
        return $false
    }
    
    if ($result.ExitCode -ne 0)
    {
        throw "Encountered an unexpected error when trying to remove $ProcessId from the held list. Error=$result.ExitCode"
    }
    else
    {
        return $true
    }
}

<#
.SYNOPSIS
Keep attempting to remove processId from UMJIT's held list.

.DESCRIPTION
Calls TryRemoveProcessFromHeldList until that call succeeds or the
retry counter goes to zero.

.PARAMETER ProcessId
The ID of the process on the device we want to remove from the held list.

.EXAMPLE
RemoveProcessFromHeldList 129
Removes process 129 from the UMJIT held list and throwing an exception if not
successful after 12 attempts.
#>
function RemoveProcessFromHeldList(
    [String] $ProcessId)
{
    $howLongToWaitForProcessRemoval = 12
    $removed = $false
    [System.TimeSpan]$processRemovalPollingInterval = New-Object System.TimeSpan(0, 0, 5)
    
    while (-not $removed -and $howLongToWaitForProcessRemoval -gt 0)
    {
        $removed = TryRemoveProcessFromHeldList $ProcessId
        if (-not $removed)
        {
            [System.Threading.Thread]::Sleep($processRemovalPollingInterval)
            $howLongToWaitForProcessRemoval--
            if ($howLongToWaitForProcessRemoval -eq 0)
            {
                Write-Error "Timed out trying to remove $ProcessId from the UMJIT held queue."
            }
        }
    }
}

<#
.SYNOPSIS
If needed, reset the change we made to the device registry.

.DESCRIPTIONS
The "undo" command for any changes to registry on the device are recorded in
$Script:CleanUp. Iterate through that collection and perform the
"undo" commands.

.EXAMPLE
CleanRegistry
Cycles through any entries in $Script:CleanUp, executing the commmands
with reg.exe.
#>
function CleanRegistry
{
    $cmd = "none"
    try
    {
        foreach ($cmd in $Script:CleanUp)
        {
            $result = Exec-Device -FileName $Script:RegExePath -Arguments $cmd -HideOutput
        }
    }
    catch
    {
        Write-Error "Could not reset important registry values, which may now be corrupted"
    }
}

<#
.SYNOPSIS
Returns type (managed vs. native) of $ExePath

.DESCRIPTION
Runs the helper program IsManaged.exe which returns one of:
    0  - EXE is native
    1  - EXE is managed
    -1 - An error; see IsManaged output

.PARAMETER ExePath
The path of the exe to be checked.

.EXAMPLE
$Type = DetermineExeType "\test\tuxnet.exe"
Should return "Managed"
#>
function DetermineExeType(
    [string] $ExePath)
{
    $result = Cmd-Device -Command $Script:IsManaged -Arguments "$ExePath" -HideOutput
    
    if($result.ExitCode -eq 0)
    {
        return $Script:NativeType
    }
    elseif($result.ExitCode -eq 1)
    {
        return $Script:ManagedType
    }

    throw "Error running $Script:IsManaged - $($result.Output)"
}

<#
.SYNOPSIS
If -AppName is specified, determine the AppId or Aumid and the $Typed

.DESCRIPTION
If the -AppName argument is present, call AppLauncher to learn the type and ID.

.PARAMETER AumId
A reference to a AumId which we may change if the App name maps to that.

.PARAMETER AppID
A reference to a AppId which we may change if the App name maps to that.

.PARAMETER AppName
The name of the App

.EXAMPLE
$type = DetermineAppFromName -Type $Type -AppID ([ref]$AppPid) -AumId ([ref]$AumId) -AppNmae $AppNmae 
#>
function DetermineAppFromName(
    [ref][String] $AppId,
    [ref][String] $AumId,
    [String] $AppName)
{
    if ($AppName)
    {
        $found = $false

        Write-Host "Calling $Script:Launcher -Describe -AppName `"$AppName`""
        try {
            $result = Exec-Device -FileName $Script:Launcher -Arguments "-Describe -AppName `"$AppName`"" -HideOutput
        }
        catch { 
            $result = Exec-Device -FileName $Script:BlueLauncher -Arguments "-Describe -AppName `"$AppName`"" -HideOutput
        }

        
        if ($result.Output -and $result.ExitCode -eq 0)
        {
            $rawArray = $result.Output.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
            $findNameValuePairs = "(?<name>\S+)\=(?<value>.*)"
        
            foreach ($line in $rawArray)
            {
                $match = ($line | Select-String $findNameValuePairs)
                if ($match -and $match.Matches -and $match.Matches[0].Success)
                {
                    $name = $match.Matches[0].Groups["name"].Value
                    $value = $match.Matches[0].Groups["value"].Value
                    
                    if ($name -eq "AumId")
                    {
                        $AumId.Value = $value
                        $found = $true
                    }
                    elseif ($name -eq "AppId")
                    {
                        $AppId.Value = $value
                        $found = $true                  }
                    elseif ($name -ne "AppTitle")
                    {
                        Write-Warning "Ignoring extraneous output from $Script:Launcher - $name=$value"
                    }                
                }               
            }

            if (-not $found)
            {
                throw "Failed to find a match for the AppName $AppName"
            }
        }
        else
        {
            throw "Error running $Script:Launcher /Describe - error is $($result.ExitCode) `n $($result.Output)"
        }
    }
}

<#
.SYNOPSIS
Apply process type defaults.

.DESCRIPTION
If the user codes an -AppId as a process designation, the default is silverlight,
in other cases, it is native.

.PARAMETER Type
This is the debugging type, as coded by the user. This function doesn't validate
but only cares if it needs a default (i.e.;is $null).

.PARAMETER AppId
The AppId of a silverlight program or possibly $null.

.PARAMETER AumId
The AumId of a Modern program or possibly $null.

.PARAMETER AppName
The AppName of a Silverlight, Silverlight 8.1 or Modern App

.EXAMPLE
$type = SelectTypeDefault -Type $Type -AppId $AppID -AppName $AppName
Will, if $Type is null, returns a default debugging type.  If $AppId is $null, the
default debugging type is native otherwise it is silverlight.
#>
function ApplyTypeDefault(
    [String] $Type,
    [String] $AppId,
    [String] $AumId,
    [string] $AppName)
{
    if (-not $Type)
    {   
        if ($AppId)
        {
            $Type = $Script:Silverlight
        }
        elseif ($AumId -or $AppName)
        {
            $Type = $Script:Modern
        }
        else
        {
            $Type = $Script:NativeType
        }
    }
    return $Type
}

<#
.SYNOPSIS
Return $true if string is a valid Silverlight APP ID

.DESCRIPTION
Performs a regular expression check on AppID.

.PARAMETER AppID
The Silverlight APP ID to be validated.

.EXAMPLE
IsValidAppID "fred"
Would return $false

.EXAMPLE
IsValidAppID "app://619C483B-BA14-432C-8611-DD6A6AA08888/_default"
would return $true
#>
function IsValidAppID(
    [string] $AppID)
{
    $regexArg = "^app\://[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
    [System.Text.RegularExpressions.Regex]$validApp = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $regexArg
    [System.Text.RegularExpressions.Match]$appMatch = $validApp.Match($AppID)
    return $appMatch.Success
}

<#
.SYNOPSIS
Validate the process designation, including its type.

.DESCRIPTION
The process can be designated by any one of 5 parameters. Validate that the
user only picked one and make sure the -Type parameter makes sense.

.PARAMETER pn
Specifies a Windows Phone process name to debug.

.PARAMETER psn
Specifies a Windows Phone service name to debug.

.PARAMETER processId
Specifies a Windows Phone service process ID to debug.

.PARAMETER fileName
Specifies a filename or app ID to start and then attach to.

.PARAMETER AppID
Specifies a application ID.

.PARAMETER AumID
Specifies a application User Model ID for a Silverlight-on-Blue or Modren app.

.PARAMETER arguments
Specifies arguments to pass to the process we are starting with fileName parameter.

.PARAMETER type
Specifies native or managed debugging, defaulting to native. Mixed-mode debugging isn't supported yet.

.EXAMPLE
ValidateProcessDesignation -Pn "ping.exe"
Validates that a -Pn of "ping.exe" is a validate process designation.

.EXAMPLE
ValidateProcessDesignation -Pn "ping.exe" -ProcessID 120
Throws an exception because the process is being designated two ways when only one way is allowed.
#>
function ValidateProcessDesignation
(
    [String] $Pn,
    [String] $Psn,
    [String] $ProcessId,
    [String] $FileName,
    [String] $AppId,
    [String] $AumId,
    [String] $AppName,
    [String] $Type
)
{
    # We want exactly one of -processId, -Pn, -psn, -fileName, or -appid
    $count = 0
    
    if ($FileName)
    { 
        $count++
    }
    
    if ($Pn)
    { 
        $count++
    }
    
    if ($Psn)
    { 
        $count++
    }
    
    if ($ProcessId)
    { 
        $count++
    }
    
    if ($AppId)
    { 
        $count++
    }
    
    if ($AumId)
    { 
        $count++
    }
    
    if ($AppName)
    { 
        $count++
    }
    
    if ($count -ne 1)
    {
        throw "Need exactly one of -Pn, -psn, -processId, -appid , -aumid, -appname or -filename"
    }
    
    # If there's a ProcessId it must be a number > 0
    if (![String]::IsNullOrEmpty($ProcessId))
    {
        $refPid = -1
        if ([Int]::TryParse($ProcessId, [ref]$refPid))
        {
            if ($refPid -le 0)
            {
                throw "processId must be greater than 0"
            }
        }
        else
        {
            throw "processId doesn't appear to be a number"
        }
    }
    
    # Validate process type - if specified, -type must be "managed", "native","silverlight", or "modern"
    if (($Type -ine $Script:ManagedType) -and ($Type -ine $Script:NativeType) -and ($Type -ine $Script:Silverlight) -and ($Type -ine $Script:Modern))
    {
        throw "type must be one of '$($Script:ManagedType)', '$($Script:NativeType)', '$($Script:Silverlight)', or  '$($Script:Modern)'"
    }
    
    # If AppName is present, that's all we can validate right now.
    if (-not $AppName)
    {
        # Validate app id, if present
        if ($AppId)
        {
            if ($Type -ine $Script:Silverlight)
            {
                throw "-AppId is only needed for starting silverligh Apps"
            }
        
            if (-not (IsValidAppID($AppID)))
            {
                throw "To start a Silverlight App, -AppId parameter needs to be a valid App ID"
            }
        }
        elseif ($Type -ieq $Script:Silverlight)
        {
            throw "To start a Silverlight App, you must provide an -AppId parameter."
        }
    
        # Validate AumId, if present
    
        if ($AumId)
        {
            if ($Type -ine $Script:Modern)
            {
                throw "-AumId is only needed for starting a modern app"
            }       
        }
        elseif ($Type -ieq $Script:Modern)
        {
            throw "To start a Modern App, you must provide an -AumId parameter."
        }
    
        # Validate -fileName, if present.
        if ($FileName -and !(DoesTargetPathExist $FileName))
        {
            throw "-fileName specifies a target that doesn't exist on the device."
        }
    }
}

<#
.SYNOPSIS
Gets the raw list of packages.

.DESCRIPTION
Uses regd to get the subkeys under the registry key
HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package
and returns the raw output to our caller.

.EXAMPLE
GetPackageList
Builds the RawPackage collection at $Script:rawPkgs
#>

function GetPackageList
{
    $rawOutput = regd query $Script:pkgRoot
    $RawArray = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) 
    
    foreach ($package in $RawArray)
    {
        $Script:rawPkgs.Add($package)
    }
}

<#
.SYNOPSIS
Gets all the subkeys under the given package registry key.

.DESCRIPTION
Enumerates the subkeys under the individual package's registry key, which looks something like:

HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package\
104af0de-efe1-4b4d-bea0-129f493e8f1f_1.0.0.2_x86__95k6d2vatfycm

.PARAMETER PackageRegKey
The package's registry key.

.EXAMPLE
$subkeys = GetServerSubkeys "HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package\104af0de-efe1-4b4d-bea0-129f493e8f1f_1.0.0.2_x86__95k6d2vatfycm"
#>
function GetServerSubkeys(
    [String] $PackageRegKey)
{
    try
    {
        $rawOutput = regd query "$PackageRegKey\Server"
        $rawArray = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) 
    }
    catch
    {
        $rawArray = $null
    }
    
    return , $rawArray
}

<#
.SYNOPSIS
GetSingleValueFromRegistry

.DESCRIPTION
Given a registry path and value name, return a single value from the connected
device's registry.

.PARAMETER ValueName
Value name to be retrieved.

.PARAMETER RegPath
Registry path to be used.

.EXAMPLE
GetSingleValueFromRegistry $ValueName $RegistryPath
#>
function GetSingleValueFromRegistry(
    [String]$ValueName,
    [String]$RegistryPath)
{
    $retValue = $null

    try
    {
        $rawOutput = regd query $RegistryPath
        $rawArray = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
    
        $regEx = "\s+(?<name>\S+)\s+\S+\s+(?<value>.*)"
        $rawArray | Select-String $regEx | 
        ForEach-Object {
            foreach ($match in $_.Matches)
            {
                $name = $match.Groups["name"].Value  
                $value = $match.Groups["value"].Value
                if ($name -ieq $ValueName)
                {
                    $retValue = $value
                }
            }
        }
    }
    catch
    {
        Write-Warning "Unable to read $ValueName from $RegistryPath"
    }

    return $retValue
}

<#
.SYNOPSIS
Determines the correct exe path for a given AUMID

.DESCRIPTION
The real executable path for each AUMID can be found under the registry key
<root key><PackageName>\ActivatableClassId\<PRAID> where

The root key is
HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package

The PackageName is something like: BatterySense_1.0.12281.709_x86__8wekyb3d8bbwe

And the PRAID is the part of the Aumid to the right of the exclamation mark, so in the case of
BatterySense_8wekyb3d8bbwe!BatterySense, it would be simply "BatterySense".  However, it is not
always that readable; consider the case of the zWebViewBrowser, where the PRAID is quite cryptic:

zWebViewBrowser_95k6d2vatfycm!x4b6e5721y0349y4a86yb414y205eea32d447x

.PARAMETER AddObject
This is the object representing the AUMID.

.PARAMETER PackageName
The name of the package weare working on.

.EXAMPLE
Add-CorrectExePath $AddObject $PackageName
#>
function Add-CorrectExePath(
    [ref][PSObject]$AddObject,
    [String]$PackageName)
{
    $userModelId = $AddObject.Value.AppUserModelId
    
    if (-not $userModelId)
    {
        throw "Unexpected problem fetching the $userModelId"
    }
    
    $praId = $userModelId.SubString($userModelId.IndexOf("!") + 1)
    
    if (-not $praId -or $praId.Length -eq 0)
    {
        throw "Unable to determine the executable to debug"
    }
    
    $server = GetSingleValueFromRegistry "Server" "$Script:pkgRoot\$PackageName\ActivatableClassId\$praId"
    
    if ($server -eq $null)
    {
        throw "Unable to determine the executable to debug"
    }
    
    $exeName = GetSingleValueFromRegistry "ExePath" "$Script:pkgRoot\$PackageName\Server\$server"
    
    if ($exeName -eq $null)
    {
        throw "Unable to determine the executable to debug"
    }
    
    $AddObject.Value.ExePath = $exeName
}

function UseAppXEnumerator([ref][System.Collections.Generic.Dictionary[String, object]]$packageList)
{
    if ($packageList.Value["_Initialized"])
    {
        return
    }
    Write-Host "Using fallback mechanism to collect EXE information"
    Write-Host "Calling $Script:AppXEnumerator"
    $rawList = Cmd-Device -Command $Script:AppXEnumerator -HideOutput
    if ($rawList -eq $null -Or $rawList.Output -eq $null)
    {
        Write-Warning "Unable to enumerate apps using $Script:AppXEnumerator"
        return
    }
    $rawArray = $rawList.Output.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

    $addObject = New-Object PSObject
    $addObjectReady = $false

    foreach ($result in $rawArray)
    {
        $addObjectReady =                      ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "PackageName"}) -ne $null
        $addObjectReady = $addObjectReady -And ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "AumId"}) -ne $null
        $addObjectReady = $addObjectReady -And ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "ExePath"}) -ne $null
        if ($result.StartsWith("-----------------------------"))
        {
            if ($addObjectReady)
            {
                $packageList.Value.Add($addObject.AumId, $addObject)
            }
            $addObject = New-Object PSObject
        }

        $nameValuePair = $result.Split("=")
        if ($nameValuePair -ne $null -And $nameValuePair.Count -eq 2)
        {
            $name = $nameValuePair[0]
            $value = $nameValuePair[1]

            if ($name -eq "ExePath[0]")
            {
                $name = "ExePath";
            }
            if ($name -eq "Executable[0]")
            {
                $name = "Executable";
            }
            if ($name -eq "ApplicationId[0]")
            {
                $name = "ApplicationId";
            }
            if ($name -eq "AumId[0]")
            {
                $name = "AumId";
            }
            Add-Member -InputObject $addObject -MemberType NoteProperty -Name $name -Value $value
        }
    }
    $addObjectReady =                      ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "PackageName"}) -ne $null
    $addObjectReady = $addObjectReady -And ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "AumId"}) -ne $null
    $addObjectReady = $addObjectReady -And ($addObject | Get-Member -MemberType NoteProperty | ? { $_.Name -eq "ExePath"}) -ne $null
    if ($addObjectReady)
    {
        $packageList.Value.Add($addObject.AumId, $addObject)
    }
    $packageList.Value.Add("_Initialized", $true);
}

<#
.SYNOPSIS
Adds a package name to the collection.

.DESCRIPTION
If the ServerKey is an ".mca", we build an object from its subkeys and data values,
then add this to the growing collection.

.PARAMETER packageReg
A packages root registration key.

.PARAMETER PackageRoot
The root of all the packages in the registry.

.EXAMPLE
Add-PackageToList $packageReg $packageRoot $Script:pkgList
#>

function Add-PackageToList(
    [String] $packageReg,
    [string] $packageRoot,
    [ref][System.Collections.Generic.Dictionary[String, object]]$packageList)
{
    $packageName = $packageReg.SubString($packageRoot.Length + 1)        

    $serverSubKeyArray = GetServerSubkeys $packageReg 
    if ($serverSubKeyArray -eq $null)
    {
        UseAppXEnumerator $packageList
        return
    }

    $serverSubKey = $null
    foreach ($tryServerSubKey in $serverSubKeyArray)
    {
        if ($tryServerSubKey.EndsWith(".mca") -or $tryServerSubKey.EndsWith(".wwa"))
        {
            $serverSubKey = $tryServerSubKey
            break;
        }
    }        

    if ($serverSubKey -ne $null)
    {
        $rawOutput = regd query "$serverSubKey"
        $rawArray = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
        $regEx = "\s+(?<name>\S+)\s+\S+\s+(?<value>.*)"
        
        $addObject = New-Object PSObject
        
        $rawArray | Select-String $regEx | 
        ForEach-Object {
            foreach ($match in $_.Matches)
            {
                $name = $match.Groups["name"].Value  
                $value = $match.Groups["value"].Value
                Add-Member -InputObject $addObject -MemberType NoteProperty -Name $name -Value $value
            }
        }
        
        Add-Member -InputObject $addObject -MemberType NoteProperty -Name PackageName -Value $PackageName
        
        if ($serverSubKey.EndsWith(".mca"))
        {
            Add-CorrectExePath ([ref]$addObject) $PackageName
        }
        
        try
        {
            $userModelId = $addObject.AppUserModelId
            if ($UserModelId -and (-not $packageList.Value[$userModelId]))
            {
                $packageList.Value.Add($userModelId, $addObject) 
            }
            else
            {
                if ($userModelId -and $packageList.Value[$userModelId])
                {
                    if ($addObject.PackageName -ne $packageList.Value[$userModelId].PackageName)
                    {
                        Write-Warning "Duplicate: $($addObject.AppUserModelId)"
                    }
                }
            }
        }
        catch
        {
            Write-Warning "Could not add $PackageName"
            Write-Warning $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
Builts the package collection.

.DESCRIPTION
When we debug a Modern app, we need to enable debugging for its package.
Once it is built, THE package collectoin enables a quick lookup of the 
package name by AUMID. This function builds the collection lazily as it
needs to in order to find callers AUMID.

.ARGUMENT Aumid
We'll add packages to the collection until we run out of packages or we find
this Aumid.

.EXAMPLE
$package = AddPackagesUntilMatch
#>
function AddPackagesUntilMatch(
    [String] $Aumid)
{
    $packageObject = $null
    
    while ($Script:rawPkgs.Count -gt 0)
    {        
        $packageReg = $Script:rawPkgs[0]
        $Script:rawPkgs.RemoveAt(0)
        
        Add-PackageToList $packageReg $Script:pkgRoot ([ref]$Script:pkgList)

        $packageObject = $Script:pkgList[$AumId]
        
        if ($packageObject)
        {
            break;
        }
    }
    
    return $packageObject
}

<#
.SYNOPSIS
Looks up the package object for the given AUMID

.DESCRIPTION
If we don't have a package collection built, go build it.  If it is built we
just index it using the AumId.

.PARAMETER AumId
The Application User Model ID for the application of interest.

.EXAMPLE
$pkg = GetFullPackageName "PRWP81HubApp_95k6d2vatfycm!x84fc2644yfea9y47ecy806cy4d5035f7d375x"
#>

function GetFullPackageName(
    [String]$AumId)
{
    # If we are no longer attached to the same device, our lists are now obsolete.
    if (-not $Script:InstallCheck -or $Script:InstallCheck -ne $Global:DeviceAddress)
    {
        $Script:pkgList.Clear()
        $Script:rawPkgs.Clear()
    }

    if ($Script:pkgList.Count -eq 0)
    {
        GetPackageList
    }
    
    $package = $Script:pkgList[$AumId]
    
    if (-not $package)
    {                
        $package = AddPackagesUntilMatch $AumId
    }
    
    if (-not $package)
    {                
        throw "Unable to find package for $AumId"
    }
    
    return $package
}

Export-ModuleMember -Function "VSDebug-Device"
Export-ModuleMember -Function "Detach-VisualStudioDebugger"
Export-ModuleMember -Function "Add-PackageToList"

#################################
# VSDebug-Device aliases
#################################
Set-Alias vsdebugd VSDebug-Device 
Set-Alias vsd VSDebug-Device
Export-ModuleMember -Alias *
