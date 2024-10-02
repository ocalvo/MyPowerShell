[CmdLetBinding()]
param(
  [switch]$OnlyMetadata
)

$location = Get-Location
$cDir = $location.Path
$total = 0;
$commits = git log --oneline $cDir |% {
    $_.Split(" ")[0]
    $total++
}

Write-Verbose "Found $total commits"

$sr = $PSScriptRoot
$i = 0;
$result = $commits | ForEach-Object {
    Write-Verbose "Parsing commit $_"
    if ($OnlyMetadata) {
        $gitCommit = Parse-GitCommit -Commit $_ -OnlyMetadata
    } else {
        $gitCommit = Parse-GitCommit -Commit $_
    }
    [double]$p = ($i++/$total)*100.0;
    Write-Progress -PercentComplete $p -Activity ("{0}({1}%)" -f $gitCommit.Commit.SubString(0,8),[int]$p);
    return $gitCommit
}

return $result

