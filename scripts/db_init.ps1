# Initializes the QLTTTA database (Windows, or macOS/Linux with PowerShell 7): runs database\00..07 with sqlcmd.
#
# Usage (PowerShell):
#   .\scripts\db_init.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\db_init.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\db_init.ps1 -User sa -Password "<password>"   # SQL Server Authentication
#   .\scripts\db_init.ps1 -Docker sql2022                   # sqlcmd inside a Docker container (sa password: $env:SQL_PASSWORD)
# The password can be given in the SQL_PASSWORD environment variable instead of -Password (keeps it off the command line).
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
if ($User -and -not $Password) { throw "Missing password: use -Password or the SQL_PASSWORD environment variable." }

$previousPassword = $env:SQLCMDPASSWORD
try {
    if ($User) { $env:SQLCMDPASSWORD = $Password }   # sqlcmd reads the password from this variable
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
        if ($LASTEXITCODE -ne 0) { throw "Error while running $f" }
    }
} finally {
    $env:SQLCMDPASSWORD = $previousPassword   # never leave the sa password in the PowerShell session
}
Write-Host "Done. The QLTTTA database is ready (demo accounts: see docs\SETUP.md)."
