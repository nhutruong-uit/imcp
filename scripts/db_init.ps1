# Khởi tạo CSDL QLTTTA (Windows, hoặc macOS/Linux có PowerShell 7): chạy lần lượt database\00..07 bằng sqlcmd.
#
# Cách dùng (PowerShell):
#   .\scripts\db_init.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\db_init.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\db_init.ps1 -User sa -Password "<mật khẩu>"   # SQL Server Authentication
#   .\scripts\db_init.ps1 -Docker sql2022                   # sqlcmd trong container Docker (mật khẩu sa: $env:SQL_PASSWORD)
# Mật khẩu có thể đặt trong biến môi trường SQL_PASSWORD thay cho -Password (không lộ trên dòng lệnh).
param(
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Password = "",
    [string]$Docker = ""
)
$ErrorActionPreference = "Stop"
$dbDir = Join-Path $PSScriptRoot "..\database"
$files = @("00_create_database.sql", "01_tables.sql", "02_functions.sql", "03_views.sql",
           "04_procedures.sql", "05_triggers.sql", "06_security.sql", "07_seed_data.sql")
if (-not $Password -and $env:SQL_PASSWORD) { $Password = $env:SQL_PASSWORD }
if ($Docker -and -not $User) { $User = "sa" }
if ($User -and -not $Password) { throw "Thiếu mật khẩu: dùng -Password hoặc biến môi trường SQL_PASSWORD." }

$matKhauCu = $env:SQLCMDPASSWORD
try {
    if ($User) { $env:SQLCMDPASSWORD = $Password }   # sqlcmd đọc mật khẩu từ biến này
    foreach ($f in $files) {
        $db = if ($f -like "00_*") { "master" } else { "QLTTTA" }
        Write-Host ">> $f"
        if ($Docker) {
            docker cp (Join-Path $dbDir $f) "${Docker}:/tmp/$f" | Out-Null
            docker exec -e SQLCMDPASSWORD $Docker /opt/mssql-tools18/bin/sqlcmd `
                -S localhost -U $User -C -I -b -f 65001 -d $db -i "/tmp/$f"
        } else {
            $sqlArgs = @("-S", $Server, "-d", $db, "-C", "-I", "-b", "-f", "65001", "-i", (Join-Path $dbDir $f))
            if ($User) { $sqlArgs += @("-U", $User) } else { $sqlArgs += "-E" }
            & sqlcmd @sqlArgs
        }
        if ($LASTEXITCODE -ne 0) { throw "Lỗi khi chạy $f" }
    }
} finally {
    $env:SQLCMDPASSWORD = $matKhauCu   # không để mật khẩu sa lại trong phiên PowerShell
}
Write-Host "Hoàn tất. CSDL QLTTTA đã sẵn sàng (tài khoản demo: xem docs\SETUP.md)."
