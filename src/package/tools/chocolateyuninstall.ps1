$ErrorActionPreference = 'Stop'
[string] $packageName = $env:ChocolateyPackageName
[string] $toolsDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Main function
function Main() {
    # Load package data
    [string] $xmlPath = Join-Path $toolsDir 'packageData.xml'
    [xml] $packageData = Get-Content $xmlPath

    # 32bit vs 64bit registry
    if ([System.Environment]::Is64BitOperatingSystem) {
        $regPrefix32 = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $regPrefix64 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
    }
    else {
        $regPrefix32 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
    }

    # Process uninstall data
    $uninstallData = $packageData.PackageData.Uninstall
    foreach ($record in $uninstallData) {
        Write-Debug "Processing $($record.RegKey)"
        # Determine whether to skip due to "Arch" attribute
        if (($record.Arch -eq 'x64') -and (-not [System.Environment]::Is64BitOperatingSystem) ) {
            Write-Debug 'Skipping due to Arch=x64 and non-64bit OS'
            continue
        }
        if (($record.Arch -eq 'x86') -and ([System.Environment]::Is64BitOperatingSystem) ) {
            Write-Debug 'Skipping due to Arch=x86 and 64bit OS'
            continue
        }
        try {
            # Read from registry
            if ($record.Arch -eq 'x64') {
                if ($record.Reg -eq '32') {
                    $regPath = ($regPrefix32 + $record.RegKey)
                }
                else {
                    $regPath = ($regPrefix64 + $record.RegKey)
                }
            }
            else {
                $regPath = ($regPrefix32 + $record.RegKey)
            }
            Write-Debug "Read registry key $regPath"
            $regValues = Get-ItemProperty $regPath
            Write-Host "Uninstalling $($regValues.DisplayName)"
            $cmd = $regValues.($record.RegValue)

            if ($record.Match) {
                # Transform using regex
                if ($cmd -notmatch $record.Match) {
                    throw "Error: Command $cmd does not match $($record.Match)"
                }
            }
            $file = Invoke-Expression "`"$($record.Command)`""
            Write-Debug "File: $file"
            $fileType = Invoke-Expression "`"$($record.FileType)`""
            Write-Debug "Filetype: $fileType"
            $silentArgs = Invoke-Expression "`"$($record.Args)`""
            Write-Debug "Args: $silentArgs"

            # Uninstall
            Uninstall-ChocolateyPackage -PackageName $packageName -File $file -FileType $fileType -SilentArgs $silentArgs | Out-Null
        }
        catch {
            Write-Warning "Failed: $_"
            continue
        }
    }
}

# Call Main
Main