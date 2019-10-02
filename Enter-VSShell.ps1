param(
  [Parameter(Mandatory=$false)][String]$vsVersion = "Preview")

$installPath = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -prerelease -property installationpath
$vsVersions = $installPath |
  Select-Object @{Name='Version';Expression={Split-Path $_ -Leaf | Select-Object -First 1}},
    @{Name='Path';Expression={$_}}

$ver = $vsVersions | Where-Object {$_.Version -eq $vsVersion }
$devShellModule = Join-Path $ver.Path "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Import-Module $devShellModule
Enter-VsDevShell -VsInstallPath $ver.Path -SkipAutomaticLocation

$env:_MSBUILD_VERBOSITY = "m"
$env:_VSINSTALLDIR = Split-path ((Split-Path ((get-command msbuild).Definition) -Parent)+"\..\..\") -Resolve

function global:msb()
{
  msbuild /bl /nologo /v:$env:_MSBUILD_VERBOSITY $args
}

function global:build()
{
  msb /target:Build
}

function global:buildclean()
{
  msb /target:ReBuild
}

set-alias b build -scope global

