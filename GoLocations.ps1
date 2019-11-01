########################################################
# 'go' command and targets

if( $global:go_locations -eq $null )
{
  $global:go_locations = @{};
}

function _sd
{
  param([string] $pattern,[switch]$All)

  import-module ~\Documents\WindowsPowerShell\Modules\SearchDir\SearchDir.dll

  [string[]]$sd
  if ($env:_XROOT -ne $null )
  {
    $sd = $env:_XROOT
  }
  else
  {
    $sd = (get-location)
  }
  [string[]]$exDirs=("objd","obj","objr","objc")
  if ($env:_XROOT -ne $null )
  {
    $exDirs+=$env:_XROOT+"\SetupAuthoring"
    $exDirs+=$env:_XROOT+"\Tools"
    $exDirs+=$env:_XROOT+"\public"
  }
  if ($env:init -ne $null )
  {
    $exDirs+=$env:init
  }
  if ( $all.IsPresent )
  {
    Search-Directory -Search $sd -ExcludeDirectories $exDirs -Pattern $pattern -All
  }
  else
  {
    Search-Directory -Search $sd -ExcludeDirectories $exDirs -Pattern $pattern
  }
}

function _gosd
{
  param([string] $pattern)
  $dir = $null
  if (test-path $pattern)
  {
    $dir = (gi $pattern)
  }
  else
  {
    $dir = (_sd $pattern)
  }

  if (!($dir -eq $null))
  {
    $fn= $dir.FullName
    pushd $fn
    return $true
  }

  return $false
}

function global:Goto-KnownLocation([string] $location)
{
  if ( $go_locations.ContainsKey($location) )
  {
    set-location $go_locations[$location];
  }
  else
  {
    if (!(_gosd $location))
    {
      write-output "The following locations are defined:";
      write-output $go_locations;
    }
  }
}
$go_locations["home"]="~"
$go_locations["dl"]="\\server\Downloads"
$go_locations["dev"]="C:\dd"
$go_locations["scripts"]="~\Documents\WindowsPowerShell"
$go_locations["tools"]="~\Documents\Tools"
$go_locations["public"]=$env:public

set-alias go                 Goto-KnownLocation                 -scope global

