# Builds the Windows installer - works on a personal machine and on GitHub Actions.
#   1. Release build (Qt + MinGW)
#   2. windeployqt: copies the Qt DLLs, plugins (including qsqlodbc) and the MinGW runtime
#   3. Portable ZIP (unzip and run) + setup.exe installer (Inno Setup, no admin rights needed)
#
# Requirements: Qt 6 (MinGW 64-bit), CMake, Ninja on PATH; QT_ROOT_DIR pointing to the Qt folder,
#               e.g. C:\Qt\6.8.3\mingw_64. Inno Setup 6 (optional, for setup.exe).
param(
    [string]$QtDir = $env:QT_ROOT_DIR
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

if (-not $QtDir) { throw "Set QT_ROOT_DIR, e.g. `$env:QT_ROOT_DIR = 'C:\Qt\6.8.3\mingw_64'" }
$version = (Select-String -Path CMakeLists.txt -Pattern '^\s*VERSION\s+([0-9.]+)').Matches[0].Groups[1].Value
Write-Host ">> Release build (QLTTTA $version)"
cmake --preset windows-release
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }
cmake --build --preset windows-release
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

$stage = Join-Path $root "build\windows-release\stage\QLTTTA"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $root "build\windows-release\src\app\QLTTTA.exe") $stage

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

$iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) { $iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe" }
if (Test-Path $iscc) {
    Write-Host ">> Create the Inno Setup installer"
    & $iscc "/DAppVersion=$version" "/DSourceDir=$stage" "/DOutputDir=$dist" (Join-Path $root "packaging\windows\installer.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed" }
} else {
    Write-Warning "Inno Setup 6 is not installed - only the portable ZIP was created."
}
Write-Host "Done. The output is in the dist\ folder"
