#
#  Update SkyFallPS from release share
#
$ReleasePath = '\\redmond.corp.microsoft.com\osg\Threshold\TestContent\CORE\DEP\XAML\catGates\release\';
$CurrentVerPath = ($releasePath+"\current.txt")
$CurrentVer = Get-Content $CurrentVerPath
$ReleaseServicePath = ($ReleasePath+$CurrentVer+"\service")
$tempFolder = $env:TEMP+"\CatGatesPS"
$env:SkyFallPSTargetDir = $tempFolder
$InstalledVerPath = ($env:SkyFallPSTargetDir+"\current.txt")
if (Test-path $InstalledVerPath)
{
   $InstalledVer = Get-Content $InstalledVerPath
}
else
{
   $InstalledVer = "0";
}
if ($CurrentVer -ne $installedVer)
{
    $skyFallModule = (get-module SkyFallPS)
    if ($null -eq $skyFallModule)
    {
        Write-Host "Updating SkyFallPS to version $CurrentVer"
        RoboCopy $ReleaseServicePath $env:SkyFallPSTargetDir /S /PURGE /NP /NS /NC /NFL /NDL /NJH /NJS
        Copy-Item $CurrentVerPath $InstalledVerPath -Force
    }
    else
    {
        $env:SkyFallPSTargetDir = $skyFallModule.ModuleBase
        Write-Warning "SkyFallPS version $installedVer is out of date, lastest version $CurrentVer"
    }
}
$env:Path+=(";"+$env:SkyFallPSTargetDir)

