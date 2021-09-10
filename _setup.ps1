
# Install the OpenSSH Client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Start-Service sshd
#
# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'
#
# Confirm the firewall rule is configured. It should be created automatically by setup.
Get-NetFirewallRule -Name *ssh*
#
# There should be a firewall rule named "OpenSSH-Server-In-TCP", which should be enabled
# If the firewall does not exist, create one
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Ignore

New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

powershell -nologo -noprofile -command Set-ExecutionPolicy bypass -force

if ($null -eq (get-command choco*))
{
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  choco feature enable -n allowGlobalConfirmation
}

if ($null -eq (get-command git*))
{
  choco install git
}

$env:path+=(";"+"C:\Program Files\Git\bin\")
$_psHOME=($env:HOMEDRIVE+$env:HOMEPATH+"\Documents\")
$_psD = Split-path $profile
$_psDWin = ($_psHOME+"WindowsPowerShell")
$_psDCore = ($_psHOME+"PowerShell")

if (!(Test-path $profile))
{
  git clone https://github.com/ocalvo/MyPowerShell.git $_psD
}

if ("Core" -eq $PSEdition) {
  if (!(Test-path $_psDWin))
  {
    new-Item $_psDWin -ItemType SymbolicLink -Target $_psDCore
  }
  cd $_psDCore
} else {
  if (!(Test-path $_psDCore))
  {
    new-Item $_psDCore -ItemType SymbolicLink -Target $_psDWin
  }
  cd $_psDWin
}

git submodule update --init .\vimfiles\
git submodule update --init .\Scripts\
git submodule update --init .\Modules\PowerTab\1.1.0

choco install microsoft-windows-terminal --pre
choco install cascadiafonts
choco install pwsh

If (Test-Path "C:\Program Files\openssh-win64\Set-SSHDefaultShell.ps1") {
  & "C:\Program Files\openssh-win64\Set-SSHDefaultShell.ps1"
}

.$profile

.\Set-GitConfig.ps1

$tSettings = $_psD+"\WinTerminal\settings.json"
cp $tSettings $terminalSettings
