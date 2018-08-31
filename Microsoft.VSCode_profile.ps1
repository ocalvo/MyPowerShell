$pspath=$env:PSModulePath.Split(';')[0]+"\.."
$stdProfile = $pspath+"\Microsoft.PowerShell_profile.ps1"
.$stdProfile
