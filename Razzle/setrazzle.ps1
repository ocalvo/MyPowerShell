# ocalvo Razzle settings

Write-Host "Setting Razzle settings for ocalvo, ver 2.0"

.$PSScriptRoot\SkyFallPSPuller.ps1

function global:wux
{
    go onecoreuap\windows\dxaml\xcp\dxaml\dllsrv\winrt\native
    build -parent $args[0] $args[1] $args[2]
    Pop-Location
}

function global:wu
{
  go onecoreuap\windows\AdvCore\WinRT\OneCoreIWindow\CoreWindow
  build -parent $args[0] $args[1] $args[2]
  Pop-Location
  go onecoreuap\windows\AdvCore\WinRT\OneCoreDll\moderncore
  build -parent $args[0] $args[1] $args[2]
  Pop-Location
  go windows\AdvCore\WinRT\Dll
  build -parent $args[0] $args[1] $args[2]
  Pop-Location
}

set-alias pv $env:SDXROOT\onecoreuap\windows\dxaml\scripts\pv.ps1 -scope global

function global:pusheen
{
  [string]$a = ""
  $args |ForEach-Object { $a += " " + $_ + " " }
  . $env:SDXROOT\onecoreuap\windows\dxaml\scripts\pusheen.cmd $a
}

function global:Build-MyPublics()
{
  go onecore\windows\AppCompat\db;build;Pop-Location
  go onecoreuap\windows\wil\staging;build;Pop-Location
}

function global:Build-MySDK()
{
  go onecoreuap\merged\winmetadata;build;Pop-Location
  go MergeComponents\SDK;build;Pop-Location
}

function global:New-Branch($bug)
{
  $lkg = GetLkgCommit
  git checkout -B user/ocalvo/$bug $lkg.CommitId
  git fetch
  razzle
}

function global:Delete-LocalBranches()
{
  param([switch]$force)

  git branch | Where-Object { !$_.StartsWith("*") } |ForEach-Object {
    $branchName = $_.Trim()
    if ($force.IsPresent)
    {
      git branch -D $branchName
    }
    else
    {
      git branch -d $branchName
    }
  }
}
