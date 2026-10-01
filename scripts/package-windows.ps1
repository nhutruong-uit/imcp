# Đóng gói bản cài Windows - chạy được trên máy cá nhân lẫn GitHub Actions.
#   1. Build Release (Qt + MinGW)
#   2. windeployqt: chép Qt DLL, plugin (gồm qsqlodbc), runtime MinGW
#   3. Tạo bản ZIP portable (giải nén là chạy) + bộ cài setup.exe (Inno Setup, không cần quyền admin)
#
# Yêu cầu: Qt 6 (MinGW 64-bit), CMake, Ninja trong PATH; biến QT_ROOT_DIR trỏ tới thư mục Qt,
#          vd. C:\Qt\6.8.3\mingw_64. Inno Setup 6 (tùy chọn, để tạo setup.exe).
param(
    [string]$QtDir = $env:QT_ROOT_DIR
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

if (-not $QtDir) { throw "Hãy đặt biến QT_ROOT_DIR, vd: `$env:QT_ROOT_DIR = 'C:\Qt\6.8.3\mingw_64'" }
$version = (Select-String -Path CMakeLists.txt -Pattern '^\s*VERSION\s+([0-9.]+)').Matches[0].Groups[1].Value
Write-Host ">> Build Release (QLTTTA $version)"
cmake --preset windows-release
if ($LASTEXITCODE -ne 0) { throw "CMake configure lỗi" }
cmake --build --preset windows-release
if ($LASTEXITCODE -ne 0) { throw "Build lỗi" }

$stage = Join-Path $root "build\windows-release\stage\QLTTTA"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $root "build\windows-release\src\app\QLTTTA.exe") $stage

Write-Host ">> windeployqt"
& (Join-Path $QtDir "bin\windeployqt.exe") --release --compiler-runtime --no-translations `
    --no-system-d3d-compiler --no-opengl-sw (Join-Path $stage "QLTTTA.exe")
if ($LASTEXITCODE -ne 0) { throw "windeployqt lỗi" }
Copy-Item (Join-Path $root "packaging\windows\HUONG_DAN_CAI_DAT.txt") $stage

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "QLTTTA-$version-windows-x64-portable.zip"
if (Test-Path $zip) { Remove-Item $zip }
Write-Host ">> Tạo ZIP portable"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip

$iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) { $iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe" }
if (Test-Path $iscc) {
    Write-Host ">> Tạo bộ cài Inno Setup"
    & $iscc "/DAppVersion=$version" "/DSourceDir=$stage" "/DOutputDir=$dist" (Join-Path $root "packaging\windows\installer.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup lỗi" }
} else {
    Write-Warning "Chưa cài Inno Setup 6 - chỉ tạo bản ZIP portable."
}
Write-Host "Hoàn tất. Kết quả trong thư mục dist\"
