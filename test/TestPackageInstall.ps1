#Requires -Version 5

param(
    # Package name
    [Parameter(Mandatory = $true)]
    [string] $PackageName,
    # Package source dir
    [Parameter(Mandatory = $false)]
    [string] $PackageSourceDir,
    # Package install dir
    [Parameter(Mandatory = $false)]
    [string] $PackageInstallDir
)


# Terminate on exception
trap {
    Write-Host "Error: $_"
    Write-Host $_.ScriptStackTrace
    exit 1
}

# Always stop on errors
$ErrorActionPreference = "Stop"

# Strict mode
Set-StrictMode -Version Latest



# Main function
function Main() {

    # Determine package source dir
    $pkgSourceDir = $PackageSourceDir
    if (-not $pkgSourceDir) {
        $pkgSourceDir = Join-Path $PSScriptRoot "../Dist"
    }

    # Determine package install dir
    $pkgInstalltDir = $PackageInstallDir
    if (-not $pkgInstalltDir) {
        $pkgInstalltDir = Join-Path $PSScriptRoot "VS 2013"
    }

    # Path for chocolatey logfile
    $chocolateyLogPath = Join-Path $PSScriptRoot "/logs/chocolatey.log"

    # Remove existing chocolatey log
    if (Test-Path $chocolateyLogPath) {
        Write-Host "*** Remove existing chocolatey log $chocolateyLogPath"
        Remove-Item $chocolateyLogPath -Force
    }

    # Install package
    Write-Host "`n*** Installing chocolatey package: $PackageName"
    Write-Host "*** Package source dir: $pkgSourceDir"
    Write-Host "*** Install dir: $pkgInstalltDir`n"

    # Check whether to use local copy of ISO file
    if ($env:VS_INSTALLER_LOCATION) {
        $isoLocParam = " /Installer:$env:VS_INSTALLER_LOCATION"
    }
    else {
        $isoLocParam = ""
    }

    $cmd = "choco install $PackageName --source=`"$pkgSourceDir;chocolatey`" --yes --force --no-progress --log-file=`"$chocolateyLogPath`" --params=`"'/InstallDir:$pkgInstalltDir $isoLocParam'`""
    Write-Host "*** Executing: $cmd"
    Invoke-Expression "& $cmd"
    if ($LASTEXITCODE -ne 0) { throw "Failed" }


    # Uninstall package
    Write-Host "`n*** Uninstalling chocolatey package: $PackageName`n"
    $cmd = "choco uninstall $PackageName --yes --force --no-progress --log-file=`"$chocolateyLogPath`""
    Write-Host "*** Executing: $cmd"
    Invoke-Expression "& $cmd"
    if ($LASTEXITCODE -ne 0) { throw "Failed" }

    Write-Host "`nFinished"
}


# Call Main
Main