# Chocolatey Packages for Microsoft Visual Studio 2013

## Description
These [Chocolatey](https://chocolatey.org/) packages wrap the installation of various versions of Microsoft Visual Studio 2013.\
Visual Studio 2013 is an integrated development environment (IDE) from Microsoft.\

## Available Packages

Visual Studio 2013 Professional (initial release)
Visual Studio 2013 Professional with Update 1
Visual Studio 2013 Professional with Update 2
Visual Studio 2013 Professional with Update 3
Visual Studio 2013 Professional with Update 4
Visual Studio 2013 Professional with Update 5


## Package Parameters
The following package parameters can be set:

 * `/InstallDir:` - Directory where to install the Microsoft Help Workshop files - defaults to "`$env:ProgramFiles(x86)`" on 64 bit Windows and "`$env:ProgramFiles`" on 32 bit Windows
 * `/HcwSetupLocation:` - Location of Microsoft Help Workshop Setup (hcwsetup.exe) v4.03 - may be either a URL (http(s):// or file://) or a path.\
   If no location is specified, Help Workshop Setup is downloaded from "`https://download.microsoft.com/download/word97win/Utility/4.03/WIN98/EN-US/Hcwsetup.exe "`
 

To pass parameters, use `--params "''"` (e.g. `choco install help-workshop [other options] --params="'/InstallDir:C:\Help Workshop /HcwSetupLocation:C:\Temp\HcwSetup.exe'"`).\
To have choco remember parameters on upgrade, be sure to set `choco feature enable -n=useRememberedArgumentsForUpgrades`.

## Package Installation
To install the package with default parameters:

```
choco install help-workshop
```

To install the package with *different* parameters (example):

```
choco install help-workshop --params="'/InstallDir:C:\Help Workshop /HcwSetupLocation:C:\Temp\HcwSetup.exe'"
```

## Disclaimer
This Chocolatey Package only contains installation routines. The actual software is downloaded from the official source of the actual software vendor.\
The author of this package is not affiliated, associated, authorized, endorsed by, or in any way officially connected with the actual software vendor.

## Author
[Hartmut Honisch](https://github.com/hhonisch)

## License
This project is under the MIT License. For details, see the [license file](LICENSE.md).