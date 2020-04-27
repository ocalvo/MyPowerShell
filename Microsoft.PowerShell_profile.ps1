########################################################
# Oscar Calvo's PowerShell Profile (oscar@calvonet.com)
#

$psTab = Get-Module PowerTab -ListAvailable
if ($null -eq $psTab)
{
  Find-Module PowerTab | Install-Module -Force
}

$symbolsPath = "w:\symbols"
if (test-path $symbolsPath)
{
  $env:_NT_SYMBOL_PATH=('SRV*'+$symbolsPath+'*http://symweb')
}
$env:ChocolateyToolsLocation = "C:\ProgramData\chocolatey\tools\"

########################################################
# Helper Functions
function ff ([string] $glob) { get-childitem -recurse -filter $glob }
function Sleep-Computer { RunDll.exe PowrProf.dll,SetSuspendState }
function global:Lock-WorkStation {
  $signature = "[DllImport(`"user32.dll`", SetLastError = true)] public static extern bool LockWorkStation();"

  $LockWorkStation = Add-Type -memberDefinition $signature -name "Win32LockWorkStation" -namespace Win32Functions -passthru
  $LockWorkStation::LockWorkStation() | Out-Null
}
function rmd ([string] $glob) { remove-item -recurse -force $glob }
function cd.. { Set-Location ..  }
function .. { Set-Location ..  }

function test-isadmin
{
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    $wp.IsInRole("Administrators") -eq 1
}
$isAdmin = (test-isadmin)
$global:myhome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]'MyDocuments')
$global:scriptFolder = $global:myhome +'\WindowsPowerShell'
$env:REMOTE_HOME = $myHome
$localHome = $env:HOMEDRIVE + $env:HOMEPATH + '\Documents'
if (!(test-path $localHome))
{
  if ($isAdmin)
  {
    New-Item $localHome -ItemType SymbolicLink -Target $myhome
  }
}
if (test-path $localHome)
{
  $myHome = $localHome
}

$vimRC = ($env:USERPROFILE + '\_vimrc')
if (!(test-path $vimRC))
{
  set-content -path $vimRC "source <sfile>:p:h\Documents\WindowsPowerShell\profile.vim"
}

function global:Install-Chocolatey
{
   Invoke-Expression ((new-object net.webclient).DownloadString(' https://chocolatey.org/install.ps1'))
}

set-alias bcomp               $env:ProgramFiles'\Beyond Compare 4\bcomp.com'     -scope global
set-alias razzle              Execute-Razzle                                     -scope global
set-alias vsvars              Enter-VSShell                                      -scope global
set-alias zip                 7z                                                 -scope global
set-alias ztw                 '~\OneDrive\Apps\ZtreeWin\ztw64.exe'               -scope global
set-alias sudo                Execute-Elevated                                   -scope global
set-alias go                  Goto-KnownLocation                                 -scope global

# SD settings
$vimCmd = get-command vim 2> $null
$codeCmd = get-command code 2> $null
if (($null -ne $codeCmd) -and ($env:TERM_PROGRAM -eq "vscode"))
{
  $env:SDEDITOR=$codeCmd.definition
  $env:SDUEDITOR=$codeCmd.definition
}
elseif ($null -ne $vimCmd)
{
  $env:SDEDITOR=$vimCmd.definition
  $env:SDUEDITOR=$vimCmd.definition
}

function global:Edit()
{
  .$env:SDEDITOR $args
}

function global:_up ([int] $count = 1)
{
    push-location -path .
    1..$count | % { set-location .. }
}

set-alias e edit -scope global
set-alias up _up -scope global

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

function global:Get-BranchName { "" }

function global:Get-LocationForPrompt
{
  [string]$p = (Get-Location).ProviderPath

  if ( ($env:_XROOT -ne $null) -and ($p -like ($env:_XROOT+'\*')) )
  {
      $index = ($env:_XROOT).Length + 1
      $p = $p.SubString($index)
  }
  else
  {
    $hStr = (get-item ~).FullName
    $p = $p.Replace($hStr, "~")
  }

  (Compress-Path $p 45)
}

if ($null -ne $env:SSH_CLIENT)
{
  $remoteIp = ($env:SSH_CLIENT.Split(" ") | select -first 1)
  if (("::1" -ne $remoteIp) -and ("127.0.0.1" -ne $remoteIp))
  {
    $localHostName = $env:COMPUTERNAME
  }
}

########################################################
# Prompt
function prompt
{
    $srcId = $null
    if ($env:_xroot -ne $null)
    {
        $srcId = $env:_xroot.Replace("\src","").ToCharArray() | select-object -last 1
    }

    if (test-path env:_BuildArch)
    {
      $razzleTitle = "Razzle: "+ $srcId + " " + $env:_BuildArch + "/" + $env:_BuildType + " "
      if ($razzleTitle -ne $null )
      {
        $title = $razzleTitle + (Get-WindowTitleSuffix)
      }
    }

    if ( $isadmin )
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
    write-host ((Get-BranchName)) -NoNewLine -ForegroundColor Green
    if ($null -ne $localHostName)
    {
      Write-host ($localHostName+":") -NoNewLine -ForegroundColor Green
    }
    Write-host ((Get-LocationForPrompt) + "]") -NoNewLine -ForegroundColor Green
    Write-host ">" -NoNewLine -ForegroundColor $color

    if ( $title -ne $null )
    {
      $host.UI.RawUI.WindowTitle = $title;
    }
    return " "
}

$serverModules='S:\ServerFolders\Company\Scripts\Modules'
if (test-path $serverModules -ErrorAction Ignore)
{
  $env:psmodulepath+=(';'+$serverModules)
  Import-Module PersonalMedia
}

$psScripts = ($PSScriptRoot+'\Modules\scripts\PSRazzle.psm1')
if (test-path $psScripts -ErrorAction Ignore)
{
  Import-Module $psScripts
}

Import-Module DirColors

$global:wt_profile = ($env:LocalAppData+'\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json')

function global:Execute-PowerShell32
{
  c:\Windows\SysWoW64\WindowsPowerShell\v1.0\powershell.exe -nologo $args
}
set-alias ps32 Execute-PowerShell32 -scope global

function global:Open-CodeFlow
{
  param([string]$webUrl)
  #\\codeflow\public\cf.cmd help openGitHubPr
  \\codeflow\public\cf.cmd openGitHubPr -webUrl $webUrl
  #\\codeflow\public\cf.cmd openGitHubPr -account <account> -GitHubProject <project> -prId <prId>
}

#Import-Module PowerTab
Import-Module PSReadLine
Set-PSReadLineOption –HistoryNoDuplicates:$True
Import-Module PSSudo
Import-Module SearchDir
Import-Module Razzle

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

