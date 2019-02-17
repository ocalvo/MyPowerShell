
function Get-Duplicates()
{
    [CmdletBinding()]
    param (
        [string[]] $inputDirs,
        [string] $hashStore = $env:temp
    )

    $hashRootDir = ($hashStore+"\Dupes\Hash\")
    if (!(test-path $hashRootDir))
    {
        mkdir $hashRootDir
    }

    $hashResultsDir = ($hashStore+"\Dupes\Results\")
    if (!(test-path $hashResultsDir))
    {
        mkdir $hashResultsDir
    }

    Get-ChildItem ([string[]]$inputDirs) -Recurse -File |
        Where-Object { $_.Length -gt 0 } |
        ForEach-Object {
            $fullName = $_.FullName
            Write-Progress -Id 1 -Activity "Finding duplicates" -Status "Getting hash for $fullName"
            $hash = Get-FileHash $_.FullName -Algorithm MD5
            $h = $hash.Hash
            $hashDir = ($hashRootDir + "\" + $h)
            $name = $_.Name
            if (!(test-path $hashDir))
            {
                Write-Output "Found new hash $h=>$name"
                mkdir $hashDir | Out-Null
            }
            $currentDupes = Get-ChildItem -Path $hashDir -File |
                Select-Object -Property Target |
                ForEach-Object {
                    Get-Item $_.Target
                }
            $dupe = $currentDupes | Where-Object -Property FullName -EQ $fullName;
            if ($dupe -EQ $null)
            {
                $guid = [guid]::NewGuid();
                $dupe = New-Item -Path $hashDir -Name $guid -ItemType SymbolicLink -Target $fullName
                if ($currentDupes.Count -NE 0)
                {
                    Write-Output "Found duplicate for $fullName with hash $h"
                    $resultPath = $hashResultsDir + "\" + $h
                    if (!(test-path $resultPath))
                    {
                        New-Item -Path $hashResultsDir -Name $h -ItemType SymbolicLink -Target $hashDir
                    }
                }
            }
        }
}

Export-ModuleMember -Function "Get-*"



