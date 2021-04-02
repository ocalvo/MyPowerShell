########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#

if ((get-command sudo -erroraction ignore) -eq $null)
{
  Enable-Execute-Elevated
  $env:path += ";~\scoop\apps"
}

$global:terminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

function global:Install-Chocolatey
{
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

$psTab = Get-Module PowerTab -ListAvailable
if ($null -eq $psTab)
{
  Find-Module PowerTab | Install-Module -Force
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
  ."$PSScriptRoot\Set-GitConfig.ps1"
}

if ((get-command vim -erroraction ignore) -eq $null)
{
  sudo choco install vim -y
}

if (!(test-path ~\Documents\PowerShell))
{
  sudo {
    $workOneDriveDir = "~\OneDrive - Microsoft"
    $oneDriveDir = "~\OneDrive"
    $useWorkOneDrive = (test-path $workOneDriveDir\Documents)
    if ($useWorkOneDrive)
    {
      if (test-path ~\OneDrive) { mv ~\OneDrive ~\OneDrive.bak }
      new-item ~\OneDrive -ItemType SymbolicLink -Target $workOneDriveDir
      $oneDriveDir = $workOneDriveDir
    }
    if (test-path ~\Documents) { mv ~\Documents ~\Documents.bak }
    new-item ~\Documents -ItemType SymbolicLink -Target $oneDriveDir\Documents
  }
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
function rmd ([string] $glob) { remove-item -recurse -force $glob }
function cd.. { Set-Location ..  }
function .. { Set-Location ..  }

function test-isadmin
{
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    $wp.IsInRole("Administrators") -eq 1
}
$isAdmin = (test-isadmin)
$global:myhome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]'MyDocuments')
$global:scriptFolder = $global:myhome +'\WindowsPowerShell'
$env:REMOTE_HOME = $myHome
$localHome = $env:HOMEDRIVE + $env:HOMEPATH + '\Documents'
if (!(test-path $localHome))
{
  if ($isAdmin)
  {
    New-Item $localHome -ItemType SymbolicLink -Target $myhome
  }
}
if (test-path $localHome)
{
  $myHome = $localHome
}

$vimRC = ($env:USERPROFILE + '\_vimrc')
if (!(test-path $vimRC))
{
  set-content -path $vimRC "source <sfile>:p:h\Documents\WindowsPowerShell\profile.vim"
}

set-alias bcomp               $env:ProgramFiles'\Beyond Compare 4\bcomp.com'     -scope global
set-alias razzle              Execute-Razzle                                     -scope global
set-alias vsvars              Enter-VSShell                                      -scope global
set-alias zip                 7z                                                 -scope global
set-alias ztw                 '~\OneDrive\Apps\ZtreeWin\ztw64.exe'               -scope global
set-alias sudo                Execute-Elevated                                   -scope global
set-alias go                  Goto-KnownLocation                                 -scope global

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

function FirstTime-Setup()
{
  sudo fsutil behavior set symlinkEvaluation R2R:1
  sudo fsutil behavior set symlinkEvaluation L2R:1
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

Import-Module posh-git
Import-Module oh-my-posh

#Set-PowerLinePrompt -PowerLineFont -Title { Get-MyWindowTitle }
$ThemeSettings.Options.ConsoleTitle = $false
Set-Theme MyAgnoster

$serverModules = ($PSScriptRoot+'\Scripts\Modules')
if (test-path $serverModules -ErrorAction Ignore)
{
  $env:psmodulepath+=(';'+$serverModules)
  Import-Module PersonalMedia
}

$psScripts = ($PSScriptRoot+'\Modules\scripts\PSRazzle.psm1')
if (test-path $psScripts -ErrorAction Ignore)
{
  Import-Module $psScripts
}

Import-Module DirColors

$global:wt_profile = ($env:LocalAppData+'\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json')

function global:Execute-PowerShell32
{
  c:\Windows\SysWoW64\WindowsPowerShell\v1.0\powershell.exe -nologo $args
}
set-alias ps32 Execute-PowerShell32 -scope global

function global:Open-CodeFlow
{
  param([string]$webUrl)
  #\\codeflow\public\cf.cmd help openGitHubPr
  \\codeflow\public\cf.cmd openGitHubPr -webUrl $webUrl
  #\\codeflow\public\cf.cmd openGitHubPr -account <account> -GitHubProject <project> -prId <prId>
}

function global:Setup-MyBash
{
  wsl -- wget https://raw.githubusercontent.com/ocalvo/MyBash/master/setup.sh -O /tmp/setup.sh; bash /tmp/setup.sh
}

#Import-Module PowerTab
Import-Module PSReadLine
Set-PSReadLineOption –HistoryNoDuplicates:$True
Import-Module PwrSudo
Import-Module SearchDir
Import-Module Razzle

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

