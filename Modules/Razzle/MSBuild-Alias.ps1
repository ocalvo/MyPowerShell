Param([switch]$msBuildAlias)

$global:lastBuildErrors = $null
if ($null -eq $env:_msBuildPath)
{
  $env:_msBuildPath = (get-command msbuild).Definition
}

$env:_MSBUILD_VERBOSITY = "m"
$env:_VSINSTALLDIR = Split-path ((Split-Path ($env:_msBuildPath) -Parent)+"\..\..\") -Resolve

function global:msb()
{
  ps msbuild* | where { $_.StartInfo.EnvironmentVariables['RepoRoot'] -eq $env:RepoRoot } | kill -force
  $global:lastBuildErrors = $null
  $logFileName = ("build"+$env:_BuildType)
  .$env:_msBuildPath /bl /nologo /v:$env:_MSBUILD_VERBOSITY /m $args "-flp2:logfile=$logFileName.err;errorsonly" "-flp3:logfile=$logFileName.wrn;warningsonly"
  $global:lastBuildErrors = Get-BuildErrors
  if ($null -ne $global:lastBuildErrors)
  {
    Write-Warning "Build errors detected:`$lastBuildErrors"
  }
  ps msbuild* | where { $_.StartInfo.EnvironmentVariables['RepoRoot'] -eq $env:RepoRoot } | kill -force
}

function global:build()
{
  msb /target:Build $args
}

function global:buildclean()
{
  msb /target:ReBuild $args
}

set-alias b        build -scope global
set-alias bc       buildclean -scope global
if ($msBuildAlias.IsPresent)
{
  set-alias msbuild  build -scope global
  $env:path = ($PSScriptRoot+';'+$env:path)
}
