
if (!(Test-IsUnix)) {

  if ((get-command sudo -erroraction ignore) -eq $null)
  {
    Enable-Execute-Elevated
    $env:path += ";~\scoop\apps"
  }

  $global:terminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

  function global:Install-Chocolatey
  {
    if (Test-IsUnix) { return; }

    if (!(test-isadmin))
    {
       Write-Error "Not admin"
       return
    }

    Invoke-Expression ((new-object net.webclient).DownloadString(' https://chocolatey.org/install.ps1'));
    $env:path += ";C:\ProgramData\chocolatey\bin"
    choco feature enable -n allowGlobalConfirmation
    #choco install cascadiafonts
    #choco install pwsh --pre
    cp $PSScriptRoot\WinTerminal\settings.json $terminalSettings
    $env:path += ";C:\ProgramData\chocolatey\bin"
  }

  function global:Install-Scoop
  {
    if ((get-command scoop*) -eq $null)
    {
      iwr -useb get.scoop.sh | iex

      scoop bucket add nerd-fonts
      scoop install Cascadia-Code
    }
    if ((get-command gsudo*) -eq $null)
    {
      scoop install gsudo
      gsudo cache on
    }
    if ((get-command pwsh*) -eq $null)
    {
      sudo scoop install pwsh
      git clone http://github.com/ocalvo/MyPowerShell ($env:HOMEDRIVE+$env:HOMEPATH+"\Documents\PowerShell") --recursive
    }
    if ((get-command vim*) -eq $null)
    {
      sudo scoop install vim
    }
    if ((get-command wt*) -eq $null)
    {
      scoop bucket add versions
      scoop install windows-terminal-preview
      cp $PSScriptRoot\WinTerminal\settings.json $terminalSettings
      git clone 
    }
    if ((get-command python*) -eq $null)
    {
      scoop bucket add versions
      scoop install python310
    }
    #if ((get-command choco*) -eq $null)
    #{
    #  sudo Install-Chocolatey
    #}
  }

  $symbolsPath = "c:\dd\symbols"
  if (test-path $symbolsPath)
  {
    $env:_NT_SYMBOL_PATH=('SRV*'+$symbolsPath+'*http://symweb')
  }

  if ((get-command git -erroraction ignore) -eq $null)
  {
    sudo choco install git -y
    $env:path += ";C:\Program Files\Git\cmd"
  }

}

#$isWorkMode = ($env:USERNAME -eq "ocalvo")
#if ($isWorkMode)
#{
#  $workOneDriveDir = "~/OneDrive - Microsoft"
#  if (!(Test-path "~/OneDrive/Documents"))
#  {
#    $workOneDriveDir = (get-item $workOneDriveDir).FullName
#    if (Test-Path "~/OneDrive")
#    {
#      mv ~/OneDrive ~/OneDrive.old
#    }
#    new-item ~/OneDrive -ItemType SymbolicLink -Target $workOneDriveDir -force
#  }
#}

#if (!(test-path ~/Documents/PowerShell))
#{
#  $workOneDriveDir = "~/OneDrive - Microsoft"
#  $oneDriveDir = (get-item "~/OneDrive").FullName
#  $useWorkOneDrive = (test-path $workOneDriveDir\Documents)
#  if ($useWorkOneDrive)
#  {
#    $workOneDriveDir = (get-item $workOneDriveDir).FullName
#    new-item ~/OneDrive -ItemType SymbolicLink -Target $workOneDriveDir -force
#    $oneDriveDir = $workOneDriveDir
#  }
#  new-item ~/Documents -ItemType SymbolicLink -Target $oneDriveDir/Documents -force
#}
