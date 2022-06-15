########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#

function global:Test-IsUnix
{
  return (($PSVersionTable.PSEdition -eq 'Core') -and ($PSVersionTable.Platform -eq 'Unix'))
}

if (!(Test-IsUnix)) {

  if ((get-command sudo -erroraction ignore) -eq $null)
  {
    Enable-Execute-Elevated
    $env:path += ";~\scoop\apps"
  }

  $global:terminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

  function global:Install-Chocolatey
  {
    if (Test-IsUnix) { return; }
    sudo {
      Invoke-Expression ((new-object net.webclient).DownloadString(' https://chocolatey.org/install.ps1'));
      $env:path += ";C:\ProgramData\chocolatey\bin"
      choco feature enable -n allowGlobalConfirmation
      choco install cascadiafonts
      choco install pwsh --pre
      cp $PSScriptRoot\WinTerminal\settings.json $terminalSettings
    }
    $env:path += ";C:\ProgramData\chocolatey\bin"
  }

  function global:Install-Scoop
  {
    iwr -useb get.scoop.sh | iex
  }

  $pythonPath = "C:\Python310"
  if (test-path $pythonPath)
  {
    $env:path =  $pythonPath + ";" + $env:path
  }

  $symbolsPath = "c:\dd\symbols"
  if (test-path $symbolsPath)
  {
    $env:_NT_SYMBOL_PATH=('SRV*'+$symbolsPath+'*http://symweb')
  }

  $env:ChocolateyToolsLocation = "C:\ProgramData\chocolatey\tools\"

  if ((get-command choco -erroraction ignore) -eq $null)
  {
    Install-Chocolatey
  }

  if ((get-command git -erroraction ignore) -eq $null)
  {
    sudo choco install git -y
    $env:path += ";C:\Program Files\Git\cmd"
  }

  if ((get-command vim -erroraction ignore) -eq $null)
  {
    sudo choco install vim -y
  }

  ########################################################
  # Helper Functions
  function ff ([string] $glob) { get-childitem -recurse -filter $glob }
  function Sleep-Computer { RunDll.exe PowrProf.dll,SetSuspendState }
  function global:Lock-WorkStation {
    $signature = "[DllImport(`"user32.dll`", SetLastError = true)] public static extern bool LockWorkStation();"

    $LockWorkStation = Add-Type -memberDefinition $signature -name "Win32LockWorkStation" -namespace Win32Functions -passthru
    $LockWorkStation::LockWorkStation() | Out-Null
  }
} else {
  if (Test-Path /etc/lsb-release) {
    $distroInfo = (Get-Content /etc/lsb-release | where {$_.StartsWith("DISTRIB_ID")} )
    if ($null -ne $distroInfo -and $distroInfo.Contains('=')) {
      $distroName = $distroInfo.Split('=')[1]
      $Host.UI.RawUI.WindowTitle = $distroName
    }
  }
}

$isWorkMode = ($env:USER -eq "ocalvo")
if ($isWorkMode)
{
  $workOneDriveDir = "~/OneDrive - Microsoft"
  $oneDriveDir = (get-item "~/OneDrive").FullName
  if (!(Test-path ($oneDriveDir+"\Documents")))
  {
    $workOneDriveDir = (get-item $workOneDriveDir).FullName
    new-item ~/OneDrive -ItemType SymbolicLink -Target $workOneDriveDir -force
    $oneDriveDir = $workOneDriveDir
  }
}

#if (!(test-path ~/Documents/PowerShell))
#{
#  $workOneDriveDir = "~/OneDrive - Microsoft"
#  $oneDriveDir = (get-item "~/OneDrive").FullName
#  $useWorkOneDrive = (test-path $workOneDriveDir\Documents)
#  if ($useWorkOneDrive)
#  {
#    $workOneDriveDir = (get-item $workOneDriveDir).FullName
#    new-item ~/OneDrive -ItemType SymbolicLink -Target $workOneDriveDir -force
#    $oneDriveDir = $workOneDriveDir
#  }
#  new-item ~/Documents -ItemType SymbolicLink -Target $oneDriveDir/Documents -force
#}

function rmd ([string] $glob) { remove-item -recurse -force $glob }
function cd.. { Set-Location ..  }
function .. { Set-Location ..  }

function test-isadmin
{
  $isUnix = Test-IsUnix
  if ($isUnix) {
    return ((id -u) -eq 0)
  } else {
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    return $wp.IsInRole("Administrators") -eq 1
  }
}

$isAdmin = (test-isadmin)
[string]$global:myhome = '~/Documents'
[string]$global:scriptFolder = $global:myhome +'/'
if ($PSEdition -eq "Desktop") { $global:scriptFolder += 'Windows' }
$global:scriptFolder += 'PowerShell'
$myHome = (get-item ~/.).FullName
$vimRC = ($myHome + '/_vimrc')
if (!(test-path $vimRC))
{
  set-content -path $vimRC "source <sfile>:p:h/OneDrive/Documents/PowerShell/profile.vim"
}

set-alias bcomp               $env:ProgramFiles'/Beyond Compare 4/bcomp.com'     -scope global
set-alias vsvars              Enter-VSShell                                      -scope global
set-alias zip                 7z                                                 -scope global
set-alias ztw                 '~/OneDrive/Apps/ZtreeWin/ztw64.exe'               -scope global

."$PSScriptRoot\Set-GitConfig.ps1"

# SD settings
$vimCmd = get-command vim 2> $null
$codeCmd = get-command code 2> $null
if (($null -ne $codeCmd) -and ($env:TERM_PROGRAM -eq "vscode"))
{
  $env:SDEDITOR=$codeCmd.definition
  $env:SDUEDITOR=$codeCmd.definition
}
elseif ($null -ne $vimCmd)
{
  $env:SDEDITOR=$vimCmd.definition
  $env:SDUEDITOR=$vimCmd.definition
}

function global:Edit()
{
  .$env:SDEDITOR $args
}

function global:_up ([int] $count = 1)
{
    push-location -path .
    1..$count | % { set-location .. }
}

set-alias e edit -scope global
set-alias up _up -scope global

function Compress-Path($Path, $Length=20)
{
  if (Test-IsUnix)
  {
    return $Path
  }
  else
  {
    $newType = @'
[DllImport("shlwapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern bool PathCompactPathEx(System.Text.StringBuilder pszOut, string pszSrc, Int32 cchMax, Int32 dwFlags);
'@
    try { Add-Type -MemberDefinition $newType -name StringFunctions -namespace Win32 } catch {}
    $sb = New-Object System.Text.StringBuilder(260)
    if ([Win32.StringFunctions]::PathCompactPathEx($sb , $Path , $Length+1, 0))
    {
        $sb.ToString()
    }
    else
    {
        Throw "Unable to compact path"
    }
  }
}

function global:Get-BranchName { "" }

$global:initialTitle = $Host.UI.RawUI.WindowTitle

function global:Get-MyWindowTitle
{
    $srcId = $null
    if ($env:_xroot -ne $null)
    {
        $srcId = $env:_xroot.Replace("\src","").ToCharArray() | select-object -last 1
    }

    if (test-path env:_BuildArch)
    {
      $currentPath = (get-item ((pwd).path) -ErrorAction Ignore)
      if ($null -ne $currentPath)
      {
        $repoRoot = (get-item $env:_XROOT).FullName
        if ($currentPath.FullName.StartsWith($repoRoot))
        {
          $razzleTitle = "Razzle: "+ $srcId + " " + $env:_BuildArch + "/" + $env:_BuildType + " "
          $title = $razzleTitle + (Get-WindowTitleSuffix)
        }
      }
    }

    if ( $isadmin )
    {
        if ( $title -ne $null )
        {
          $title += " (Admin)"
        }
    }

    if ($null -eq $title)
    {
      return $initialTitle
    }

    return $title
}

$_profilePath = (get-item $profile).Directory.FullName
$_profileModulesPath = $_profilePath+"/Modules"
if (!$env:PSModulePath.Contains($_profileModulesPath))
{
  $separator = ";"
  if (Test-IsUnix) { $separator = ":" }
  $env:PSModulePath += $separator+$_profileModulesPath
}

Import-Module posh-git
Import-Module oh-my-posh

#Set-PowerLinePrompt -PowerLineFont -Title { Get-MyWindowTitle }
$ThemeSettings.Options.ConsoleTitle = $false
Set-Theme MyAgnoster

$serverModules = ($PSScriptRoot+'/../PSModules/Modules')
if (test-path $serverModules -ErrorAction Ignore)
{
  $_fd = (get-item $serverModules).FullName
  $env:psmodulepath+=(';'+$_fd)
  get-content ($_fd+"/../.preload") -ErrorAction Ignore |% { Import-Module $_ }
}

Import-Module DirColors

$global:wt_profile = ($env:LocalAppData+'\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json')

function global:Execute-PowerShell32
{
  c:\Windows\SysWoW64\WindowsPowerShell\v1.0\powershell.exe -nologo $args
}
set-alias ps32 Execute-PowerShell32 -scope global

function global:Setup-MyBash
{
  wsl -- wget https://raw.githubusercontent.com/ocalvo/MyBash/master/setup.sh -O /tmp/setup.sh; bash /tmp/setup.sh
}

#Import-Module PowerTab
Import-Module PSReadLine -RequiredVersion 2.1.0
Set-PSReadLineOption –HistoryNoDuplicates:$True
Set-PSReadLineOption -PredictionSource History
Import-Module PwrSudo
Import-Module PwrSearch
Import-Module PwrRazzle

if (!(Test-IsUnix))
{
  # Chocolatey profile
  $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
  }
}
