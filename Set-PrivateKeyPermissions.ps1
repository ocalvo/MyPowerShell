[cmdLetBinding()]
param (
    [string]$path = "$env:USERPROFILE/.ssh/id_rsa"
)

$acl = Get-Acl $path

$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)

# Create new access rules
$accessRuleUser = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:USERNAME", "FullControl", "Allow")
$acl.AddAccessRule($accessRuleUser)

#$accessRuleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
#$acl.AddAccessRule($accessRuleSystem)

Set-Acl $path $acl
