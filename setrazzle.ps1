# ocalvo Razzle settings

echo "Setting razzle settings for ocalvo"

function global:wux
{
    go onecoreuap\windows\dxaml\xcp\dxaml\dllsrv\winrt\native
    build -parent $args[0] $args[1] $args[2]
    popd
}

function global:wu
{
  go onecoreuap\windows\AdvCore\WinRT\OneCoreIWindow\CoreWindow
  build -parent $args[0] $args[1] $args[2]
  popd
  go onecoreuap\windows\AdvCore\WinRT\OneCoreDll\moderncore
  build -parent $args[0] $args[1] $args[2]
  popd
  go windows\AdvCore\WinRT\Dll
  build -parent $args[0] $args[1] $args[2]
  popd
}

set-alias pv $env:SDXROOT\onecoreuap\windows\dxaml\scripts\pv.ps1 -scope global

function global:pusheen
{
  [string]$a = ""
  $args |% { $a += " " + $_ + " " }
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
    Get-Content .\build$env:_BuildType.err | where { $_ -like "*(*) : error *" } |% {
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

function global:Edit-BuildErrors($first=1,$skip=0)
{
  Get-BuildErrors | Select-Object -First $first -Skip $skip |% { edit $_.Item1 ("+"+$_.Item2) }
}

function global:Build-MyPublics()
{
  go onecore\windows\AppCompat\db;build;popd
  go onecoreuap\windows\wil\staging;build;popd
}

function global:Build-MySDK()
{
  go onecoreuap\merged\winmetadata;build;popd
  go MergeComponents\SDK;build;popd
}

