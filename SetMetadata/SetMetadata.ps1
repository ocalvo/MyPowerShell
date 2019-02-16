param (
	$videoFolder,
	[switch] $forcemetadata=$false
)

$date = Get-Date
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "\\server\Logs\SetMetadata."+$date.Year+"-"+$date.Month+"-"+$date.Day+".txt"
$msbuild = $env:windir+"\Microsoft.NET\Framework\v3.5\MSBuild.exe"
echo $mydir
.$msbuild "/nologo" ($myDir+"\SetMetadata.project") ("/flp:LogFile="+$logFile) ("/p:VideoFolder="+$videoFolder) ("/p:ForceMetadata="+$forcemetadata)

