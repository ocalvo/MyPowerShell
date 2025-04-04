########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#

[CmdLetBinding()]
param()

$global:lastInvocation = $MyInvocation

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

$env:BUILD_TASKBAR_FLASH=1
$env:BUILD_DASHBOARD=1
$env:BUILD_LESS_OUTPUT=1
$env:BUILD_PIP_OUTPUT_FREQUENCY = 100
$env:MSBUILD_VERBOSITY='binlog'

$myHome = (get-item ~/.).FullName
$vimRC = ($myHome + '/_vimrc')
if (!(test-path $vimRC))
{
  $_PsScriptRoot = $PSScriptRoot.Replace("\","/")
  set-content -path $vimRC "source $_PsScriptRoot/profile.vim"
}

set-alias bcomp                      $env:ProgramFiles'/Beyond Compare 5/bcomp.com'     -scope global
set-alias ztw                        '~/OneDrive/Apps/ZtreeWin/ztw64.exe'               -scope global
set-alias speak                      "$PSScriptRoot\Speak.ps1"                          -scope global
set-alias Parse-GitCommit            "$PSScriptRoot\Parse-GitCommit.ps1"                -scope global
set-alias Get-GitCommit              "$PSScriptRoot\Get-GitCommit.ps1"                  -scope global
set-alias Set-PrivateKeyPermissions  "$PSScriptRoot\Set-PrivateKeyPermissions.ps1"      -scope global

#."$PSScriptRoot\Set-GitConfig.ps1"

# SD settings
$vimCmd = get-command vim -ErrorAction Ignore
$codeCmd = get-command code -ErrorAction Ignore
if ($null -eq $vimCmd)
{
   $vimExe = dir "C:\Program Files\Vim\vim*\vim.exe" | select -first 1
   $vimPath = $vimExe.Directory.FullName
   $env:path += ";$vimPath"
   $vimCmd = get-command vim -ErrorAction Ignore
}

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

$_profileModulesPath = $PSScriptRoot+"/Modules"
if (!$env:PSModulePath.Contains($_profileModulesPath))
{
  $separator = ";"
  if (Test-IsUnix) { $separator = ":" }
  $env:PSModulePath += $separator+$_profileModulesPath
}

[Console]::OutputEncoding = [Text.Encoding]::UTF8

if ($null -eq (get-command oh-my-posh -ErrorAction Ignore)) {
  if (Test-IsUnix) {
    $poshDir = "~/bin"
    if ($notInPath) { $env:PATH += ":$poshDir" }
  } else {
    $poshDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
    if ($notInPath) { $env:PATH += ";$poshDir" }
  }
}
if ($null -ne (get-command oh-my-posh -ErrorAction Ignore)) {
  # $poshTheme = "Jandedobbeleer.omp.json"
  $poshTheme = "markbull.omp.custom.yaml"
  oh-my-posh init pwsh --config "$PSScriptRoot\PoshThemes\$poshTheme" | Invoke-Expression
} else {
  # Fallback to old PowerShell Module
}

$serverModules = ($PSScriptRoot+'/../PSModules/Modules')
if (test-path $serverModules -ErrorAction Ignore)
{
  $_fd = (get-item $serverModules).FullName
  $env:psmodulepath+=(';'+$_fd)
  get-content ($_fd+"/../.preload") -ErrorAction Ignore |% { Import-Module $_ }
}

function global:vpack {
  $vPackPath = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Engineering\VPack" "InstallPath" -ErrorAction Ignore
  if ($null -ne $vPackPath) {
    $vPackPath = $vPackPath.InstallPath
    ."$vPackPath\vpack.exe" @args
  } else {
    Write-Error "VPack not found in 'HKCU:\Software\Microsoft\Engineering\VPack'"
  }
}

Import-Module DirColors

#Import-Module PowerTab
Import-Module PSReadLine
Set-PSReadLineOption –HistoryNoDuplicates:$True
Set-PSReadLineOption -PredictionSource History
Import-Module PwrSudo
Import-Module PwrSearch
Import-Module PwrDev
Import-Module PwrRazzle

Import-Module Terminal-Icons
#if ($null -eq $global:glyphs) {
#  $glPath = Split-path (get-module Terminal-Icons).Path
#  $global:glyphs = Invoke-Expression "& '$glPath/Data/glyphs.ps1'"
#}

if (!(Test-IsUnix))
{
  # Chocolatey profile
  $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
  }
}


