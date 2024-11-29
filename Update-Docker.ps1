#Requires -RunAsAdministrator
[CmdLetBinding()]
param(
  $baseUrl = "https://download.docker.com/win/static/stable/x86_64/",
  $destinationPath = "$env:ProgramFiles\docker",
  $serviceName = "docker",
  $currentVerFile = "$destinationPath\ver.txt",
  [switch]$Force
)

if ($force) {
    if (Test-Path $currentVerFile) {
        Remove-Item $currentVerFile
    }
}

$latestVersionZip = Invoke-WebRequest -Uri $baseUrl | Select-String -Pattern 'docker-\d+\.\d+\.\d+\.zip' | ForEach-Object { $_.Matches[0].Value } | Sort-Object -Descending | Select-Object -First 1
Write-Verbose "Found version: $latestVersionZip"

# Use a regular expression to extract the version
if (-Not ($latestVersionZip -match "docker-(\d+\.\d+\.\d+)\.zip")) {
    Write-Error "No version found in the input string."
    return 404
}
[version]$latestVersion = [version]$matches[1]
[version]$currentVersion = [version]"0.0.0"
if (Test-Path $currentVerFile) {
  [version]$currentVersion = [version](Get-Content  $currentVerFile)
}

Write-Verbose "Current version $currentVersion"
Write-Verbose "Latest version $latestVersion"

if ($currentVersion -ge $latestVersion) {
  Write-Verbose "Current version is equal or more than latest"
  return 0;
}

$dockerUrl = "$baseUrl$latestVersionZip"
Write-Verbose "Downloading $dockerUrl"

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Verbose "Stopping service $serviceName"
    Stop-Service -Name $serviceName -ErrorAction SilentlyContinue
}

# Download the Docker zip file
$zipFilePath = "$env:TEMP\docker.zip"
if (Test-Path $zipFilePath) {
  Remove-Item $zipFilePath
}
Invoke-WebRequest -Uri $dockerUrl -OutFile $zipFilePath
Write-Verbose "Expanding $zipFilePath to $destinationPath"
Expand-Archive -Path $zipFilePath -DestinationPath $destinationPath -Force
Remove-Item -Path $zipFilePath

$dockerPath = "$destinationPath\docker"
& "$dockerPath\dockerd.exe" --register-service

Start-Service -Name "docker"

if (-Not (Get-command docker -ErrorAction SilentlyContinue)) {
    Write-Verbose "Adding $dockerPath to system PATH"
    $currentSystemPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    if ($currentSystemPath -notlike "*$dockerPath*") {
      $newSystemPath = "$currentSystemPath;$dockerPath"
      [Environment]::SetEnvironmentVariable("Path", $newSystemPath, [EnvironmentVariableTarget]::Machine)
      Write-Verbose "Docker path added to the system PATH successfully."
    } else {
      Write-Verbose "Docker path is already in the system PATH."
    }
}

Set-Content $latestVersion -path $currentVerFile

