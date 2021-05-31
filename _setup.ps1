iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation
choco install git
$env:path+=(";"+"C:\Program Files\Git\bin\")
$_psD = ($env:HOMEDRIVE+$env:HOMEPATH+"\Documents\WindowsPowerShell")
git clone https://github.com/ocalvo/MyPowerShell.git $_psD
new-Item ~\Documents\PowerShell -ItemType SymbolicLink -Target ~\Documents\WindowsPowerShell

cd $_psD
git submodule update --init .\vimfiles\

choco install microsoft-windows-terminal --pre
choco install cascadiafonts
choco install pwsh

.$profile

.\Set-GitConfig.ps1

