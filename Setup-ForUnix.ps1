param()

$h = (get-item ~).FullName

$u = (whoami)
$_pwcmd = (get-command pwsh).Definition
sudo usermod --shell $_pwcmd $u

git config --global submodule.recurse true
git clone https://github.com/ocalvo/MyPowerShell.git ($h+'/OneDrive/Documents/PowerShell')
git clone https://github.com/ocalvo/PSPersonalModules.git ($h+'/OneDrive/Documents/PSModules')

#new-item /home/$user/OneDrive/Documents/PowerShell -ItemType SymbolicLink -Target /mnt/c/Users/oscar/OneDrive/Documents/PowerShell
#new-item /home/$user/OneDrive/Documents/PSModules -ItemType SymbolicLink -Target /mnt/c/Users/$winUser/OneDrive/Documents/PSModules/

new-item ($h+'/.config/powershell') -ItemType SymbolicLink -Target ($h+'/OneDrive/Documents/PowerShell') -Force

