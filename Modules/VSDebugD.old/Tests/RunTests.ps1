#Copyright (c) Microsoft Corporation.  All rights reserved.

<#
.SYNOPSIS
VSDebugD tests.  These tests are not very isolated but do run VSDebugD through its
basic functions with a series of negative and positve tests.

The tests require a certain amount of hand-holding and expect TShell to be connected
to the device at the beginning of the tests.  If the connection is lost during the
tests, this script attempts to reestablish it.

.DESCRIPTION
Tests for VSDebugD

.PARAMETER Tests
There are several varieties of tests identified with a string of test IDs in quotes.
The possibilities are:
    LaunchByName
    ModernApps
    Silverlight
    Native
    Managed
    Negative

.PARAMETER TestsCount
Sets the number of tests for TestModernApps and TestSilverlIghtApps.

.PARAMETER vs2012
-VS2012 will cause VS to be tested. 
#>
Param(  
    [string] $Tests,
    [int] $TestCount = 5,
    [switch] $VS2012) 

# VS2012 selection is global to the script;
$Script:VS2012Option = ""

# Save device address here
$Script:SaveAddress = 0

# An array of AppIds to test.
$Script:AppIds = @()

# An array of AppIds to test.
$Script:AumIds = @()

# An array of AppTitles to test.
$Script:AppTitles = @()

# Path to th.exe 
$Script:ThPath = "C:\Data\Test\bin\th.exe"

# The installed packages are enumerated at this registry location.
$Script:pkgRoot = "HKEY_USERS\S-1-5-21-2702878673-795188819-444038987-2781\Software\Classes\ActivatableClasses\Package"

# We generate a list of the installed packages to associate the AUMID and ExePath
$Script:packageList = New-Object 'System.Collections.Generic.Dictionary[String, object]'

# These packages haven't been processed to determine the AUMID and ExePath
[string[]]$Script:skipTheseAumids =
(
    "IETileManager_1ag6x397eqev0!IETileManager.AppId"
)

# These hosts are native mode.
[string[]]$Script:skipTheseHosts =
(
    "aghost.exe",
    "wwahost.exe"
)

<#
.SYNOPSIS
 Test if VS 2012 is Installed

.DESCRIPTION
Looks for devenv at "Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\"
returning $true if its present and $false if not.

.EXAMPLE
Test-VS2012Installed
Returns $true if VS 2012 is installed.
#>
function Test-VS2012Installed
{
    $systemRoot = $env:SystemDrive + [System.IO.Path]::DirectorySeparatorChar
    $VsPath = [System.IO.Path]::Combine($systemRoot, "Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe")
    return Test-Path $VsPath
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
    [string] $TargetPath)
{
    try
    {
        dird /B $TargetPath | Out-Null
        return $True
     }
     catch
     {
        return $False
     }
}

<#
.SYNOPSIS
Ensures we have a device connection

.DESCRIPTION
If we dont have a connect (per Test-Path Variable:DeviceAddress), we try to reestablish it.
#>
function Ensure-Connection
{
    $connected = Test-Path Variable:DeviceAddress
    if($connected -eq $false)
    {
        Write-Warning "Re-establishing a connection to $Script:SaveAddress"
        Open-Device $Script:SaveAddress
    }
}

<#
.SYNOPSIS
Warn if connection was lost.

.DESCRIPTION
If Test-Path Variable:DeviceAddress returns $false, write a warning to the console.
#>
function Warn-Connection
{
    $connected = Test-Path Variable:DeviceAddress
    if($connected -eq $false)
    {
        Write-Warning "Connection lost after test."
    }
}

<#
.SYNOPSIS
Prompt the user with a message and quit if needed.

.DESCRIPTION
Call Read-Host with callers prompt.  If the user depresses Enter, just return,
but if the user enters anything starting with a "q", bail out.  This just 
gives the user a chance to bail out, if needed.

.PARAMETER Prompt
The message to display

.EXAMPLE
Prompt-User "Depress enter to continue testing."
#>
function Prompt-User(
    [string] $Prompt)
{
    $result = Read-Host $Prompt
    if ($result.ToLower().StartsWith("q"))
    {
        exit
    }
    return
}

<#
.SYNOPSIS
Perform a VSD test, possibly adding the -VS2012 option

.DESCRIPTION
if $vs2012 is set, add the appropirate option to the test and run it.

.PARAMETER Test
A Scriptblock containing the test to be run.

.EXAMPLE
RunVsTest $Test
#>
function RunVsdTest(
    [ScriptBlock]$Test)
{
   if ($VS2012)
   {
    	$revisedTest = $ExecutionContext.InvokeCommand.NewScriptBlock("$($Test.ToString()) -vs2012")
    	&$revisedTest    		
    }
    else
    {
    	&$Test
    }
    
 }

<#
.SYNOPSIS
Verify that th.exe is on the phone.

.DESCRIPTION
If th.exe is on the phone, just return.  If not, warn the user and give some
options, one of which is to exit.  

.EXAMPLE
VeriftyThExeDeployed
#>
function VeriftyThExeDeployed
{
    $exists = DoesTargetPathExist $Script:ThPath
    if (-not $exists)
    {
        Write-Warning "$Script:ThPath is needed for this test, but is not deployed."
        $result = Read-Host "Enter 'q' to quit or 'd' to attempt to deploy $Script:ThPath"
        if ($result.ToLower().StartsWith("q"))
        {
            exit
        }
        if ($result.ToLower().StartsWith("d"))
        {
            try
            {
                Deploy-Binary [System.IO.Path]::GetFileName($Script:ThPath)
            }
            catch
            {
                Write-Error "Deploy-Binary failed. $($_.Exception.Message)"
            }
        }
    }
    return
}

<#
.SYNOPSIS
 Tests Modern apps

.DESCRIPTION
Iterates through the $Script:AumIds table trying VSDebugD on each one.

.EXAMPLE
TestModernApps
#>
function TestModernApps
{
    LoadValidAumIds

    foreach ($aumId in $Script:AumIds)
    {
        DoAumidPositiveTest $aumId
    }
}

<#
.SYNOPSIS
 Tests the Launch by Name feature

.DESCRIPTION
Iterates through the $Script:AppTiless table trying VSDebugD on each Title.

.EXAMPLE
TestLaunchByName
#>
function TestLaunchByName
{
    VeriftyThExeDeployed

    LoadValidAppTitles

    $Prompt = "Depress enter after closing any VS dialogs[q=quit]"

    foreach ($appTitle in $Script:AppTitles)
    {
        DoPositiveTest -Test {&VSDebugD -AppName $appTitle} -PostTest $Prompt
    }
}

<#
.SYNOPSIS
 Tests Silverlight apps

.DESCRIPTION
Iterates through the $Script:AppIds table trying VSDebugD on each AppId.

.EXAMPLE
TestSilverlIghtApps
#>
function TestSilverlIghtApps
{
    VeriftyThExeDeployed

    LoadValidAppIds

    $Prompt = "Depress enter after closing any VS dialogs[q=quit]"
    #Do one test for legacy user of -FileName with the AppID
    DoPositiveTest -Test {&VSDebugD -FileName $Script:AppIds[0] -type Silverlight } -PostTest $Prompt

    foreach ($appId in $Script:AppIds)
    {
        DoPositiveTest -Test {&VSDebugD -AppId $appId} -PostTest $Prompt
    }
}

<#
.SYNOPSIS
 Tests native apps

.DESCRIPTION
Tests DebugVS on native apps

.EXAMPLE
TestNativeApps
#>
function TestNativeApps
{
    DoPositiveTest -Test {&VSDebugD -pn MobileUI.exe -type native }
    DoPositiveTest -Test {&VSDebugD -psn DnsCache -type native }
    DoPositiveTest -Test {&VSDebugD -psn DnsCache -type native -symbols http://symweb }
    DoPositiveTest -Test {&VSDebugD -fileName C:\windows\System32\PING.EXE -type native } -PostTest  "Depress enter after closing the dialog on Visual Studio"
}

<#
.SYNOPSIS
 Tests managed apps

.DESCRIPTION
Tests DebugVS on managed apps

.EXAMPLE
TestManagedApps
#>
function TestManagedApps
{
    # Tuxnet isn't always on the device.
    if (DoesTargetPathExist "C:\Test\Tuxnet.exe")
    {
	    DoPositiveTest -Test {&VSDebugD -fileName C:\Test\Tuxnet.exe -type managed }
    }

    # Waitforreports.exe isn't always on the device.
    if (DoesTargetPathExist "C:\Data\Test\bin\waitforpendingreports.exe")
    {
	    DoPositiveTest -Test {&VSDebugD -fileName C:\Data\Test\bin\waitforpendingreports.exe  -type managed }
    }
}

<#
.SYNOPSIS
 Runs all the negative tests

.DESCRIPTION
Calls DebugVs for each negative test.

.EXAMPLE
RunNegativeTests
#>
function RunNegativeTests
{
    DoNegativeTest -Test {&VSDebugD -pn 1} -Filter "Could not determine process ID from the process name 1"
    DoNegativeTest -Test {&VSDebugD -psn 1} -Filter "Could not determine process ID from the service name 1"
    DoNegativeTest -Test {&VSDebugD -pn MobileUI.exe -processID 1} -Filter $ProcessError
    DoNegativeTest -Test {&VSDebugD -psn DnsCache -processID 1} -Filter $ProcessError
    DoNegativeTest -Test {&VSDebugD -pn MobileUI.exe -psn DnsCache} -Filter $ProcessError
    DoNegativeTest -Test {&VSDebugD -pn MobileUI.exe -psn DnsCache -processID 1} -Filter $ProcessError
    DoNegativeTest -Test {&VSDebugD}  -Filter $ProcessError
    DoNegativeTest -Test {&VSDebugD -fileName 1 -type "silverlight"}  -Filter "To start a Silverlight App, you must provide an -AppId parameter."
    DoNegativeTest -Test {&VSDebugD -processID -1} -Filter "processId must be greater than 0"
    DoNegativeTest -Test {&VSDebugD -processID fred} -Filter "processId doesn't appear to be a number"
}

<#
.SYNOPSIS
 Loads all valid AumIDs for future use.

.DESCRIPTION
Tries to load all the valid AumIDs on the device

.EXAMPLE
LoadValidAumIds
If possible loads valid AumIDs from the device.
#>
function LoadValidAumids
{
    [System.Boolean]$ignoreCase = $true;
    [System.Globalization.CultureInfo]$cultureInfo = "en"
    $rawOutput = regd query $Script:pkgRoot
    $packageList = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) 

    $rawOutput = regd query $Script:pkgRoot
    $RawArray = $rawOutput.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) 
    
    foreach ($packageReg in $RawArray)
    {
        Add-PackageToList $packageReg $Script:pkgRoot ([ref]$Script:packageList)        
    }

    foreach ($packageIter in $Script:packageList.GetEnumerator())
    {
        $package = $packageIter.Value

        if ($package.AppUserModelID)
        {
            $appUserModelID = $package.AppUserModelID
            $exeName =  [System.IO.Path]::GetFileName($package.ExePath).ToLower()

            if ($Script:skipTheseAumids.Contains($appUserModelID))
            {
                Write-Host "Skipping $appUserModelID since it is on the 'skip' list"
            }
            elseif ($appUserModelID.EndsWith("!"))
            {
                Write-Host "Skipping $appUserModelID since it is a dependency"
            }
            else
            {
   			    Write-Host "Adding $appUserModelID"
	            $Script:AumIds += $package
            }

            if($Script:AumIds.Count -ge $TestCount)
            {
                break;
            }
        }
    }
}

<#
.SYNOPSIS
 Loads all valid App IDs for future use.

.DESCRIPTION
Tries to load all the valid App IDs on the device

.EXAMPLE
LoadValidAppIds
If possible loads valid App IDs from the device.
#>
function LoadValidAppIds
{
    try
    {
        Write-Host "Loading valid App IDs from the device."

        $result = Exec-Device -FileName $Script:ThPath -HideOutput
        
        if (-not $result.Output -or $result.ExitCode -ne 0)
        {
            throw "Got an error from th.exe error code is $($result.ExitCode)"
        }

        $AppIdRegExArg = "^\s+\[[0-9]+\].+InvocationInfo\s:\s(?<appid>app\://[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}.*$)"
        [System.Text.RegularExpressions.Regex]$AppIdRegEx = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $AppIdRegExArg

        $output = $result.Output.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($line in $output)
        {
            [System.Text.RegularExpressions.Match]$appIdMatch = $AppIdRegEx.Match($line)
            if ($appIdMatch.Success)
            {                
                $oneAppId = $appIdMatch.Groups["appid"].Value
                Write-Host "Adding $oneAppId"
                $Script:AppIds += @($oneAppId)
                if($Script:AppIds.Count -ge $TestCount)
                {
                    break;
                }
            }
        }
    }
    catch
    {
        Write-Warning "Not able to load App ID, so using defaults."        
    }

}

<#
.SYNOPSIS
 Loads all valid App Titles for future use using th.exe.

.DESCRIPTION
Tries to load all the valid App Titles on the device

.EXAMPLE
LoadValidAppTitles
If possible loads valid App Titles from the device.
#>
function LoadValidAppTitles
{
    try
    {
        Write-Host "Loading valid App Titles from the device."

        $result = Exec-Device -FileName $Script:ThPath -HideOutput
        
        if (-not $result.Output -or $result.ExitCode -ne 0)
        {
            throw "Got an error from th.exe error code is $($result.ExitCode)"
        }

        $appTitleRegExArg = "^\s+\[[0-9]+\].+AppTitle\s:\s(?<apptitle>.*$)"
        [System.Text.RegularExpressions.Regex]$appTitleRegEx = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $appTitleRegExArg

        $output = $result.Output.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($line in $output)
        {
            [System.Text.RegularExpressions.Match]$appIdMatch = $appTitleRegEx.Match($line)
            if ($appIdMatch.Success)
            {                
                $oneAppTitle = $appIdMatch.Groups["apptitle"].Value
                Write-Host "Adding $oneAppTitle"
                $Script:AppTitles += @($oneAppTitle)
                if($Script:AppTitles.Count -ge $TestCount)
                {
                    break;
                }
            }
        }
    }
    catch
    {
        Write-Warning "Not able to load AppTiles."        
    }

}


<#
.SYNOPSIS
Perform a positive test

.DESCRIPTION
Call the $Test and complain on a failure.

.PARAMETER Test
A Scriptblock containing the test to be run.

.PARAMETER PostTest
If specified, prompt the user after the test and wait for a response

.PARAMETER PreTest
If specified, prompt the user before the test and wait for a response


.EXAMPLE
DoPositiveTest -Test {&VSDebugD -fileName C:\windows\System32\PING.EXE -type native
Will ensure we have a valid connection, run the test, report any errors, detach
the debugger and check the device connection.
#>
function DoPositiveTest(
    [ScriptBlock]$Test,
    [string]$PostTest,
    [string]$PreTest )
{
    Write-Host "`n`n`nPerforming postive test: $Test`n"
    if($PreTest)
    {
        Prompt-User $PreTest
    }

    try
    {
        Ensure-Connection       
       	RunVsdTest $Test
    }
    catch [Exception]
    {
        Write-Error "Postive test failed: $Test"
    }

    if($PostTest)
    {
        Prompt-User $PostTest
    }
    else
    {
        [TimeSpan]$errorRetryDelaySeconds = New-Object System.TimeSpan(0, 0, 2)
        [System.Threading.Thread]::Sleep($ErrorRetryDelaySeconds)
    }

    Detach-VisualStudioDebugger
    Warn-Connection
}

<#
.SYNOPSIS
Perform a negative test

.DESCRIPTION
Call the $Test and complain on a success.

.PARAMETER Filter
Contains text that should be contained in the tests response.  If the text is missing, we have a
failed test.

.PARAMETER Test
A  script block containing the test to be run.

.EXAMPLE
DoNegativeTest -Test {&VSDebugD -pn 1} -Filter "Could not determine process ID from the process name 1"
Will ensure we have a valid connection, run the test, check the output for the right error message,
report any errors, detach the debugger and check the device connection.
#>
function DoNegativeTest(
    [string]$Filter, 
    [Scriptblock]$Test)
{
    Write-Host "Performing negative test: $Test"
    try
    {
        Ensure-Connection
        $success = $false
        $Error.Clear()
        $discard = RunVsdTest $Test  2>&1
        if($Error.Count -gt 0)
        {
            $output = $Error[0].ToString()
            $success = $outPut.Contains($Filter)
        }
    }
    catch [Exception]
    {
        if($_.ToString().Contains("Input string was not in a correct format"))
        {
            $success = $true
        }
        else
        {
            $success = $false
            Write-Warning "$_"
        }
    }

    if($success -eq $true)
    {
        Write-Host "Negative test succeeded: $Test"
    }
    else
    {
        Write-Error "Negative test failed: $Test"
    }
    Warn-Connection
}

<#
.SYNOPSIS
Perform a positive test for caller's Aumid

.DESCRIPTION
Performs the test and attempts to kill of the resultant EXE in order to keep the machine clean.

.PARAMETER Aumid
The Application User Model ID.

.EXAMPLE
DoAumidPositiveTest $Aumid
Will perform a positive test on callers $Aumid
#>

function DoAumidPositiveTest(
    [PSObject] $AppObject)
{
    Write-Host "`n`n`nPerforming postive test: $Test`n"

    $aumid = $AppObject.AppUserModelID
    $exeName =  [System.IO.Path]::GetFileName($AppObject.ExePath)

    try
    {
        Ensure-Connection
        RunVsdTest {VSDebugD -aumid $aumid}
    }

    catch [Exception]
    {
        Write-Error "Postive test failed: VSDebug -aumid $Test"
    }

    $result = Read-Host "Press enter to continue after closing an VS dialogs, q to quit. Err to record an error"
    if ($result.ToLower().StartsWith("q"))
    {
        exit
    }
    elseif ($result.ToLower().StartsWith("e"))
    {
        Write-Warning "$result $exeName $aumid"
    }

    Detach-VisualStudioDebugger
    Warn-Connection

    Cmd-Device -Command "kill.exe" -Arguments $exeName
}

<#
.SYNOPSIS
Make sure that we have a connection for our tests.

.DESCRIPTION
Calls Test-Path Variable:DeviceAddress.  On a $false return, we output an error message
and exit.

.EXAMPLE
ValidateConnection
Will write an error message and throw if we don't have a device connection.
#>
function ValidateConnection
{
    $connected = Test-Path Variable:DeviceAddress
    if($connected -eq $false)
    {
        Write-Error "Device connection required"
        exit
    }
    $Script:SaveAddress = $DeviceAddress
}

ValidateConnection

if (-not $Tests)
{
    $result = Read-Host "You didn't select any tests. Do you want to run all of them?"

    if ($result.ToLower().StartsWith("n"))
    {
        exit
    }

    TestLaunchByName
    RunNegativeTests
    TestModernApps
    TestSilverlIghtApps
    TestNativeApps        
    TestManagedApps
}
else
{
    foreach ($Test in $Tests)
    {
        if ($Test -ieq "LaunchByName")
        {
            TestLaunchByName
        }
        elseif ($Test -ieq "ModernApps")
        {
            TestModernApps
        }
        elseif ($Test -ieq "Silverlight")
        {
            TestSilverlIghtApps
        }
        elseif ($Test -ieq "Native")
        {
            TestNativeApps
        }
        elseif ($Test -ieq "Managed")
        {
            TestManagedApps
        }
        elseif ($Test -ieq "Negative")
        {
            RunNegativeTests
        }
    }
}
