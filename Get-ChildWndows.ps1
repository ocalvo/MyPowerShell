function Get-ChildWindows
{
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [System.Diagnostics.Process]
        $Process
    )

    BEGIN
    {
        function Local:Get-DelegateType
        {
            Param
            (
                [OutputType([Type])]
            
                [Parameter( Position = 0)]
                [Type[]]
                $Parameters = (New-Object Type[](0)),
            
                [Parameter( Position = 1 )]
                [Type]
                $ReturnType = [Void]
            )

            $Domain = [AppDomain]::CurrentDomain
            $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
            $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, 'Run')
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)

            $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType',
                                                     'Class, Public, Sealed, AnsiClass, AutoClass',
                                                     [MulticastDelegate])

            $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public',
                                                                 'Standard',
                                                                 $Parameters)

            $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')

            $MethodBuilder = $TypeBuilder.DefineMethod('Invoke',
                                                       'Public, HideBySig, NewSlot, Virtual',
                                                       $ReturnType,
                                                       $Parameters)

            $MethodBuilder.SetImplementationFlags('Runtime, Managed')
        
            Write-Output $TypeBuilder.CreateType()
        }

        # Create a delegate type with EnumChildProc function signature
        $EnumChildProcDelegateType = Get-DelegateType @([IntPtr], [Int32]) ([Bool])

        # Define p/invoke method for User32!EnumWindows
        $DynAssembly = New-Object System.Reflection.AssemblyName('SysUtils')
        $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, 'Run')
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('SysUtils', $False)
        $TypeBuilder = $ModuleBuilder.DefineType('User32', 'Public, Class')

        $TypeBuilder.DefinePInvokeMethod( 'EnumChildWindows',
                                          'user32.dll',
                                          'Public, Static',
                                          'Standard',
                                          # EnumChildWindows return type
                                          [Bool],
                                          # EnumChildWindows arguments.
                                          @([IntPtr], [MulticastDelegate], [Int32]),
                                          'Winapi',
                                          'Auto' ) | Out-Null

        $User32 = $TypeBuilder.CreateType()

        $mscorlib = [AppDomain]::CurrentDomain.GetAssemblies() | ? {$_.ManifestModule.Name -eq 'System.dll'}
        $NativeMethods = $mscorlib.GetType('Microsoft.Win32.NativeMethods')
        $Global:GetWindowTextLength = $NativeMethods.GetMethod('GetWindowTextLength', ([Reflection.BindingFlags] 'Public, Static'))
        $Global:GetWindowText = $NativeMethods.GetMethod('GetWindowText', ([Reflection.BindingFlags] 'Public, Static'))

        # This scriptblock will serve as the callback function
        $Action = {
            # Define params in place of $args[0] and $args[1]
            # Note: These parameters need to match the params
            # of EnumChildProc.
            Param (
                [IntPtr] $hwnd,
                [Int32] $lParam
            )

            $WindowTitle = [String]::Empty

            if ($hwnd -ne [IntPtr]::Zero)
            {
                $WindowTitleLength = $Global:GetWindowTextLength.Invoke($null,
                    @(([Runtime.InteropServices.HandleRef] (New-Object Runtime.InteropServices.HandleRef($this, $hwnd))))) * 2

                $WindowTitleSB = New-Object Text.StringBuilder($WindowTitleLength)

                $Global:GetWindowText.Invoke($null,
                    @(([Runtime.InteropServices.HandleRef] (New-Object Runtime.InteropServices.HandleRef($this, $hwnd))),
                    [Text.StringBuilder] $WindowTitleSB, $WindowTitleSB.Capacity))

                $WindowTitle = $WindowTitleSB.ToString()
            }
            
            $Result = New-Object PSObject -Property @{ Handle = $hwnd; WindowTitle = $WindowTitle }

            $Global:WindowInfo += $Result

            # Returning true will allow EnumChildWindows to continue iterating through each window
            $True
        }

        # Cast the scriptblock as the EnumWindowsProc delegate created eariler
        $EnumChildProc = $Action -as $EnumChildProcDelegateType
    }

    PROCESS
    {
        foreach ($Proc in $Process)
        {
            # Store all of the window handles into a global variable.
            # This is only way the callback function (i.e. scriptblock)
            # will be able to communicate objects back to the PowerShell
            # session.
            $Global:WindowInfo = New-Object PSObject[](0)

            # Finally, call EnumChildWindows
            $User32::EnumChildWindows($Proc.MainWindowHandle, $EnumChildProc, 0) | Out-Null

            # Output all of the window handles
            Write-Output $Global:WindowInfo

            Remove-Variable -Name WindowInfo -Scope Global
        }
    }

    END
    {
        Remove-Variable -Name GetWindowTextLength -Scope Global
        Remove-Variable -Name GetWindowText -Scope Global
    }
}

Get-ChildWindows $args[0]