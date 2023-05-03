########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#

function global:Test-IsUnix
{
  return (($PSVersionTable.PSEdition -eq 'Core') -and ($PSVersionTable.Platform -eq 'Unix'))
}

function global:test-isadmin
{
  $isUnix = Test-IsUnix
  if ($isUnix) {
    return ((id -u) -eq 0)
  } else {
    if ("ConstrainedLanguage" -eq $ExecutionContext.SessionState.LanguageMode) {
       return $false
    }
    try {
      $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
      $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
      return $wp.IsInRole("Administrators") -eq 1
    } catch {
      return $false
    }
  }
}

if (!(Test-IsUnix)) {
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

$env:BUILD_TASKBAR_FLASH=1

function rmd ([string] $glob) { remove-item -recurse -force $glob }
function cd.. { Set-Location ..  }
function .. { Set-Location ..  }

$isAdmin = (test-isadmin)
[string]$global:myhome = '~/Documents'
[string]$global:scriptFolder = $global:myhome +'/'
if ($PSEdition -eq "Desktop") { $global:scriptFolder += 'Windows' }
$global:scriptFolder += 'PowerShell'
$myHome = (get-item ~/.).FullName
$vimRC = ($myHome + '/_vimrc')
if (!(test-path $vimRC))
{
  set-content -path $vimRC "source <sfile>:p:h/Documents/PowerShell/profile.vim"
}

set-alias bcomp               $env:ProgramFiles'/Beyond Compare 4/bcomp.com'     -scope global
set-alias vsvars              Enter-VSShell                                      -scope global
set-alias zip                 7z                                                 -scope global
set-alias ztw                 '~/OneDrive/Apps/ZtreeWin/ztw64.exe'               -scope global
set-alias speak               "$PSScriptRoot\Speak.ps1"

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
    else
    {
      $repoName = git config --get remote.origin.url | Split-Path -Leaf | select -first 1
      if ($null -ne $repoName)
      {
        $title = "git $repoName " + (Get-WindowTitleSuffix)
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

if ("ConstrainedLanguage" -ne $ExecutionContext.SessionState.LanguageMode) {
  Import-Module posh-git
  Import-Module oh-my-posh

  $ThemeSettings.Options.ConsoleTitle = $false
  Set-Theme MyAgnoster

}

#Set-PowerLinePrompt -PowerLineFont -Title { Get-MyWindowTitle }

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
Import-Module Terminal-Icons

if (!(Test-IsUnix))
{
  # Chocolatey profile
  $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
  }
}
