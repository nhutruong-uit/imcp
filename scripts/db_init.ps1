# Khởi tạo CSDL QLTTTA (Windows): chạy lần lượt database\00..07 bằng sqlcmd.
#
# Cách dùng (PowerShell):
#   .\scripts\db_init.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\db_init.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\db_init.ps1 -User sa -Password "<mật khẩu>"   # SQL Server Authentication
param(
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Password = ""
)
$ErrorActionPreference = "Stop"
$dbDir = Join-Path $PSScriptRoot "..\database"
$files = @("00_create_database.sql", "01_tables.sql", "02_functions.sql", "03_views.sql",
           "04_procedures.sql", "05_triggers.sql", "06_security.sql", "07_seed_data.sql")

foreach ($f in $files) {
    $db = if ($f -like "00_*") { "master" } else { "QLTTTA" }
    Write-Host ">> $f"
    $sqlArgs = @("-S", $Server, "-d", $db, "-C", "-I", "-b", "-f", "65001", "-i", (Join-Path $dbDir $f))
    if ($User) { $env:SQLCMDPASSWORD = $Password; $sqlArgs += @("-U", $User) } else { $sqlArgs += "-E" }
    & sqlcmd @sqlArgs
    if ($LASTEXITCODE -ne 0) { throw "Lỗi khi chạy $f" }
}
Write-Host "Hoàn tất. CSDL QLTTTA đã sẵn sàng (tài khoản demo: xem docs\SETUP.md)."
