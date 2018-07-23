Function Enable-AutoAdminLogon
{
  param(
    [Parameter(Mandatory=$false)][String[]]$computerName = ".",
    [Parameter(Mandatory=$false)][String]$DefaultDomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)][String]$DefaultUserName = $env:USERNAME,
    [Parameter(Mandatory=$true)][String]$DefaultPassword,
    [Parameter(Mandatory=$false)][Int]$AutoLogonCount)

  if ([IntPtr]::Size -eq 8)
  {
    $hostArchitecture = "amd64"
  }
  else
  {
    $hostArchitecture = "x86"
  }
  foreach ($computer in $computerName) {
    if (($hostArchitecture -eq "x86") -and ((Get-WmiObject -ComputerName $computer -Class Win32_OperatingSystem).OSArchitecture -eq "64-bit"))
    {
       Write-Host "Remote System's OS architecture is amd64. You must run this script from x64 PowerShell Host" continue
    }
    else
    {
      if ($computer -ne ".")
      {
        if ((Get-Service -ComputerName $computer -Name RemoteRegistry).Status -ne "Running")
        {
          Write-Error "remote registry service is not running on $($computer)" continue
        }
        else
        {
          Write-Verbose "Adding required registry values on $($computer)"
          $remoteRegBaseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$computer)
          $remoteRegSubKey = $remoteRegBaseKey.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon",$true)
          $remoteRegSubKey.SetValue("AutoAdminLogon",1,[Microsoft.Win32.RegistryValueKind]::String)
          $remoteRegSubKey.SetValue("DefaultDomainName",$DefaultDomainName,[Microsoft.Win32.RegistryValueKind]::String)
          $remoteRegSubKey.SetValue("DefaultUserName",$DefaultUserName,[Microsoft.Win32.RegistryValueKind]::String)
          $remoteRegSubKey.SetValue("DefaultPassword",$DefaultPassword,[Microsoft.Win32.RegistryValueKind]::String)
          if ($AutoLogonCount)
          {
             $remoteRegSubKey.SetValue("AutoLogonCount",$AutoLogonCount,[Microsoft.Win32.RegistryValueKind]::DWord)
          }
        }
      }
      else
      {
        #do local modifications here
        Write-Verbose "Adding required registry values on $($computer)"
        Write-Verbose "Saving curent location"
        Push-Location
        Set-Location "HKLM:\Software\Microsoft\Windows NT\Currentversion\WinLogon"
        New-ItemProperty -Path $pwd.Path -Name "AutoAdminLogon" -Value 1 -PropertyType "String" -Force | Out-Null
        New-ItemProperty -Path $pwd.Path -Name "DefaultUserName" -Value $DefaultUserName -PropertyType "String" -Force | Out-Null
        New-ItemProperty -Path $pwd.Path -Name "DefaultPassword" -Value $DefaultPassword -PropertyType "String" -Force | Out-Null
        New-ItemProperty -Path $pwd.Path -Name "DefaultDomainName" -Value $DefaultDomainName -PropertyType "String" -Force | Out-Null
        if ($AutoLogonCount)
        {
          New-ItemProperty -Path $pwd.Path -Name "AutoLogonCount" -Value $AutoLogonCount -PropertyType "Dword" -Force | Out-Null
        }
        Write-Verbose "restoring earlier location"
        Pop-Location
      }
    }
  }
}