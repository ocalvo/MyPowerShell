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
$_psD = ($_psHOME+"WindowsPowerShell")
$_psDCore = ($_psHOME+"PowerShell")

if (!(Test-path $_psD))
{
  git clone https://github.com/ocalvo/MyPowerShell.git $_psD
}

if (!(Test-Path $_psDCore))
{
  new-Item $_psDCore -ItemType SymbolicLink -Target $_psD
}

if ("Core" -eq $PSEdition) {
  cd $_psDCore
} else {
  cd $_psD
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

