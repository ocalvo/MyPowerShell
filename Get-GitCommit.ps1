[CmdLetBinding()]
param(
  [switch]$OnlyMetadata,
  [switch]$Parallel = $true,
  $ThrottleLimit=32
)

$location = Get-Location
$cDir = $location.Path
$total = 0;
$commits = git log --oneline $cDir |% {
    $_.Split(" ")[0]
    $total++
}

Write-Verbose "Found $total commits"

$i = 0;
$lastCommit = $null
$result = $commits | ForEach-Object -Parallel {

    Write-Verbose "Parsing commit $_"
    if ($true) {
        ."C:\Users\ocalvo\Documents\PowerShell\Parse-GitCommit.ps1" -Commit $_ -OnlyMetadata
    } else {
        ."C:\Users\ocalvo\Documents\PowerShell\Parse-GitCommit.ps1" -Commit $_
    }
} -ThrottleLimit 32 |% {
    $gitCommit = $_
    [double]$p = ($i++/$total)*100.0;
    $cId = $gitCommit.Commit
    if ($cId.Length -gt 7) {
        $actName = ("{0}({1}%)" -f $gitCommit.Commit.SubString(0,8),[int]$p)
        Write-Progress -PercentComplete $p -Activity $actName;
    } else {
        Write-Warning ("Invalid commit detected: {0}" -f $gitCommit.Subject)
    }
    return $gitCommit
}

return $result

