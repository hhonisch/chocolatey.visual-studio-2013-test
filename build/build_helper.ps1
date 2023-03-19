#Requires -Version 5

param(
    # Generate package files
    [Parameter(Mandatory = $true, ParameterSetName = 'GeneratePackageFiles')]
    [switch] $GeneratePackageFiles,
    # Package ID
    [Parameter(Mandatory = $true, ParameterSetName = 'GeneratePackageFiles')]
    [string] $PackageID,
    # Package dir
    [Parameter(Mandatory = $true, ParameterSetName = 'GeneratePackageFiles')]
    [string] $PackageDir,
    # Package version
    [Parameter(Mandatory = $true, ParameterSetName = 'GeneratePackageFiles')]
    [string] $PackageVersion
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


# Generate package files
function GeneratePackageFiles($packageID, $packageDir, $packageVersion) {
    Write-Host "Generating Chocolatey package files in $packageDir..."

    # Get package parameters
    $packageParams = $null
    GetPackageParams $packageID ([ref] $packageParams)
    $toolsDir = Join-Path $packageDir 'tools'

    # Create nuspec file
    $nuspecTemplatePath = Join-Path $packageDir 'visual-studio-2013.nuspec.template'
    $nuspecPath = Join-Path $packageDir "$packageID.nuspec"
    Write-Host "  Generating $nuspecPath from $nuspecTemplatePath..."
    [xml] $nuspecXml = Get-Content $nuspecTemplatePath
    $nuspecXml.package.metadata.id = $packageID
    $nuspecXml.package.metadata.version = $packageVersion
    $nuspecXml.package.metadata.title = $packageParams.Name
    $nuspecXml.package.metadata.licenseUrl = $nuspecXml.package.metadata.licenseUrl -replace '%VS_PACKAGE_ID_SHORT%', $packageParams.ShortId
    $nuspecXml.package.metadata.tags = "$($nuspecXml.package.metadata.tags) $($packageParams.Tags)"
    $str = $nuspecXml.package.metadata.description
    $str = $str -replace '%VS_DOWNLOAD_URL%', $packageParams.DownloadUrl
    $str = $str -replace '%VS_PACKAGE_ID%', $packageID
    $nuspecXml.package.metadata.description = $str
    $nuspecXml.Save($nuspecPath)

    # Create PackageData.xml
    $pkgDataSrc = Join-Path $toolsDir "PackageData.$($packageParams.ShortId).xml"
    $pkgDataDest = Join-Path $toolsDir 'PackageData.xml'
    Write-Host "  Generating $pkgDataDest from $pkgDataSrc..."
    [xml] $packageDataXml = Get-Content $pkgDataSrc
    $packageDataXml.PackageData.IsoDownloadUrl = $packageParams.DownloadUrl
    $packageDataXml.PackageData.IsoChecksum = $packageParams.Checksum
    $packageDataXml.Save($pkgDataDest)

    # Create AdminDeployment.xml
    $admDataSrc = Join-Path $toolsDir "AdminDeployment.$($packageParams.ShortId).xml"
    $admDataDest = Join-Path $toolsDir 'AdminDeployment.xml'
    Write-Host "  Generating $admDataDest from $admDataSrc..."
    Copy-Item $admDataSrc $admDataDest -Force

}


# Main function
function Main {
    # Generate package files
    if ($GeneratePackageFiles) {
        GeneratePackageFiles $PackageID $PackageDir $PackageVersion
    }
    else {
        throw 'Nothing to do'
    }
}


Main
