[CmdletBinding()]
param(
    [Parameter(Mandatory=$false,Position=0,ValueFromRemainingArguments=$true)]
    [string[]]$DockerArgs,
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "$env:USERPROFILE\.docker-cli",
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalDays = 7,
    [Parameter(Mandatory=$false)]
    [switch]$ForceCheck
)

$ErrorActionPreference = "Stop"

Write-Verbose "InstallDir: $InstallDir"
Write-Verbose "CheckIntervalDays: $CheckIntervalDays"
Write-Verbose "ForceCheck: $ForceCheck"

# Paths
$MetaFile   = Join-Path $InstallDir "version.json"
$DockerRoot = Join-Path $InstallDir "docker"
$DockerExe  = Join-Path $DockerRoot "docker.exe"

# Detect install directory existence
$InstallDirExists = Test-Path $InstallDir
Write-Verbose "InstallDirExists: $InstallDirExists"

# Load metadata if present
$LocalVersion = $null
$LastCheck = $null
$MetaExists = Test-Path $MetaFile

if ($MetaExists) {
    try {
        $meta = Get-Content $MetaFile | ConvertFrom-Json
        $LocalVersion = $meta.version
        $LastCheck = Get-Date $meta.lastCheck
        Write-Verbose "Loaded metadata: version=$LocalVersion lastCheck=$LastCheck"
    } catch {
        Write-Verbose "Metadata corrupted, ignoring."
        $MetaExists = $false
    }
} else {
    Write-Verbose "Metadata file does not exist."
}

# Detect docker.exe existence
$DockerExists = Test-Path $DockerExe
Write-Verbose "DockerExists: $DockerExists"

# Determine whether we need to check remote
$NeedCheck =
    $ForceCheck -or
    (-not $InstallDirExists) -or
    (-not $DockerExists) -or
    (-not $MetaExists) -or
    (-not $LastCheck) -or
    ((Get-Date) - $LastCheck).Days -ge $CheckIntervalDays

Write-Verbose "NeedCheck: $NeedCheck"

if ($NeedCheck) {
    Write-Verbose "Checking latest Docker CLI version online..."

    # Ensure install directory exists before extraction
    if (-not $InstallDirExists) {
        Write-Verbose "Creating install directory: $InstallDir"
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }

    $index = Invoke-WebRequest "https://download.docker.com/win/static/stable/x86_64/"

    $files = $index.Links.href | Where-Object { $_ -match "^docker-\d+\.\d+\.\d+\.zip$" }

    if (-not $files) {
        throw "Could not detect any docker-*.zip files."
    }

    $LatestFile = $files | Sort-Object {
        ($_ -replace "docker-|\.zip","") -as [version]
    } -Descending | Select-Object -First 1

    $RemoteVersion = ($LatestFile -replace "docker-|\.zip","")
    $ZipUrl = "https://download.docker.com/win/static/stable/x86_64/$LatestFile"
    $ZipPath = "$env:TEMP\$LatestFile"

    Write-Verbose "RemoteVersion: $RemoteVersion"
    Write-Verbose "LocalVersion:  $LocalVersion"

    $IsUpToDate =
        $DockerExists -and
        $LocalVersion -and
        ([version]$RemoteVersion -le [version]$LocalVersion)

    if ($IsUpToDate) {
        Write-Verbose "Already up to date."
        @{ version = $LocalVersion; lastCheck = (Get-Date) } |
            ConvertTo-Json | Set-Content $MetaFile
    }
    else {
        Write-Verbose "Downloading new version: $RemoteVersion"
        Invoke-WebRequest $ZipUrl -OutFile $ZipPath -UseBasicParsing

        Write-Verbose "Extracting to $InstallDir"
        Expand-Archive $ZipPath -DestinationPath $InstallDir -Force

        @{ version = $RemoteVersion; lastCheck = (Get-Date) } |
            ConvertTo-Json | Set-Content $MetaFile
    }
}
else {
    Write-Verbose "Skipping version check (last check was $LastCheck)."
}

# --- Compose Plugin Install ----------------------------------------------------
$ComposeDir = Join-Path $DockerRoot "cli-plugins"
$ComposeExe = Join-Path $ComposeDir "docker-compose.exe"
$ComposeMeta = Join-Path $InstallDir "compose-version.json"
# Ensure plugin directory exists
if (-not (Test-Path $ComposeDir)) {
    New-Item -ItemType Directory -Path $ComposeDir | Out-Null
}
# Load compose metadata
$LocalComposeVersion = $null
$ComposeLastCheck = $null
$ComposeMetaExists = Test-Path $ComposeMeta
if ($ComposeMetaExists) {
    try {
        $cmeta = Get-Content $ComposeMeta | ConvertFrom-Json
        $LocalComposeVersion = $cmeta.version
        $ComposeLastCheck = Get-Date $cmeta.lastCheck
    } catch {
        $ComposeMetaExists = $false
    }
}

# Determine if compose needs update
$NeedComposeCheck = $ForceCheck -or 
    (-not $ComposeMetaExists) -or
    (-not (Test-Path $ComposeExe)) -or
    (-not $ComposeLastCheck) -or ((Get-Date) - $ComposeLastCheck).Days -ge $CheckIntervalDays

Write-Verbose "NeedComposeCheck: $NeedComposeCheck"
if ($NeedComposeCheck) {
    Write-Verbose "Checking latest Docker Compose V2 version..."
    $composeIndex = Invoke-WebRequest "https://api.github.com/repos/docker/compose/releases/latest"
    $composeJson = $composeIndex.Content | ConvertFrom-Json
    $RemoteComposeVersion = $composeJson.tag_name.TrimStart("v")
    Write-Verbose "Compose remote version: $RemoteComposeVersion"
    Write-Verbose "Compose local version: $LocalComposeVersion"
    $IsComposeUpToDate = (Test-Path $ComposeExe) -and
        $LocalComposeVersion -and ([version]$RemoteComposeVersion -le [version]$LocalComposeVersion)
    if (-not $IsComposeUpToDate) {
        Write-Verbose "Downloading Compose V2 plugin..."
        $asset = $composeJson.assets | Where-Object { $_.name -match "docker-compose-windows-x86_64.exe" } | Select-Object -First 1
        if (-not $asset) {
            throw "Could not find docker-compose-windows-x86_64.exe in release assets."
        }
        $ComposeDownload = "$env:TEMP\docker-compose.exe"
        Invoke-WebRequest $asset.browser_download_url -OutFile $ComposeDownload
        Write-Verbose "Installing Compose plugin to $ComposeExe"
        Copy-Item $ComposeDownload $ComposeExe -Force
        @{ version = $RemoteComposeVersion; lastCheck = (Get-Date) } | ConvertTo-Json | Set-Content $ComposeMeta
    } else {
        Write-Verbose "Compose plugin already up to date." 
        @{ version = $LocalComposeVersion; lastCheck = (Get-Date) } | ConvertTo-Json | Set-Content $ComposeMeta
    }
}

# Recreate docker alias
if (Get-Alias docker -ErrorAction SilentlyContinue) {
    Write-Verbose "Removing old docker alias..."
    Remove-Item Alias:docker -ErrorAction SilentlyContinue
}

Write-Verbose "Creating docker alias -> $DockerExe"
Set-Alias -Name docker -Value $DockerExe -Scope Global

# Forward all original arguments to docker.exe
if (Test-Path $DockerExe) {
    Write-Verbose "Invoking docker.exe with args: $DockerArgs"
    & $DockerExe @DockerArgs
}

