#Requires -RunAsAdministrator
[CmdletBinding()]
param (
  $srcDrive = "s:",
  $binDrive = "x:"
)

#Format-Volume -DriveLetter $binDrive -DevDrive
#Format-Volume -DriveLetter $srcDrive -DevDrive

setx /M _NT_SYMBOL_PATH "SRV*$binDrive\symbols*https://symweb.azurefd.net"
setx /M npm_config_cache "$srcDrive\packages\npm"
setx /M NUGET_PACKAGES "$srcDrive\packages\nuget"
setx /M VCPKG_DEFAULT_BINARY_CACHE "$srcDrive\packages\vcpkg"
setx /M PIP_CACHE_DIR "$srcDrive\packages\pip"
setx /M CARGO_HOME "$srcDrive\packages\cargo"
setx /M MAVEN_OPTS "-Dmaven.repo.local=$srcDrive\packages\maven %MAVEN_OPTS%"
setx /M GRADLE_USER_HOME "$srcDrive\packages\gradle"
setx /M RUSTUP_HOME "$srcDrive\msrust"
setx /M MSRUSTUP_HOME "$srcDrive\msrust"

fsutil devdrv trust $binDrive
fsutil devdrv trust $srcDrive
fsutil devdrv enable /disallowAv
fsutil devdrv setfiltersallowed "PrjFlt, DfmFlt"

