param(
  [Parameter(Mandatory=$false)][String]$vsVersion = "Preview")

$installPath = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -prerelease -property installationpath
$vsVersions = $installPath |
  Select-Object @{Name='Version';Expression={Split-Path $_ -Leaf | Select-Object -First 1}},
    @{Name='Path';Expression={$_}}

$ver = $vsVersions | Where-Object {$_.Version -eq $vsVersion }
if ($null -eq $ver)
{
  throw "Visual Studio version $vsVersion not found"
}
$devShellModule = Join-Path $ver.Path "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Import-Module $devShellModule
Enter-VsDevShell -VsInstallPath $ver.Path -SkipAutomaticLocation

.$PSScriptRoot\MSBuild-Alias.ps1

