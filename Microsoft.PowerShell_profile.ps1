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

if (-Not (Test-Path env:TEMP) -And (Test-Path env:TMPDIR)) {
    $env:TEMP = $env:TMPDIR
    $env:TMP = $env:TMPDIR
}

$env:AppxSymbolPackageEnabled='false'
$env:MSBUILDLOGALLENVIRONMENTVARIABLES=1

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
set-alias test-nsfw                  "$PSScriptRoot\Test-NSFW.ps1"                      -scope global
set-alias Get-NSFWProperties         "$PSScriptRoot\Get-NSFWProperties.ps1"             -scope global

#."$PSScriptRoot\Set-GitConfig.ps1"

# SD settings
$vimCmd = get-command vim -ErrorAction Ignore
$codeCmd = get-command code -ErrorAction Ignore
if ($null -eq $vimCmd)
{
   $vimExe = dir "C:\Program Files\Vim\vim*\vim.exe" -ErrorAction Ignore | select -first 1
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

$separator = ";"
if (Test-IsUnix) { $separator = ":" }

$_profileModulesPath = $PSScriptRoot+"/Modules"
if (!$env:PSModulePath.Contains($_profileModulesPath))
{
  $newModPath = $separator+$_profileModulesPath
  Write-Verbose "Adding new module path:$newModPath"
  $env:PSModulePath += $newModPath
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
  $poshTheme = "markbull.omp.custom.yaml"
  oh-my-posh init pwsh --config "$PSScriptRoot\PoshThemes\$poshTheme" | Invoke-Expression
}

$serverModules = ($PSScriptRoot+'/../PSModules/Modules')
Write-Verbose "Probing module path:$serverModules"
if (test-path $serverModules -ErrorAction Ignore)
{
  $_fd = (get-item $serverModules).FullName
  $env:PSModulePath+=($separator+$_fd)
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


