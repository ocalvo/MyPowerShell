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

function global:Get-BuildErrors()
{
    $buildErrorsDir = ".\"
    $buildErrorsFile = ($buildErrorsDir + "build" + $env:_BuildType + ".err")
    if (!(Test-Path $buildErrorsFile))
    {
        return;
    }
    Get-Content .\build$env:_BuildType.err | where-object { $_ -like "*(*) : error *" } |ForEach-Object {
        $fileStart = $_.IndexOf(">")
        $fileEnd = $_.IndexOf("(")
        $fileName = $_.SubString($fileStart + 1, $fileEnd - $fileStart - 1)
        $fileNumberEnd =  $_.IndexOf(")")
        $fileNumber = $_.SubString($fileEnd + 1, $fileNumberEnd - $fileEnd - 1)
        $errorStart = $_.IndexOf(" : ");
        $errorD = $_.SubString($errorStart + 3);
        [System.Tuple]::Create($fileName,$fileNumber,$errorD)
    }
}
function global:Open-Editor($fileName,$lineNumber)
{
  if ($null -ne $env:VSCODE_CWD)
  {
    $codeParam = ($fileName+":"+$lineNumber)
    code --goto $codeParam
  }
  elseif ($null -ne (get-command edit))
  {
    edit $fileName ("+"+$lineNumber)
  }
  else
  {
    .$env:SDEDITOR $fileName
  }
}

function global:Edit-BuildErrors($first=1,$skip=0)
{
  Get-BuildErrors | Select-Object -First $first -Skip $skip |ForEach-Object { Open-Editor $_.Item1 $_.Item2 }
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