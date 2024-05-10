param(
  $arch = "amd64",
  $flavor = "fre",
  $branchName = "rs_es_corebuild",
  $bId = ((dir \\winbuilds\release\$branchName | select -last 2 | select -first 1).Name),
  $bName)

if ($null -ne $bName) {
  $bParts = $bName.Split(".")
  $branchName = $bParts | Select -Skip 2 -First 1
  $bId = ($bParts[0]+"."+$bParts[1]+"."+$bParts[3])
}

if ($null -eq $bId) {
  Write-Error "$bId is not set"
  return
}

$buildCsv = "\\winbuilds\release\$branchName\$bId\$arch$flavor\build_logs\build$flavor.csv"
if (!(Test-Path $buildCsv)) {
  Write-Error "Build data $buildCsv not found, build may be incomplete or does not exist"
  return;
}

$dataMem = Get-Content $buildCsv | ConvertFrom-Csv

$col = $dataMem | gm | where { $_.Name.Contains('Memory\Available MBytes') } | select -first 1
$colName = $col.Name
$dataMem.$colName | Measure-Object -Minimum
$global:data = $dataMem.$colName

$result = $global:data | Measure-Object -Minimum
$absMin = $result.Minimum*1Mb/1Gb;
Write-Host "Absolute minimum $absMin Gb"

# Initialize an empty array to store the local minimums
$global:localMin = @()

# Iterate through the data set, excluding the first and last elements
for ($i=1; $i -lt ($data.Length-1); $i++) {
  # If the current element is less than or equal to its neighbors, it's a local minimum
  if ($data[$i] -le $data[$i-1] -and $data[$i] -le $data[$i+1]) {
    $global:localMin += $data[$i]
  }
}

$result = $global:localMin | Measure-Object -Average
$averageMin = $result.Average*1Mb/1Gb
Write-Host "Average local minimums $averageMin Gb"
