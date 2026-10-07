# Builds the Windows installer - works on a personal machine and on GitHub Actions.
#   1. Release build (Qt + MinGW)
#   2. windeployqt: copies the Qt DLLs, plugins (including qsqlodbc) and the MinGW runtime
#   3. Portable ZIP (unzip and run) + setup.exe installer (Inno Setup, no admin rights needed)
#   4. Self-test of the portable ZIP as a user gets it: unzipped into a new folder, QLTTTA.exe --self-test checks
#      the Qt plugins, an ODBC driver for SQL Server, the translation and the icons (no database needed).
#      release.yml also installs the setup.exe silently and runs the same self-test on the installed app.
#
# Requirements: Qt 6 (MinGW 64-bit), CMake, Ninja on PATH; QT_ROOT_DIR pointing to the Qt folder,
#               e.g. C:\Qt\6.8.3\mingw_64. Inno Setup 6 (optional, for setup.exe).
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\package-windows.ps1                                  # Qt from $env:QT_ROOT_DIR
#   .\scripts\package-windows.ps1 -QtDir C:\Qt\6.8.3\mingw_64       # another Qt (also used by the CMake preset)
param(
    [string]$QtDir = $env:QT_ROOT_DIR
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Runs a packaged QLTTTA.exe with --self-test and waits for it. A .NET Process reads its output and exit code:
# PowerShell does not wait for a GUI program started directly
function Test-PackagedApp([string]$Exe) {
    $start = New-Object System.Diagnostics.ProcessStartInfo $Exe, "--self-test"
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $process = [System.Diagnostics.Process]::Start($start)
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    Write-Host $output
    if ($process.ExitCode -ne 0) { throw "The self-test of $Exe failed (exit code $($process.ExitCode))" }
}
# Run from a PowerShell window, the script works in the repository folder with the chosen Qt, then puts the
# window's folder and QT_ROOT_DIR back, also when a step fails
$previousLocation = Get-Location
$previousQt = $env:QT_ROOT_DIR
try {
    Set-Location $root

    if (-not $QtDir) { throw "Set QT_ROOT_DIR, e.g. `$env:QT_ROOT_DIR = 'C:\Qt\6.8.3\mingw_64'" }
    # The windows-release preset reads $env:QT_ROOT_DIR: build and deploy with the same Qt
    $env:QT_ROOT_DIR = $QtDir
    $version = (Select-String -Path CMakeLists.txt -Pattern '^\s*VERSION\s+([0-9.]+)').Matches[0].Groups[1].Value
    Write-Host ">> Release build (QLTTTA $version)"
    cmake --preset windows-release
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }
    cmake --build --preset windows-release
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }

    $stage = Join-Path $root "build\windows-release\stage\QLTTTA"
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force $stage | Out-Null
    # On Windows qt_standard_project_setup() puts every executable in the build folder itself (next to the DLLs)
    Copy-Item (Join-Path $root "build\windows-release\QLTTTA.exe") $stage

    Write-Host ">> windeployqt"
    # --no-translations: Qt's own catalogs are not needed (the app's translations are embedded as resources)
    & (Join-Path $QtDir "bin\windeployqt.exe") --release --compiler-runtime --no-translations `
        --no-system-d3d-compiler --no-opengl-sw (Join-Path $stage "QLTTTA.exe")
    if ($LASTEXITCODE -ne 0) { throw "windeployqt failed" }
    Copy-Item (Join-Path $root "packaging\windows\INSTALL.txt") $stage

    $dist = Join-Path $root "dist"
    New-Item -ItemType Directory -Force $dist | Out-Null
    $zip = Join-Path $dist "QLTTTA-$version-windows-x64-portable.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Write-Host ">> Create the portable ZIP"
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip

    Write-Host ">> Self-test of the portable ZIP"
    $unzipped = Join-Path $root "build\windows-release\selftest"
    if (Test-Path $unzipped) { Remove-Item -Recurse -Force $unzipped }
    Expand-Archive -Path $zip -DestinationPath $unzipped
    Test-PackagedApp (Join-Path $unzipped "QLTTTA.exe")

    # ISCC.exe on PATH, or in an Inno Setup 6 installed for all users (Program Files) or for the current user only
    # (%LOCALAPPDATA%\Programs: what "winget install JRSoftware.InnoSetup" does without administrator rights)
    $iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
    if (-not $iscc) {
        $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6", "$env:ProgramFiles\Inno Setup 6",
                  "$env:LOCALAPPDATA\Programs\Inno Setup 6") |
            ForEach-Object { Join-Path $_ "ISCC.exe" } | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if ($iscc) {
        Write-Host ">> Create the Inno Setup installer"
        & $iscc "/DAppVersion=$version" "/DSourceDir=$stage" "/DOutputDir=$dist" (Join-Path $root "packaging\windows\installer.iss")
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed" }
    } else {
        Write-Warning "Inno Setup 6 is not installed - only the portable ZIP was created."
    }
    Write-Host "Done. The output is in the dist\ folder"
} finally {
    Set-Location $previousLocation
    $env:QT_ROOT_DIR = $previousQt
}
