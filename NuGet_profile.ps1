."\\imself-lh-srv-1\documents\ocalvo\My Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

function global:Get-VSService($serviceType)
{
    # If the type was specified as a string, convert it to a Type
    if ($serviceType -is [string])
    {
        $serviceType = [Type]::GetType($serviceType, $true)
    }

    # First check the VS service container
    $service = [Microsoft.VisualStudio.Shell.ServiceProvider]::GlobalProvider.GetService($serviceType)
    
    if ($service -eq $null)
    {    
        # Then check the MEF container
        $componentModel = Get-VSComponentModel
        $getServiceMethod = [Microsoft.VisualStudio.ComponentModelHost.IComponentModel].GetMethod("GetService").MakeGenericMethod($serviceType)
        $service = $getServiceMethod.Invoke($componentModel, $null)
    }
    
    return $service
}

vsvars32

