########
# Remoting scripts
#
# Change log:
#   09.11.05 - Detect broken sessions and create a new in such case
#

if ($env:USERDOMAIN -eq "REDMOND")
{
  $global:SU_User=$env:USERDOMAIN+"\"+$env:USERNAME
}
else
{
  $global:SU_User = "SU"
}

function global:Enable-Remoting()
{
    Enable-PSRemoting  -force
    set-item WSMan:\localhost\Client\TrustedHosts * -force
    set-item wsman:localhost\Shell\MaxMemoryPerShellMB 1024 -force
    Enable-WSManCredSSP –Role Server -force
}

$global:clients = (
    "*",
    "*.calvonet.com",
    "*.corp.microsoft.com",
    "calvorojas.homeserver.com"
)

function Allow-Delegation($policyName)
{
    $keyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\"+$policyName
    if (test-path $keyPath)
    {
        rmdir $keyPath -force -rec
    }
    $key = mkdir $keyPath
    [int]$id = 1
    $clients |% { $key.SetValue($id.ToString(),"WSMAN/"+$_.ToString()); $id += 1 }
}

function global:Enable-ClientRemoting()
{
    $clients |% {Enable-WSManCredSSP –Role Client –DelegateComputer $_.ToString() -force }
    Allow-Delegation "AllowDefaultCredentials"
    Allow-Delegation "AllowDefCredentialsWhenNTLMOnly"
    Allow-Delegation "AllowFreshCredentials"
    Allow-Delegation "AllowFreshCredentialsWhenNTLMOnly"
    Enable-Remoting
}

function Import-PSCredential
{
  #http://halr9000.com/article/531
  param ( [string]$Path = "credentials.enc.xml", [string]$CredentialVariable ) 	#to create a global credential with a specified name	
  $import = Import-Clixml $Path # Import credential file
  # Test for valid import
  if ( !$import.UserName -or !$import.EncryptedPassword )
  {
    throw "Input is not a valid ExportedPSCredential object, exiting."
  }
  $Username = $import.Username
  $SecurePass = $import.EncryptedPassword | ConvertTo-SecureString  # Decrypt the password and store as a SecureString object for safekeeping
  $PsCredential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass  # Build the new credential object
  if ($CredentialVariable)
  {
    New-Variable -Name:$CredentialVariable -Scope:Global -Value:$PsCredential
  }
  else
  {
    return $PsCredential
  }
}

function Get-AdminCredential($UserName=$SU_User)
{
    $CredDir = $env:LOCALAPPDATA + '\CredDir' # stores credential files
    switch ($UserName)
    {
        "SU"
        {
            $CredUsrExpr = '(Get-WmiObject -Query "SELECT * FROM Win32_Account WHERE LocalAccount = True AND SID LIKE ""S-1-5-21-%-500""").Caption'
            $CredFilenam = Join-Path -Path:$CredDir -ChildPath:$($env:COMPUTERNAME+"_S-1-5-21--500")
        }
        "EMA"
        {
            $CredUsrExpr = '$env:UserDomain + "\" + $env:UserName[0] + "ema" + $env:UserName.Remove(0,1)'
            $CredFilenam = Join-Path -Path:$CredDir -ChildPath:$($env:UserDomain+"_S-1-5-21--ema")
        }
        default
        {
            $CredUsrExpr = '$UserName'
            $CredFilenam = Join-Path -Path:$CredDir -ChildPath:$UserName.Replace("\","_")
        }
    }
    Import-PSCredential -Path:"$CredFilenam"
}


function global:enter-session()
{
    param ($server="tv-server",[switch]$32bit=$False,$port=5985)


    if ( $server -eq "localhost")
    {
        $port=80
    }
    $cred = Get-AdminCredential
    if ( $cred -eq $null)
    {
        $cred = Get-Credential -credential administrator
    }
    $session = get-pssession | where { $_.ComputerName -eq $server }
    if ( $session -eq $null -or $session.State -eq [System.Management.Automation.Runspaces.RunspaceState]::Broken )
    {
        $config = "microsoft.powershell"
        if ( $32Bit )
        {
            $config = "microsoft.powershell32"
        }

        $sessionAuth = "credssp"
        if ($server.StartsWith("server"))
        {
            $sessionAuth = "default"
        }

        $session = New-PSSession $server -cred $cred -auth $sessionAuth -config $config -port $port
        Invoke-Command $profile -session $session
    }
    Enter-PSSession -session $session
}

function global:add-ssh-tunnel()
{
    ssh root@router -p 222 -f -L 80:vm-server:5985 sleep 10
}

function global:Connect-WinPhone7
{
  echo "Dial ##634#"
  echo "In the diagnostics mode that opens up, enter *#7284# in the phone dialer."
  echo "Switch to ""Modem, Tethered Call"" and wait for the phone to restart."
  echo "Set the number to *99***1# user name to WAP@CINGULARGPRS.COM, and password to CINGULAR1, and connect."
}

