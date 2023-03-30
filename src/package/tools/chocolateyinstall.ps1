$ErrorActionPreference = 'Stop'
[string] $packageName = $env:ChocolateyPackageName
[string] $toolsDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Get available drive letter for mounting ISO
function GetAvailableDriveLetter() {
    $driveLetter = [int][char]'C'
    $driveLetters = @()
    # Getting all the used Drive letters reported by the Operating System
    $(Get-PSDrive -PSProvider filesystem) | ForEach-Object { $driveLetters += $_.name }
    while ($driveLetters -contains $([char]$driveLetter)) {
        $driveLetter++
    }
    return $([char]$driveLetter)
}

# Main function
function Main() {
    # Load package data
    [string] $xmlPath = Join-Path $toolsDir 'packageData.xml'
    [xml] $packageData = Get-Content $xmlPath

    # Read package data
    $isoDownloadUrl = $packageData.PackageData.IsoDownloadUrl
    $isoChecksum = $packageData.PackageData.IsoCheckum
    $installerName = $packageData.PackageData.InstallerName

    # Parse package params
    $pp = Get-PackageParameters
    # Location of installer
    if (!$pp['Installer']) {
        $pp['Installer'] = $isoDownloadUrl
    }

    $tmpDir = $null
    $isoIsMounted = $false
    try {
        # Create temp dir for extraction / processing
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
        Write-Host "Create temp dir $tmpDir"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null

        if ($pp['Installer'] -match '\.iso$') {
            # Installer is ISO file
            Write-Debug "Installing from ISO file"

            # Download offline installer
            if ($isoDownloadUrl -match '.*/(.*?)$') {
                $isoName = $Matches[1]
            }
            else {
                throw "Unable to extract iso name from $isoDownloadUrl"
            }
            $isoPath = Join-Path $tmpDir $isoName
            Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $isoPath -Url ($pp['Installer']) -Checksum $isoChecksum -ChecksumType 'sha256' | Out-Null
            Write-Host "Visual Studio offline installer downloaded to $isoPath"

            # Mounting image
            $mountDrive = [string] (GetAvailableDriveLetter) + ':'
            Write-Host "Mounting ISO to drive $mountDrive"
            imdisk -a -f "$isoPath" -m $mountDrive
            $isoIsMounted = $true
            $installerPath = "$mountDrive\$installerName"
        }
        else {
            # Installer is directory with files
            Write-Debug "Installing from directory"

            $installerPath = Join-Path $pp['Installer'] $installerName
        }

        # Build install args
        $logFilePath = Join-Path $env:TEMP "$packageName.setup.log"
        $adminFilePath = Join-Path $toolsDir 'AdminDeployment.xml'
        $installArgs = "/q /NoWeb /NoRefresh /NoRestart /L `"$logFilePath`" /adminFile `"$adminFilePath`""
        if ($pp['InstallDir']) {
            $installArgs += " /CustomInstallPath `"$($pp['InstallDir'])`""
        }
        if ($pp['ProductKey']) {
            $installArgs += " /ProductKey `"$($pp['ProductKey'])`""
        }

        # Running installer
        Install-ChocolateyInstallPackage -PackageName $packageName -FileType 'exe' -File $installerPath -SilentArgs $installArgs -validExitCodes @(0, 3010, -2147185721)
    }
    finally {
        # Unmount ISO
        if ($isoIsMounted -and (Test-Path $mountDrive)) {
            imdisk -D -m $mountDrive
        }
        # Cleanup temp dir
        if (Test-Path $tmpDir) {
            Write-Host "Removing temp dir $tmpDir"
            Remove-Item -Recurse -Force $tmpDir -ErrorAction Continue
        }
    }
}

# Call Main
Main