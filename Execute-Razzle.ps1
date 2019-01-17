#################################
#
# Razzle scripts
# ocalvo@microsoft.com
#
param (
  $flavor="chk",
  $arch="x86",
  $device=$null,
  $binaries = "c:\dd\bin\",
  [switch]$bl_ok,
  [switch]$oacr,
  [switch]$opt,
  [switch]$noDeep,
  [switch]$nobtok,
  [switch]$gitVersionCheck,
  $enlistment = $env:SDXROOT)

##
## Support to get out and get in of razzle
##

if ($null -eq $enlistment)
{
  $currentDir = Get-Location;
  Write-Host "Checking current dir $currentDir for enlistment"
  $rootDir = $currentDir.Path.Split('\') | select-object -First 3
  [string]$dirs = "";
  $rootDir |ForEach-Object { $dirs += ($_+"\") }
  if (($null -ne $dirs) -and ($dirs -like "f:\os*\src\"))
  {
    Write-Host "Current dir is enlistment $dirs"
    $enlistment = $dirs
  }
}
if ($null -ne $env:_BuildArch) {$arch=$env:_BuildArch;}
if ($null -ne $env:_BuildType) {$flavor=$env:_BuildType;}

$global:UnRazzleEnv = (Get-ChildItem env:*);
$global:RazzleEnv = $null;

set-item env:psmodulepath ([System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine"))

function global:Undo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:UnRazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value > $null 2> $null
  }
}

function global:Redo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:RazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value > $null 2> $null
  }
}

function global:Execute-OutsideRazzle
{
  param([ScriptBlock] $script)

  Undo-Razzle;
  try
  {
    & $script;
  }
  finally
  {
    Redo-Razzle;
  }
}

Set-Alias UnRazzle Execute-OutsideRazzle -Scope Global;
function Get-Batchfile ($file)
{
  $cmd = "echo off & `"$file`" & set"
  cmd /c $cmd | Foreach-Object {
    $p, $v = $_.split('=')
    Set-Item -path env:$p -value $v
  }
}

function Execute-Razzle32($flavor="chk",$enlistment)
{
  $process = 'C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
  $args = '-executionpolicy bypass -noexit -c Razzle '+$flavor+' '+$enlistment
  Execute-Elevated $process $args
}

[hashtable]$razzleKind = [ordered]@{ DevDiv = "\src\tools\razzle.ps1"; Windows = "\developer\razzle.ps1"; Phone = "\wm\tools\bat\WPOpen.ps1" }

function Get-RazzleProbeDir($kind, $srcDir)
{
    return ($srcDir+$razzleKind[$kind])
}

function Get-RazzleKind($srcDir)
{
  if ($device -eq $null)
  {
    return "Windows"
  }
  $kind = $razzleKind.Keys | where { (test-path (Get-RazzleProbeDir $_ $srcDir)) } | select -first 1
  return $kind
}

$global:ddDir = "c:\dd"
$global:ddIni = ($ddDir+"\dd.ini")

function global:Get-RazzleProbes()
{
  [string[]]$razzleProbe = $null

  if (test-path $ddIni)
  {
    if ($null -eq $enlistment)
    {
      $enlistment = (get-content $ddIni)
    }
    if (($enlistment -ne $null) -and (test-path $enlistment))
    {
      $razzleProbe += $enlistment
      return $razzleProbe
    }
  }

  if (($enlistment -ne $null) -and (test-path ($ddDir+"\"+$enlistment)))
  {
    $razzleProbe += ($ddDir+"\"+$enlistment)
    return $razzleProbe
  }

  [string[]]$additionalProbes = $null
  $additionalProbes = (dir $ddDir ) | where { test-path ($_.FullName) } |% { $_.FullName }
  if (!($additionalProbes -eq $null))
  {
    $razzleProbe += $additionalProbes
  }

  return $razzleProbe
}

function Get-BranchName($razzleDirName)
{
  $branch = (git branch | where { $_.StartsWith("*") } | select -first 1 )
  if ($branch -ne $null)
  {
    $branch = $branch.Split("/") | select -last 1
    if ($branch -ne $null)
    {
      return $branch;
    }
  }
  return $razzleDirName;
}

function global:New-RazzleLink($linkName, $binaries)
{
  echo "Linking $linkName -> $binaries ..."

  if (!(test-path $binaries))
  {
     echo "Making new dir $binaries"
     mkdir $binaries > $null
  }

  $currentTarget = $null
  if (test-path $linkName)
  {
     $currentTarget = (Get-Item $linkName).Target
  }
  if (($currentTarget -eq $null) -or ($currentTarget -ne $binaries))
  {
     echo "Making new link $linkName -> $binaries"
     New-Item $linkName -ItemType SymbolicLink -Target $binaries -Force > $null
  }
}

function global:Get-BranchCustomId()
{
    [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    return ($branch.Split("/") | select -last 1)
}

function Remove-InvalidFileNameChars
{
  param([Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
      [String]$Name
  )
  return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), ' ')
}

function global:Retarget-Razzle($binariesRoot, $srcRoot = $env:OSBuildRoot)
{
    Write-Output ("Retargeting $srcRoot -> $binariesRoot")

    Push-Location ($srcRoot+"\src")
    $binRoot = $srcRoot.Replace("f:","w:")
    $binRoot = $binRoot.Replace("F:","w:")
    Write-Output "Branch binRoot is $binRoot"
    Pop-Location

    New-RazzleLink "f:\os" $srcRoot
    New-RazzleLink "w:\os" $binRoot
    New-RazzleLink ($srcRoot+"\bin") ($binRoot+"\bin")
    New-RazzleLink ($srcRoot+"\bldcache") ($binRoot+"\bldcache")
    New-RazzleLink ($srcRoot+"\bldout") ($binRoot+"\bldout")
    New-RazzleLink ($srcRoot+"\cdg") ($binRoot+"\cdg")
    New-RazzleLink ($srcRoot+"\intl") ($binRoot+"\intl")
    New-RazzleLink ($srcRoot+"\engcache") ($binRoot+"\engcache")
    New-RazzleLink ($srcRoot+"\pgo") ($binRoot+"\pgo")
    New-RazzleLink ($srcRoot+"\public") ($binRoot+"\public")
    New-RazzleLink ($srcRoot+"\pubpkg") ($binRoot+"\pubpkg")
    New-RazzleLink ($srcRoot+"\obj") ($binRoot+"\obj")
    New-RazzleLink ($srcRoot+"\osdep") ($binRoot+"\osdep")
    New-RazzleLink ($srcRoot+"\out") ($binRoot+"\out")
    New-RazzleLink ($srcRoot+"\Temp") ($binRoot+"\Temp")
    New-RazzleLink ($srcRoot+"\tools") ($binRoot+"\tools")
    New-RazzleLink ($srcRoot+"\utilities") ($binRoot+"\utilities")

    New-RazzleLink ($binRoot+"\src") ($srcRoot+"\src")

    New-RazzleLink "c:\Symbols" "w:\Symbols"
    New-RazzleLink "c:\Symcache" "w:\Symbols"
    New-RazzleLink "c:\Sym" "w:\Symbols"
    New-RazzleLink "c:\Temp" "w:\Temp"
    New-RazzleLink "c:\Logs" "w:\Logs"
    New-RazzleLink "c:\CrashDumps" "w:\CrashDumps"
    New-RazzleLink "c:\VHDs" "w:\VHDs"
    New-RazzleLink "c:\Debuggers" "f:\Debuggers"
    New-RazzleLink "f:\Debuggers\Sym" "w:\Symbols"
    New-RazzleLink "f:\Debuggers\Wow64\Sym" "w:\Symbols"

    $enlistNumber = $srcRoot.Substring($srcRoot.LastIndexOf("os")+2,1)
    $workspaceFolder = "F:\os$enlistNumber"
    $realWorkspaceFile = "$workspaceFolder\os$enlistNumber.code-workspace"
    if (test-path $realWorkspaceFile)
    {
      $title = Get-WindowTitleSuffix
      $title = $enlistNumber + " " + $title
      $fileName = Remove-InvalidFileNameChars $title
      $workSpaceFile = "$workspaceFolder\$fileName.code-workspace"
      if (!(test-path $workSpaceFile))
      {
        new-item -ItemType SymbolicLink $workSpaceFile -Target $realWorkspaceFile
      }
      $otherLinks = Get-ChildItem $workspaceFolder\*.code-workspace | Where-Object -Property LinkType -eq SymbolicLink | Where-Object -Property BaseName -ne $fileName
      if ($null -ne $otherLinks)
      {
        $otherLinks | ForEach-Object { Write-Warning "Deleting $_"; Remove-item $_ }
      }
    }

    Write-Output ("Retargeting done")
}

function Execute-Razzle($flavor="chk",$arch="x86",$enlistment)
{
  if (!(IsAdmin))
  {
    Write-Error "Admin required to unblock BitLocker"
    return
  }

  if ( ($gitVersionCheck.IsPresent) )
  {
    Write-Host "Checking git version..."
    .'\\ntdev\sourcetools\release\Setup.cmd' -Canary
  }
  else
  {
    Write-Host "Not Checking git version"
  }

  if ((Get-BitLockerVolume -MountPoint "F:").LockStatus -eq "Locked")
  {
    Write-Host "Unlocking drive F:..."
    $pass = ConvertTo-SecureString (Get-Content ~\Documents\Passwords\Bitlocker.txt) -AsPlainText -Force
    Unlock-BitLocker -MountPoint "F:" -Password $pass
  }

  $popDir = Get-Location

  Undo-Razzle

  [string[]]$razzleProbe = Get-RazzleProbes

  foreach ($driveEnlistRoot in $razzleProbe)
  {
    if (test-path $driveEnlistRoot)
    {
      $razzleDirName = split-path $driveEnlistRoot -leaf
      $depotRoot = $driveEnlistRoot
      Write-Host "Probing $depotRoot..."

      if ($depotRoot -like "*\os*\src")
      {
        Write-Host "gvfs mount $depotRoot..."
        gvfs mount $depotRoot
      }

      $srcDir = $depotRoot;
      $kind = Get-RazzleKind $srcDir
      if ($null -ne $kind)
      {
        Push-Location $srcDir
        $razzle = (Get-RazzleProbeDir $kind $srcDir)
        if ( test-path $razzle )
        {
          if (!($popDir.Path.StartsWith($depotRoot)))
          {
             $podDir = $null
          }

          set-content $ddIni $srcDir

          $env:RazzleOptions = ""
          if (!($opt.IsPresent))
          {
            $env:RazzleOptions += " no_opt "
          }

          if ( !($oacr.IsPresent) )
          {
            $env:RazzleOptions += " no_oacr "
          }

          $binaries += $razzleDirName
          $binaries = ("w:\"+(Get-BranchName $razzleDirName))
          $tempDir = ($binaries + "\temp")

          if ($noDeep.IsPresent)
          {
            $env:RazzleOptions += " binaries_dir " + $binaries + "\bin "
            $env:RazzleOptions += " object_dir " + $binaries + "\obj "
            $env:RazzleOptions += " public_dir " + $binaries + "\public "
            $env:RazzleOptions += " output_dir " + $binaries + "\out "
            $env:RazzleOptions += "  temp " + $tempDir
          }
          else
          {
            Retarget-Razzle $binaries (Get-item $depotRoot).Parent.FullName
          }

          if ($nobtok.IsPresent)
          {
            $env:RazzleOptions += " no_bl_ok "
          }

          $phoneOptions = ""
          if ( $kind -eq "Phone" )
          {
            $uConfig = ($ddDir + '\DefaultWindowsSettings.uconfig')
            if (test-path $uConfig)
            {
              $phoneOptions += " uconfig=" + $uConfig + " "
            }

            $phoneOptions += (" UConfig_Razzle_Parameters=`""+$env:RazzleOptions+"`" ")
          }

          [string]$extraArgs
          $args |ForEach-Object { $extraArgs += " " + $_ }

          $extraArgs += " developer_dir ~\Documents\Razzle\ "

          if ( $kind -eq "Phone" )
          {
            .$razzle $device ($arch+$flavor) $phoneOptions $extraArgs
          }
          else
          {
            Write-Output ".$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt"
            .$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt
          }

          $global:RazzleEnv = (Get-ChildItem env:*);

          $env:_NT_SYMBOL_PATH+=(';'+$env:_nttree+'\symbols.pri\retail\dll')
          $env:CG_TEMP = ($env:TEMP+"\CatGates")
          if (test-path env:LANG)
          {
            Remove-Item env:LANG
          }
          Pop-Location
          if ($null -ne $popDir)
          {
            Set-Location $popDir
          }

          $title = Get-WindowTitleSuffix
          Write-Host "Branch:$title" -ForegroundColor Yellow
          return
        }
        Write-Output $razzle
      }
    }
  }
  throw "Razzle not found"
}

if (!(test-path "W:\Symbols"))
{
   mkdir W:\Symbols
}

if (!(test-path "W:\SymCache"))
{
   mkdir W:\SymCache
}

if (!(test-path "W:\Temp"))
{
   mkdir W:\Temp
}

Execute-Razzle -flavor $flavor -arch $arch -enlistment $enlistment

