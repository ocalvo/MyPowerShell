########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#  Last update: 2010-03-20
#

function global:Setup-Host
{
  param($width = 160, $height = 50, $lineBuffer = 3000)

  cls
  try
  {
    $bufferSize = new-object System.Management.Automation.Host.Size -prop @{Width=$width; Height = $lineBuffer}
    $host.UI.RawUI.BufferSize = $bufferSize

    $size = new-object System.Management.Automation.Host.Size -prop @{Width=$width; Height = $height}
    $host.UI.RawUI.WindowSize = $size

    $host.UI.RawUI.ForegroundColor = 'White'
    $host.UI.RawUI.BackgroundColor = 'DarkMagenta'

    $host.UI.RawUI.WindowPosition = new-object System.Management.Automation.Host.Coordinates
  }
  finally
  {
    cls
  }
}
#Setup-Host

$psTab = Get-Module PowerTab -ListAvailable
if ($null -eq $psTab)
{
  Find-Module PowerTab | Install-Module -Force
}
Import-Module PowerTab
Import-Module PSReadLine
Set-PSReadLineOption –HistoryNoDuplicates:$True

$env:_NT_SYMBOL_PATH='SRV*c:\dd\symbols*http://symweb'
$env:ChocolateyInstall='C:\ProgramData\Chocolatey'
$env:path += ';' + $env:ChocolateyInstall + '\bin'

########################################################
# Helper Functions
function ff ([string] $glob) { get-childitem -recurse -filter $glob }
function logout { shutdown /l /t 0 }
function halt { shutdown /s /t 5 }
function restart { shutdown /r /t 5 }
function reboot { shutdown /r /t 0 }
function sleep { RunDll.exe PowrProf.dll,SetSuspendState }
function global:Lock-WorkStation {
  $signature = "[DllImport(`"user32.dll`", SetLastError = true)] public static extern bool LockWorkStation();"

  $LockWorkStation = Add-Type -memberDefinition $signature -name "Win32LockWorkStation" -namespace Win32Functions -passthru
  $LockWorkStation::LockWorkStation() | Out-Null
}
function rmd ([string] $glob) { remove-item -recurse -force $glob }
function cd.. { Set-Location ..  }
function lsf { get-childitem | ? { $_.PSIsContainer -eq $false } }
function lsd { get-childitem | ? { $_.PSIsContainer -eq $true } }

function global:isadmin
{
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    $wp.IsInRole("Administrators") -eq 1
}
function Del-Dir
{
  dir -Directory |% {
    echo $_.FullName
    if (test-path $_)
    {
      pushd $_
      Del-Dir
      dir -file -include hidden | del -force
      popd
      RmDir $_ -force -rec
    }
  }
}

function Execute-Elevated
{
  param([switch]$wait)
  $file, [string]$arguments = $args;
  $psi = new-object System.Diagnostics.ProcessStartInfo $file;
  $psi.Arguments = $arguments;
  $psi.Verb = "runas";
  $p = [System.Diagnostics.Process]::Start($psi);
  if ($wait.IsPresent)
  {
      $p.WaitForExit()
  }
}
set-alias elevate Execute-Elevated -scope global

$global:myhome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]'MyDocuments')
$global:scriptFolder = $global:myhome +'\WindowsPowerShell'
$env:REMOTE_HOME = $myHome
$localHome = $env:HOMEDRIVE + $env:HOMEPATH + '\Documents'
if (!(test-path $localHome) -and (isadmin))
{
  cmd /c mklink /d $localHome $myhome
}
if (test-path $localHome)
{
  $myHome = $localHome
}

$vimRC = ($env:HOMEDRIVE + $env:HOMEPATH + '\_vimrc')
if (!(test-path $vimRC))
{
  set-content -path $vimRC "source <sfile>:p:h\Documents\WindowsPowerShell\profile.vim"
}

function global:Install-Chocolatey
{
   iex ((new-object net.webclient).DownloadString(' https://chocolatey.org/install.ps1'))
}

set-alias dd                  $myhome'\Tools\dd\dd.exe'                          -scope global
set-alias cabarc              $myhome'\Tools\cab\cabarc.exe'                     -scope global
set-alias bcomp               $myhome'\Tools\Beyond Compare 3\bcomp.com'         -scope global
set-alias razzle              $scriptFolder'\Execute-Razzle.ps1'                 -scope global
set-alias Invoke-CmdScript    $scriptFolder'\Invoke-CmdScript.ps1'               -scope global
set-alias junction            $myhome'\Tools\x86\junction.exe'                   -scope global
set-alias logon               $scriptFolder'\logon.ps1'                          -scope global
set-alias sdp                 $myhome'\Tools\sdpack\sdp.bat'                     -scope global
set-alias su                  $scriptFolder'\su.ps1'                             -scope global
set-alias sudo                elevate                                            -scope global
set-alias vsvars32            $scriptFolder'\vsvars32.ps1'                       -scope global
set-alias xde                 'C:\Program Files (x86)\Microsoft XDE\8.1\xde'     -scope global
set-alias windbg              $scriptFolder'\debug.ps1'                          -scope global
set-alias zip                 $myhome'\Tools\7-zip\7z.exe'                       -scope global
set-alias ztw                 $myhome'\Tools\Ztree\ztw64.exe'                    -scope global

set-alias update-phonesdk     '\\javascripttools\Public\wpblue\UpdateSdk.bat'                                         -scope global
set-alias update-xap          '\\winphonelabs\securestorage\Blue\Project\DevPlat\VijayKr\AppUpdater\XapUpdaterEx.exe' -scope global
set-alias CopyAndPrep-VHD     '\\jevan\public\TestMachineScripts\Scripts\CopyAndPrepVHD.ps1'                          -scope global

$env:psmodulepath = $myhome + '\WindowsPowerShell\Modules;'+ $env:psmodulepath.SubString($env:psmodulepath.IndexOf(";"))

function  global:mklink       { cmd /c mklink $args }

function global:Use-LatestCLR
{
  reg add hklm\software\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1
  reg add hklm\software\wow6432node\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1
}

function global:Use-InstalledCLR
{
  reg add hklm\software\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 0
  reg add hklm\software\wow6432node\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 0
}

# SD settings
$vimCmd = get-command vim 2> $null
$codeCmd = get-command code 2> $null
if ($null -ne $codeCmd)
{
  $env:SDEDITOR=$codeCmd.definition
  $env:SDUEDITOR=$codeCmd.definition
}
elseif ($null -ne $vimCmd)
{
  $env:SDEDITOR=$vimCmd.definition
  $env:SDUEDITOR=$vimCmd.definition
}

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
  if ($env:SDXROOT -ne $null )
  {
    $sd = $env:SDXROOT
  }
  else
  {
    $sd = (get-location)
  }
  [string[]]$exDirs=("objd","obj","objr","objc")
  if ($env:SDXROOT -ne $null )
  {
    $exDirs+=$env:SDXROOT+"\SetupAuthoring"
    $exDirs+=$env:SDXROOT+"\Tools"
    $exDirs+=$env:SDXROOT+"\public"
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

########################################################

function global:Edit()
{
  .$env:SDEDITOR $args
}

function global:View()
{
  .$env:SDEDITOR $args
}

function global:_up ([int] $count = 1)
{
    push-location -path .
    1..$count | % { set-location .. }
}

set-alias e edit -scope global
set-alias v view -scope global
set-alias up _up -scope global

function global:time
{
  $st = ""; $args | % { $st = $st + $_ + " " }; $st = $st + " | out-host"
  "Execution time:"+(measure-command {invoke-expression $st})
}

function global:Gac-PowerShell
{
  vsvars32
  [AppDomain]::CurrentDomain.GetAssemblies() |
  where { ($_.Location -ne $null) -and ($_.Location -ne "") -and (test-path $_.Location) } |
  sort {Split-path $_.location -leaf} |
  %{
    $Name = (Split-Path $_.location -leaf)
    if ([System.Runtime.InteropServices.RuntimeEnvironment]::FromGlobalAccessCache($_))
    {
      Write-Host "Already GACed: $Name"
    }
    else
    {
      Write-Host -ForegroundColor Yellow "NGENing : $Name"
      ngen install $_.location /nologo |%{"`t$_"}
    }
  }
}

function Compress-Path($Path, $Length=20)
{
    $newType = @'
[DllImport("shlwapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern bool PathCompactPathEx(System.Text.StringBuilder pszOut, string pszSrc, Int32 cchMax, Int32 dwFlags);
'@
    try { Add-Type -MemberDefinition $newType -name StringFunctions -namespace Win32 } catch {}
    $sb = New-Object System.Text.StringBuilder(260)
    if ([Win32.StringFunctions]::PathCompactPathEx($sb , $Path , $Length+1, 0))
    {
        $sb.ToString()
    }
    else
    {
        Throw "Unable to compact path"
    }
}

$env:PSRazzleDir = ($myhome+'\Razzle')
. $env:PSRazzleDir\VSO-Helpers.ps1

Compress-Path "C:\" 1>$null 2>&1 3>&1 4>&1

function global:Get-BranchName { "" }

function global:Get-LocationForPrompt
{
  [string]$p = Get-Location

  if ( ($env:SDXROOT -ne $null) -and ($p -like ($env:SDXROOT+'\*')) )
  {
      $index = ($env:SDXROOT).Length + 1
      $p = $p.SubString($index)
  }
  else
  {
    $hStr = (get-item ~).FullName
    $p = $p.Replace($hStr, "~")
  }

  (Compress-Path $p 45)
}

########################################################
# Prompt
function prompt
{
    $nextId = (get-history -count 1).Id + 1;

    $srcId = $null
    if ($env:sdxroot -ne $null)
    {
        $srcId = $env:sdxroot.Replace("\src","").ToCharArray() | select -last 1
    }

    if (test-path env:_BuildArch)
    {
      $razzleTitle = "Razzle: "+ $srcId + " " + $env:_BuildArch + "/" + $env:_BuildType + " "
      if ($razzleTitle -ne $null )
      {
        $title = $razzleTitle + (Get-WindowTitleSuffix)
      }
    }

    if ( isadmin )
    {
        $color = "Red"
        if ( $title -ne $null )
        {
          $title += " (Admin)"
        }
    }
    else
    {
        $color = "Green"
    }

    write-host ("[") -NoNewLine -ForegroundColor Green
    write-host $nextId -NoNewLine -ForegroundColor $color
    write-host (Get-BranchName) -NoNewLine -ForegroundColor Green
    write-host (" "+ (Get-LocationForPrompt) + "]") -NoNewLine -ForegroundColor Green

    if ( $title -ne $null )
    {
      $host.UI.RawUI.WindowTitle = $title;
    }

    return "> "
}

$spVoice = new-object -ComObject "SAPI.SpVoice"

function Speak-String {
    param([string]$message)
    $spVoice.Speak($message, 1);
}

function Speak-Result {
    param([ScriptBlock]$script)
    try {
        $script.Invoke();
    }
    catch [Exception] {
        Speak-String $_.Exception.Message;
        throw;
    }
    Speak-String ($script.ToString() + "  succeeded");
}

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

