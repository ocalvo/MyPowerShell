iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation
choco install git
$env:path+=(";"+"C:\Program Files\Git\bin\")
git clone https://github.com/ocalvo/MyPowerShell.git ($env:HOMEDRIVE+$env:HOMEPATH+"\Documents\WindowsPowerShell")
new-Item ~\Documents\PowerShell -ItemType SymbolicLink -Target ~\Documents\WindowsPowerShell

choco install cacadiafonts

.$profile
