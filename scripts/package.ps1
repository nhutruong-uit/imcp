# Builds the installer of the operating system it runs on - PowerShell version of package.sh:
#   Windows -> scripts\package-windows.ps1 => dist\QLTTTA-<version>-windows-x64-setup.exe + -portable.zip
#   macOS   -> scripts/package-macos.sh    => dist/QLTTTA-<version>-macos-<arch>.dmg (with PowerShell 7, pwsh)
#   Linux   -> no installer: the team ships macOS and Windows only
# The requirements are the ones of the platform script (docs\SETUP.md "Building installers"): Qt (MinGW), CMake and
# Ninja on Windows, plus Inno Setup 6 for setup.exe (without it only the portable .zip is built); Homebrew qt,
# qt-unixodbc, unixodbc, freetds, cmake and ninja on macOS.
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\package.ps1                                     # the Qt of $env:QT_ROOT_DIR (Windows) or of Homebrew (macOS)
#   .\scripts\package.ps1 -QtDir C:\Qt\6.8.3\mingw_64         # another Qt installation
#   powershell -ExecutionPolicy Bypass -File scripts\package.ps1   # when the execution policy blocks scripts
param(
    [string]$QtDir = ""
)
$ErrorActionPreference = "Stop"

# $IsWindows and $IsMacOS exist only in PowerShell 6+; Windows PowerShell 5.1 runs only on Windows
$onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
if ($onWindows) {
    # package-windows.ps1 throws on any failure; without -QtDir it reads $env:QT_ROOT_DIR itself
    $windowsScript = Join-Path $PSScriptRoot "package-windows.ps1"
    if ($QtDir) { & $windowsScript -QtDir $QtDir } else { & $windowsScript }
} elseif ($IsMacOS) {
    $previousQt = $env:QT_ROOT_DIR
    try {
        if ($QtDir) { $env:QT_ROOT_DIR = $QtDir }   # package-macos.sh reads the Qt folder from QT_ROOT_DIR
        & bash (Join-Path $PSScriptRoot "package-macos.sh")
        if ($LASTEXITCODE -ne 0) { throw "package-macos.sh failed (exit code $LASTEXITCODE)" }
    } finally {
        $env:QT_ROOT_DIR = $previousQt
    }
} else {
    throw "No installer for this operating system: build one on macOS (.dmg) or Windows (setup.exe, portable .zip)."
}
