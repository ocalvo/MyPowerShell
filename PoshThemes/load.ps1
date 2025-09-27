[CmdLetBinding()]
param(
  $poshTheme = "markbull.omp.custom.yaml",
  $poshDebugScript = "/.cache/_poshdebug.ps1"
)

if ($null -eq (get-command oh-my-posh -ErrorAction Ignore)) {
  if (Test-IsUnix) {
    $poshDir = "~/bin"
    if ($notInPath) { $env:PATH += ":$poshDir" }
  } else {
    $poshDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
    if ($notInPath) { $env:PATH += ";$poshDir" }
  }
}

if ($null -ne (get-command oh-my-posh -ErrorAction Ignore)) {
  if ($DebugPreference -eq 'Continue') {
    $Error.Clear()
  }
  $global:__poshScript = oh-my-posh init pwsh --config "$PSScriptRoot/$poshTheme"
  if ($DebugPreference -eq 'Continue') {
    oh-my-posh init pwsh --config "$PSScriptRoot/$poshTheme" --debug | Write-Debug
    $poshScript | Set-Content -Path $poshDebugScript -Force
    Write-Debug ("PoshScript saved at {0}" -f $poshDebugScript)
  }
  $result = $global:__poshScript | Invoke-Expression
  if ($DebugPreference -eq 'Continue') {
    $Error | ForEach-Object {
      Write-Debug ("Error {0}" -f $_)
    }
    Write-Debug ("Expression Result:{0}" -f $result)
  }
}

