<#
.Synopsis
    Robocopy wrapper with standard 0 (success) and 1 (failure) exit codes.
.Parameter source
    Defines the source folder
.Parameter target
    Defines the target folder
.Parameter include
    Defines the files to include. Accepts wildcards. Eg: -include *.dll,*.pdb
    Optional, Default value is $null and will include all files from source.
.Parameter exclude
    Defines the files to exclude. Accepts wildcards. Eg: -exclude *.dll,*.pdb
    Optional, Default value is $null and will not exclude any files from source.
.Parameter folder_exclude
    Defines the folders to exclude. Eg: -exclude .git,.svn
    Optional, Default value is $null and will not exclude any folders from source.
.Parameter action
    Defines the robocopy action to execute.
    Optional, Default is /MIR which will mirror source on target. If files exist in target, but not in source, they will be deleted from target.
.Parameter options
    Defines any extra robocopy options to append to the command
    Optional, Default value is /NP /R:2 /W:1 /FFT /Z /XA:H
    /NP - do not display the progress percentage. Useful in logged scripts which would otherwise include numerous progress lines.
    /R:2 - Retry twice (in case of open files or other impediments).
    /W:1 - Wait 1 second between retries.
    /FFT /Z /XA: - Prevents errors between filesystems with different conventions for file access times.
.Link
    http://ss64.com/nt/robocopy.html
.Link
    http://ss64.com/nt/robocopy-exit.html
#>
param (
    [Parameter (Mandatory = $true)]
    [string] $source,
    [Parameter (Mandatory = $true)]
    [string] $target,
    [string[]] $include = $null,
    [string[]] $exclude = $null,
    [string[]] $folder_exclude = $null,
    [string[]] $action = @("/MIR"),
    [string[]] $options = @("/NP", "/R:2", "/W:1", "/FFT", "/Z", "/XA:H")
)
$cmd_args = @($source, $target)
if ($include) {
    $cmd_args += $include
}
if ($exclude) {
    $cmd_args += (@("/XF") + $exclude)
}
if ($folder_exclude) {
    $cmd_args += (@("/XD") + $folder_exclude)
}
if ($action) {
    $cmd_args += $action
}
if ($options) {
    $cmd_args += $options
}
& robocopy.exe @cmd_args
$returnCodeMessage = @{
    0x00 = "[INFO]: No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized."
    0x01 = "[INFO]: One or more files were copied successfully (that is, new files have arrived)."
    0x02 = "[INFO]: Some Extra files or directories were detected. Examine the output log for details."
    0x04 = "[WARN]: Some Mismatched files or directories were detected. Examine the output log. Some housekeeping may be needed."
    0x08 = "[ERROR]: Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further."
    0x10 = "[ERROR]: Usage error or an error due to insufficient access privileges on the source or destination directories."
}
Write-Host $returnCodeMessage[($returnCodeMessage.Keys | Where { ($_ -band $i) -or ($_ -eq 0x00) } | Select -First 1)]
exit ($LastExitCode -band 24)
