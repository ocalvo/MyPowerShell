param([switch]$DontRestart,[switch]$force)


$ddDir = "c:\dd\"
$ddIni = get-content ($ddDir + "dd.ini")
$logonBaseMarker = "C:\Windows\logon.base.done"
$logonMarker = "C:\Windows\logon.done"

function Set-CrashDumps
{
  param($crashFolder = 'c:\dd\CrashDumps')
  $regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
  if ( !(test-path $regKey) )
  {
      mkdir $regKey
  }
  if (!(test-path $crashFolder))
  {
    mkdir $crashFolder
  }
  set-itemproperty $regKey DumpFolder $crashFolder -type ExpandString
  set-itemproperty $regKey DumpCount 10 -type dword
  set-itemproperty $regKey DumpType 2 -type dword
}

function Execute-LogonElevated
{
  $process = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
  $a = '-noexit -executionpolicy bypass -c logon'
  if ($DontRestart.IsPresent )
  {
    $a += ' -DontRestart'
  }
  if ($force.IsPresent)
  {
    $a += ' -Force'
  }

  Execute-Elevated $process $a -Wait
}

function Execute-ForBase
{
  Write-Host "Starting devbox base setup..."
  Set-CrashDumps
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
  echo "Done" > $logonBaseMarker
  Write-Host "Devbox base setup done"
  Stop-Computer -confirm
}

function Execute-AfterBase
{
  Write-Host "Starting devbox setup..."
  Gac-PowerShell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1
  echo "Done" > $logonMarker
  if ($DontRestart.IsPresent )
  {
    return
  }
  Restart-Computer -force
}

function Execute-Logon
{
    if (!(IsAdmin))
    {
       Execute-LogonElevated
       return
    }

    if (!(test-path $logonBaseMarker))
    {
      Execute-ForBase
    }
    else
    {
      Execute-AfterBase
    }
}

function Get-NeedsToSetup
{
    if (IsDevBox)
    {
        if (!(test-path $ddDir))
        {
            throw "Dev dir not found"
        }

        if ($force.IsPresent)
        {
          return $true
        }

        return (!(test-path $logonMarker))
    }

    return $false
}

function IsDevBox
{
  ($env:computername -like "ocalvo-dev*")
}

function Execute-UserLogon
{
  if(IsDevBox)
  {
    $bgDir = $myHome + '\Tools\BgInfo\'
    Push-Location $bgDir
    .\Bginfo.exe .\Bginfo.bgi /silent /timer:0
    Pop-Location
    vsvars32
    & devenv
  }
}

if (Get-NeedsToSetup)
{
  Execute-Logon
}
else
{
  Execute-UserLogon
  Exit
}

