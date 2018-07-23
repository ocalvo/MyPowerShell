The ARM binaries in this location are actually VS Update 2 bits. They are just put here to make the deployment scripts a little simpler.

You can copy the VSDebugD.ps1 file in this folder to %USERPROFILE%\Documents\WindowsPowerShell\Modules\VSDebugD\VSDebugD.psm1 and then from tshell:

Then from the tshell powershell prompt, run:
•   Get-Module VSDebugD | Remove-Module
•   Import-Module  $Env:USERPROFILE\Documents\WindowsPowerShell\Modules\VSDebugD\VSDebugD.psm1

And then copy these binaries ontop of those to get the LVT for Update 2