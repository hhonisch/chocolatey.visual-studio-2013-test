#Requires -Version 5

param(
    # Store release meta info
    [Parameter(Mandatory = $true, ParameterSetName = 'StoreReleaseMetaInfo')]
    [switch] $StoreReleaseMetaInfo,
    # Store release notes
    [Parameter(Mandatory = $true, ParameterSetName = 'StoreReleaseNotes')]
    [switch] $StoreReleaseNotes,
    # Prepare VS install cache
    [Parameter(Mandatory = $true, ParameterSetName = 'PrepareInstallCache')]
    [switch] $PrepareInstallCache,
    # Working dir
    [Parameter(Mandatory = $true, ParameterSetName = 'PrepareInstallCache')]
    [string] $WorkingDir,
    # Cache dir
    [Parameter(Mandatory = $true, ParameterSetName = 'PrepareInstallCache')]
    [string] $CacheDir
)


# Terminate on exception
trap {
    Write-Host "Error: $_"
    Write-Host $_.ScriptStackTrace
    exit 1
}

# Always stop on errors
$ErrorActionPreference = 'Stop'

# Strict mode
Set-StrictMode -Version Latest



# Store release info in dist
function StoreReleaseMetaInfo() {
    Write-Host 'Store release meta info'
    $path = Join-Path $PSScriptRoot '..\dist\meta.json'

    # Read version
    $verXmlPath = Join-Path $PSScriptRoot version.xml
    Write-Host "Reading version from $verXmlPath..."
    [xml] $verXml = Get-Content $verXmlPath
    $verStr = $verXml.version

    # Get commit hash
    $commitHash = $env:GITHUB_SHA

    # Get run ID
    $runId = $env:GITHUB_RUN_ID

    # Write JSON to file
    Write-Host "Writing to $path..."
    $json = [ordered]@{ version = $verStr; commitHash = $commitHash; githubRunId = $runId }
    ConvertTo-Json $json -Compress | Out-File $path -Encoding ascii

    Write-Host 'Done: Store release meta info'
}


# Store release notes in dist
function StoreReleaseNotes() {
    Write-Host 'Store release notes'

    $srcPath = Join-Path $PSScriptRoot '..\RELEASE_NOTES.md'
    $dstPath = Join-Path $PSScriptRoot '..\dist\RELEASE_NOTES.md'
    Write-Host "Reading from $srcPath..."
    Write-Host "Writing to $dstPath..."
    [System.IO.StreamReader] $srcReader = $null
    [System.IO.StreamWriter] $dstWriter = $null
    try {
        $srcReader = [System.IO.StreamReader]::new($srcPath)
        $dstWriter = [System.IO.StreamWriter]::new($dstPath)
        while ($srcReader.EndOfStream -eq $false) {
            $line = $srcReader.ReadLine()
            if ($line -match '^\s*--- End of Release Notes ---\s*$') {
                break
            }
            $dstWriter.WriteLine($line)
        }

    }
    finally {
        if ($srcReader) {
            $srcReader.Close()
        }
        if ($dstWriter) {
            $dstWriter.Close()
        }
    }

    Write-Host 'Done: Store release notes'
}


# Get package parameters
function GetPackageParams($packageID, [ref]$packageParams) {
    # Load package parameters
    $paramsFile = Join-Path $PSScriptRoot 'package-params.csv'
    $records = Import-Csv -Path $paramsFile -Delimiter ';'

    # Get package params
    foreach ($record in $records) {
        if ($record.PackageId -eq $packageID) {
            $packageParams.Value = $record
            return
        }
    }

    # Not found
    throw "Package parameters not found for $PackageID"
}


# Get data of files in dir
function GetDirFileData([string] $dir, [bool] $readHash, [ref]$fileData) {
    # Get all files
    $files = Get-ChildItem "$dir" -Recurse -File

    # Process all files
    foreach ($file in $files) {
        # Determine relative path
        [string] $relPath = $file.FullName.Substring($dir.Length + 1)
        # Use lowercase relative path as hash key
        [string] $fileKey = $relPath.ToLowerInvariant()
        # Determin file hash if needed
        if ($readHash) {
            $fileHash = (Get-FileHash $file.FullName -Algorithm 'SHA256').Hash
        }
        else {
            $fileHash = $null
        }
        # Create file data object with all relevant data
        $fd = [PSCustomObject]@{
            Path = [string] $relPath
            Key  = [string] $fileKey
            Hash = $fileHash
            Size = $file.Length
            Flag = $false
        }
        $fileData.Value.Add($fileKey, $fd)
    }
}


# Prepare installer cache: Perform diff
function PrepareInstallCachePerformDiff([string] $newRoot, [string] $commonDir, [string] $cacheDiffPkgDir, [ref] $commonFileData, [ref] $otherPackages) {

    # Read files and hashes
    Write-Host "    Read file data from $newRoot"
    $newFileData = @{}
    GetDirFileData $newRoot $true ([ref]$newFileData)

    # Find files in "common" that don't match "new"
    [System.Collections.ArrayList] $removeList = [System.Collections.ArrayList]::new()
    foreach ($h in $commonFileData.Value.GetEnumerator() ) {
        [string] $commonFileKey = $h.Key
        $commonFd = $h.Value
        [bool] $isMatch = $false

        $newFd = $newFileData[$commonFileKey]
        # If file exist in "new" and size is equal and hash is equal
        if ($newFd -and ($newFd.Size -eq $h.Value.Size) -and ($newFd.Hash -eq $h.Value.Hash)) {
            # Set flag on new file data to indicate that file was processed
            $newFd.Flag = $true
            $isMatch = $true
        }

        # Found a diff file
        if (-not $isMatch) {
            $srcFilePath = Join-Path $commonDir $commonFd.Path

            # Remove file from common, copy to other package dirs
            [bool] $isFirst = $true
            foreach ($pkgData in $otherPackages.Value) {
                $destFilePath = Join-Path $pkgData.CacheDiffDir $commonFd.Path
                $destFileDir = Split-Path $destFilePath
                # Make sure dest dir exists
                if (-not (Test-Path $destFileDir)) {
                    mkdir $destFileDir | Out-Null
                }
                # Copy / move file
                if ($isFirst) {
                    Move-Item $srcFilePath $destFilePath
                    $srcFilePath = $destFilePath
                }
                else {
                    Copy-Item $srcFilePath $destFilePath
                }
                $isFirst = $false
            }

            # Add to remove list
            [void] $removeList.Add($commonFileKey)
        }
    }

    # Remove affected file keys
    foreach ($el in $removeList) {
        $commonFileData.Value.Remove($el)
    }

    # Find files in "new" that don't exist in "common"
    foreach ($h in $newFileData.GetEnumerator()) {
        $newFd = $h.Value
        # Process files where flag is not set, meaning that they are not processed yet
        if (-not $newFd.Flag) {
            $srcFilePath = Join-Path $newRoot $newFd.Path
            $destFilePath = Join-Path $cacheDiffPkgDir $newFd.Path
            $destFileDir = Split-Path $destFilePath
            # Make sure dest dir exists
            if (-not (Test-Path $destFileDir)) {
                mkdir $destFileDir | Out-Null
            }
            # Copy file
            Copy-Item $srcFilePath $destFilePath
        }
    }

}


# Remove empty directories
function RemoveEmptyDirs([string] $path) {
    $childItems = Get-ChildItem $path

    # Result: $true => dir is empty / $$false => not empty
    $result = $true
    foreach ($item in $childItems) {
        if ($item.PSIsContainer) {
            # Recurse into subdirs
            if (-not (RemoveEmptyDirs $item.FullName)) {
                $result = $false
            }
        }
        else {
            $result = $false
        }
    }
    if ($result) {
        Remove-Item $path
    }
    return $result
}


# Prepare Visual Studio 2013 installer cache
function PrepareInstallCache([string] $workingDir, [string] $cacheDir) {
    Write-Host 'Preparing VS 2013 install cache'

    # Load package parameters
    $paramsFile = Join-Path $PSScriptRoot 'package-params.csv'
    Write-Host "  Loading $paramsFile"
    $packageParams = Import-Csv -Path $paramsFile -Delimiter ';'

    # Create working dir
    if (-not (Test-Path $workingDir)) {
        Write-Host "  Creating working dir $workingDir"
        mkdir $workingDir | Out-Null
    }
    $workingDir = (Resolve-Path $workingDir).Path

    # Create cache dir
    if (-not (Test-Path $cacheDir)) {
        Write-Host "  Creating cache dir $cacheDir"
        mkdir $cacheDir | Out-Null
    }
    $cacheDir = (Resolve-Path $cacheDir).Path

    # Create empty common cache dir
    $cacheCommonDir = Join-Path $cacheDir 'common'
    if (Test-Path $cacheCommonDir) {
        Write-Host "  Remove existing cache common dir $cacheCommonDir"
        Remove-Item $cacheCommonDir -Recurse -Force
    }
    Write-Host "  Creating empty cache common dir $cacheCommonDir"
    mkdir $cacheCommonDir | Out-Null

    # List of processed packages
    [System.Collections.ArrayList] $processedPackages = [System.Collections.ArrayList]::new()

    # File data in cacheCommon
    $cacheCommonFileData = @{}

    # Process packages
    foreach ($pkgParam in $packageParams) {
        [string] $pkgId = $pkgParam.PackageId
        [string] $pkgIdShort = $pkgParam.ShortId
        Write-Host "  Processing package $pkgId"

        # Download ISO to working dir
        $isoDownloadUrl = $null
        $isoPath = $null
        if ((Test-Path variable:isoPaths) -and (Test-Path $isoPaths[$pkgIdShort])) {
            $isoPath = $isoPaths[$pkgIdShort]
            Write-Host "    Using $isoPath"
        }
        else {
            $p = Join-Path $workingDir "$pkgIdShort.iso"
            if (Test-Path $p) {
                $isoPath = $p
                Write-Host "    Using $isoPath"
            }
        }

        if (-not $isoPath) {
            $isoDownloadUrl = $pkgParam.DownloadUrl
            $isoPath = Join-Path $workingDir "$pkgIdShort.iso"
            Write-Host "    Downloading $isoDownloadUrl to $isoPath"
            & curl.exe -s -o $isoPath $isoDownloadUrl
        }

        # Verify checksum
        Write-Host '    Verify ISO checksum'
        $isoHash = Get-FileHash -Path $isoPath -Algorithm 'SHA256'
        if ($isoHash.Hash -ne $pkgParam.Checksum) {
            throw "    Checksum error for $isoPath`: expected: $($pkgParam.Checksum) ; actual: $($isoHash.Hash)"
        }

        # Create empty package diff cache dir
        [string] $cacheDiffPkgDir = Join-Path $cacheDir "$pkgId"
        if (Test-Path $cacheDiffPkgDir) {
            Write-Host "    Remove existing cache package diff dir $cacheDiffPkgDir"
            Remove-Item $cacheDiffPkgDir -Recurse -Force
        }
        Write-Host "    Creating empty cache package diff dir $cacheDiffPkgDir"
        mkdir $cacheDiffPkgDir | Out-Null

        # Mount iso
        $isoPathAbsolute = (Resolve-Path $isoPath).Path
        Write-Host "    Mounting $isoPathAbsolute"
        $mountResult = Mount-DiskImage $isoPathAbsolute -PassThru
        [string] $isoRoot = "$(($mountResult | Get-Volume).DriveLetter):"
        Write-Host "    ISO mounted to $isoRoot"

        if ($processedPackages.Count -eq 0) {
            # Initial package
            Write-Host "    Copy all files to $cacheCommonDir"
            Copy-Item "$isoRoot\*" -Destination "$cacheCommonDir\" -Force -Recurse | Out-Null

            # Read files and hashes
            Write-Host "    Read file data from $cacheCommonDir"
            GetDirFileData $cacheCommonDir $true ([ref]$cacheCommonFileData)
        }
        else {
            # Diff subsequent packages
            PrepareInstallCachePerformDiff $isoRoot $cacheCommonDir $cacheDiffPkgDir ([ref]$cacheCommonFileData) ([ref]$processedPackages)
        }

        # Add package to list
        $pkgData = [PSCustomObject]@{
            PackageId      = [string] $pkgId
            PackageShortId = [string] $pkgIdShort
            CacheDiffDir   = [string] $cacheDiffPkgDir
        }
        [void] $processedPackages.Add($pkgData)

        # Unmount iso
        Write-Host "    Dismounting $isoPathAbsolute"
        Dismount-DiskImage -ImagePath $isoPathAbsolute | Out-Null
        # Remnove if downloaded to save disk space
        if ($isoDownloadUrl) {
            Write-Host "    Removing $isoPath"
            Remove-Item $isoPath | Out-Null
        }
    }

    # Remove empty dirs from common
    RemoveEmptyDirs $cacheCommonDir | Out-Null
}


# Main function
function Main() {
    # Store release meta info
    if ($StoreReleaseMetaInfo) {
        StoreReleaseMetaInfo
    }

    # Store release notes
    if ($StoreReleaseNotes) {
        StoreReleaseNotes
    }

    # Prepare Visual Studio 2013 installer cache
    if ($PrepareInstallCache) {
        PrepareInstallCache $WorkingDir $CacheDir
    }

}


Main
