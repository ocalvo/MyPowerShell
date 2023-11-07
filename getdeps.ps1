param(
  $depsFile,
  $appType = '.NETCoreApp,Version=v6.0/win10-x64')

$j = Get-Content $depsFile | ConvertFrom-Json
$appDeps = $j.targets.$appType

$appDeps | gm | Where-Object { $_.Name.Contains("/") } |
  Select-Object @{Name="Name";Expression={$_.Name}},@{Name="Deps";Expression={
    $n = $_.Name;
    $deps = $appDeps.$n.dependencies | gm | where { $_.MemberType -eq "NoteProperty" }
    $deps |% { $_.Definition.Replace("string ","") }
    }}

