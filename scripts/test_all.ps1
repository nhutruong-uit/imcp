# Chạy TOÀN BỘ kiểm thử, dừng ngay khi có bước hỏng (dùng trước khi tạo PR) - bản PowerShell của test_all.sh:
#   1. Khởi tạo lại CSDL QLTTTA từ đầu (scripts\db_init.ps1) => dữ liệu mẫu luôn giống nhau
#   2. Kiểm thử CSDL: database\12_kiem_thu.sql (ràng buộc, nghiệp vụ, hàm/trigger/cursor, XML, phân quyền)
#   3. Build ứng dụng + unit test + kiểm thử end-to-end qua giao diện với CSDL thật (ctest)
#
# Cách dùng (PowerShell, tại thư mục repo):
#   .\scripts\test_all.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\test_all.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\test_all.ps1 -User sa -Password "<mật khẩu>"   # SQL Server Authentication
#   .\scripts\test_all.ps1 -Docker sql2022                   # SQL Server trong Docker (mật khẩu sa: $env:SQL_PASSWORD)
#   thêm -NoInit để bỏ qua bước 1; -Preset để chọn preset CMake (mặc định windows-debug / macos-debug)
# Windows: cần $env:QT_ROOT_DIR và PATH tới MinGW/Ninja/CMake như docs\SETUP.md.
# Mật khẩu tài khoản demo cho e2e: $env:QLTTTA_E2E_PASSWORD (mặc định như docs\SETUP.md).
param(
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Password = "",
    [string]$Docker = "",
    [switch]$NoInit,
    [string]$Preset = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # đọc đúng tiếng Việt từ sqlcmd -f 65001
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Preset) { $Preset = if ($IsMacOS) { "macos-debug" } else { "windows-debug" } }
if (-not $Password -and $env:SQL_PASSWORD) { $Password = $env:SQL_PASSWORD }
if ($Docker -and -not $User) { $User = "sa" }
if ($User -and -not $Password) { throw "Thiếu mật khẩu: dùng -Password hoặc biến môi trường SQL_PASSWORD." }

$ketQua = Join-Path $root "build/test-results"
New-Item -ItemType Directory -Force -Path $ketQua | Out-Null
function Buoc([string]$ten) { Write-Host ""; Write-Host "==== $ten ====" }

# Lưu biến môi trường để trả lại sau khi chạy (không để mật khẩu sa lại trong phiên PowerShell)
$bienCu = @{}
foreach ($ten in "SQLCMDPASSWORD", "QLTTTA_E2E_PASSWORD", "QLTTTA_SERVER") {
    $bienCu[$ten] = [Environment]::GetEnvironmentVariable($ten)
}
try {
    if (-not $env:QLTTTA_E2E_PASSWORD) { $env:QLTTTA_E2E_PASSWORD = "Demo@2026" }   # tài khoản demo, không phải mật khẩu thật
    if (-not $env:QLTTTA_SERVER) { $env:QLTTTA_SERVER = if ($Docker) { "localhost,1433" } else { $Server } }

    # 1. Khởi tạo lại CSDL
    if (-not $NoInit) {
        Buoc "1/3 Khởi tạo lại CSDL"
        & (Join-Path $PSScriptRoot "db_init.ps1") -Server $Server -User $User -Password $Password -Docker $Docker
    }

    # 2. Kiểm thử CSDL (file tự THROW khi có ca KHÔNG ĐẠT => sqlcmd -b trả mã lỗi)
    Buoc "2/3 Kiểm thử CSDL (database/12_kiem_thu.sql)"
    $fileSql = Join-Path $root "database/12_kiem_thu.sql"
    $fileKt = Join-Path $ketQua "kiem_thu_csdl.txt"
    if ($User) { $env:SQLCMDPASSWORD = $Password }
    if ($Docker) {
        docker cp $fileSql "${Docker}:/tmp/12_kiem_thu.sql" | Out-Null
        $dong = docker exec -e SQLCMDPASSWORD $Docker /opt/mssql-tools18/bin/sqlcmd `
            -S localhost -U $User -C -I -b -f 65001 -d QLTTTA -W -s "|" -i /tmp/12_kiem_thu.sql
    } else {
        $sqlArgs = @("-S", $Server, "-d", "QLTTTA", "-C", "-I", "-b", "-f", "65001", "-W", "-s", "|", "-i", $fileSql)
        if ($User) { $sqlArgs += @("-U", $User) } else { $sqlArgs += "-E" }
        $dong = & sqlcmd @sqlArgs
    }
    $maCsdl = $LASTEXITCODE
    $dong | Out-File -FilePath $fileKt -Encoding utf8
    $ca = @($dong | Where-Object { $_ -match '^[TP]\d{2}\|' })
    $dat = @($ca | Where-Object { $_ -match '\|ĐẠT\|' })
    Write-Host "Kết quả: $($dat.Count)/$($ca.Count) ca ĐẠT (chi tiết: build/test-results/kiem_thu_csdl.txt)"
    if ($maCsdl -ne 0) {
        $ca | Where-Object { $_ -notmatch '\|ĐẠT\|' } | ForEach-Object { Write-Host $_ }
        if ($ca.Count -eq 0) { $dong | Select-Object -Last 20 | ForEach-Object { Write-Host $_ } }
        throw "THẤT BẠI: kiểm thử CSDL có ca không đạt."
    }

    # 3. Build + unit test + e2e
    Buoc "3/3 Build, unit test và kiểm thử giao diện (ctest)"
    $logCauHinh = Join-Path $ketQua "cmake_configure.log"
    $cmakeArgs = @("--preset", $Preset)
    if ($env:EXTRA_CMAKE_ARGS) { $cmakeArgs += ($env:EXTRA_CMAKE_ARGS -split ' ') }
    & cmake @cmakeArgs | Out-File -FilePath $logCauHinh -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Get-Content $logCauHinh; throw "THẤT BẠI: cmake --preset $Preset" }
    & cmake --build --preset $Preset
    if ($LASTEXITCODE -ne 0) { throw "THẤT BẠI: build" }
    $junit = Join-Path $ketQua "ctest.xml"
    & ctest --preset $Preset --output-on-failure --output-junit $junit
    if ($LASTEXITCODE -ne 0) { throw "THẤT BẠI: có bài kiểm thử không đạt (ctest)." }

    # Không chấp nhận e2e bị SKIP âm thầm (vd quên mật khẩu, không kết nối được CSDL)
    if (Select-String -Path $junit -Pattern 'status="notrun"|<skipped' -Quiet) {
        throw "THẤT BẠI: có bài kiểm thử bị bỏ qua (SKIP) - kiểm tra kết nối CSDL / QLTTTA_E2E_PASSWORD."
    }
    Write-Host ""
    Write-Host "TẤT CẢ KIỂM THỬ ĐẠT: CSDL $($dat.Count)/$($ca.Count) ca, unit test + end-to-end qua giao diện đều đạt."
} finally {
    foreach ($ten in $bienCu.Keys) { [Environment]::SetEnvironmentVariable($ten, $bienCu[$ten]) }
}
