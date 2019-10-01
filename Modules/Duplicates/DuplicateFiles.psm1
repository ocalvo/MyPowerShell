$hashRootDir = $null
$hashResultsDir = $null

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

[ScriptBlock] $findFunction = { $true }

function Get-Duplicate
{
    param (
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        $h
    )
    process {
        Get-ChildItem -Path $h.FullName -File |
            Select-Object -Property ('DirectoryName','Target','Name') |
            Where-Object { Test-Path $_.Target }
    }
}

function Process-Duplicate
{
    param (
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$h
    )
    process {
        Write-Progress -Id 1 -Activity "Finding duplicates" -Status "Getting hash for $h"
        $hashDir = ($hashResultsDir + $h)
        Get-ChildItem -Path $hashDir -File |
            Select-Object -Property Target |
            ForEach-Object {
                Get-Item $_.Target
            } |
            Where-Object { (test-path $_) } |
            Add-Member -MemberType NoteProperty -Name ContentHash -Value $h
    }
}

function Find-Duplicates
{
    [CmdletBinding()]
    param (
        [string] $hashStore = $env:temp,
        [ScriptBlock] $filter
    )

    if ($filter -NE $null)
    {
        $findFunction = $filter;
    }

    $hashResultsDir = ($hashStore+"\Dupes\Results\")
    if (!(test-path $hashResultsDir))
    {
        Write-Error "No hash store was found, run Get-Duplicates first"
        return;
    }

    Get-ChildItem $hashResultsDir -Directory |
        Get-Duplicate
}

Export-ModuleMember -Function "Get-*"
Export-ModuleMember -Function "Find-*"



