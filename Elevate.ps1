
function global:Test-IsAdmin
{
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    $wp.IsInRole("Administrators") -eq 1
}

function global:Open-Elevated
{
  param([switch]$wait)
  $file, [string]$arguments = $args;

  if (!(Test-IsAdmin))
  {
    $psi = new-object System.Diagnostics.ProcessStartInfo $file;
    $psi.Arguments = $arguments;
    $psi.Verb = "runas";
    $p = [System.Diagnostics.Process]::Start($psi);
    if ($wait.IsPresent)
    {
        $p.WaitForExit()
    }
  }
  else
  {
    & $file $args
  }
}
set-alias elevate Open-Elevated -scope global

function global:Enable-SSH
{
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  Set-Service -Name sshd -StartupType 'Automatic'
  Set-Service -Name ssh-agent -StartupType 'Automatic'
  New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
  New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
  Start-Service ssh-agent
  Start-Service sshd
}

function global:Setup-Sudo
{
  $keyfile = $env:HOMEDRIVE+$env:HOMEPATH+'/.ssh/id_rsa'
  $keyfilePub =  $keyfile+'.pub'
  if (test-path $keyfile)
  {
    Remove-Item $keyfile -Force
    Remove-Item $keyfilePub -Force
  }
  ssh-keygen -t rsa -f $keyfile -q -P `"`"
  ssh-add $keyfile

  $serverKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
  if (!(test-path $serverKeys))
  {
     Set-Content -Value (Get-Content $keyfilePub) $serverKeys -Encoding UTF8
     $acl = Get-Acl $serverKeys
     $acl.SetAccessRuleProtection($true, $false)
     $administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
     $systemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
     $acl.SetAccessRule($administratorsRule)
     $acl.SetAccessRule($systemRule)
     $acl | Set-Acl
  }
}

function global:sudo
{
  param([switch]$wait)
  $file, [string]$arguments = $args;

  if (!(Test-IsAdmin))
  {
    ssh $env:USERDOMAIN\$env:USERNAME@localhost $args
  }
  else
  {
    & $file $args
  }
}

