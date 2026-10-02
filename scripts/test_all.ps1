# Runs the WHOLE test suite and stops at the first failing step (before creating a PR) - PowerShell version of test_all.sh:
#   1. Re-initialize the QLTTTA database from scratch (scripts\db_init.ps1) => always the same seed data
#   2. Database tests: database\12_tests.sql (constraints, business rules, functions/triggers/cursors, XML, permissions)
#   3. Build the application + unit tests + end-to-end GUI tests against the real database (ctest)
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\test_all.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\test_all.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\test_all.ps1 -User sa -Password "<password>"   # SQL Server Authentication
#   .\scripts\test_all.ps1 -Docker sql2022                   # SQL Server in Docker (sa password: $env:SQL_PASSWORD)
#   add -NoInit to skip step 1; -Preset selects the CMake preset (default windows-debug / macos-debug)
# Windows: needs $env:QT_ROOT_DIR and MinGW/Ninja/CMake on PATH as described in docs\SETUP.md.
# Demo account password for the end-to-end tests: $env:QLTTTA_E2E_PASSWORD (default as in docs\SETUP.md).
param(
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Password = "",
    [string]$Docker = "",
    [switch]$NoInit,
    [string]$Preset = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # read the UTF-8 output of sqlcmd -f 65001 (Vietnamese names) correctly
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Preset) { $Preset = if ($IsMacOS) { "macos-debug" } else { "windows-debug" } }
if (-not $Password -and $env:SQL_PASSWORD) { $Password = $env:SQL_PASSWORD }
if ($Docker -and -not $User) { $User = "sa" }
if ($User -and -not $Password) { throw "Missing password: use -Password or the SQL_PASSWORD environment variable." }

$results = Join-Path $root "build/test-results"
New-Item -ItemType Directory -Force -Path $results | Out-Null
function Step([string]$name) { Write-Host ""; Write-Host "==== $name ====" }

# Save the environment variables and restore them afterwards (never leave the sa password in the session)
$previousEnv = @{}
foreach ($name in "SQLCMDPASSWORD", "QLTTTA_E2E_PASSWORD", "QLTTTA_SERVER") {
    $previousEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    if (-not $env:QLTTTA_E2E_PASSWORD) { $env:QLTTTA_E2E_PASSWORD = "Demo@2026" }   # demo accounts, not a real password
    if (-not $env:QLTTTA_SERVER) { $env:QLTTTA_SERVER = if ($Docker) { "localhost,1433" } else { $Server } }

    # 1. Re-initialize the database
    if (-not $NoInit) {
        Step "1/3 Re-initialize the database"
        & (Join-Path $PSScriptRoot "db_init.ps1") -Server $Server -User $User -Password $Password -Docker $Docker
    }

    # 2. Database tests (the script THROWs when a case fails => sqlcmd -b returns an error code)
    Step "2/3 Database tests (database/12_tests.sql)"
    $sqlFile = Join-Path $root "database/12_tests.sql"
    $dbLog = Join-Path $results "database_tests.txt"
    if ($User) { $env:SQLCMDPASSWORD = $Password }
    if ($Docker) {
        docker cp $sqlFile "${Docker}:/tmp/12_tests.sql" | Out-Null
        $lines = docker exec -e SQLCMDPASSWORD $Docker /opt/mssql-tools18/bin/sqlcmd `
            -S localhost -U $User -C -I -b -f 65001 -d QLTTTA -W -s "|" -i /tmp/12_tests.sql
    } else {
        $sqlArgs = @("-S", $Server, "-d", "QLTTTA", "-C", "-I", "-b", "-f", "65001", "-W", "-s", "|", "-i", $sqlFile)
        if ($User) { $sqlArgs += @("-U", $User) } else { $sqlArgs += "-E" }
        $lines = & sqlcmd @sqlArgs
    }
    $dbExit = $LASTEXITCODE
    $lines | Out-File -FilePath $dbLog -Encoding utf8
    # Verdict column of the summary table of 12_tests.sql: PASSED / FAILED
    $cases = @($lines | Where-Object { $_ -match '^[TP]\d{2}\|' })
    $passed = @($cases | Where-Object { $_ -match '\|PASSED\|' })
    Write-Host "Result: $($passed.Count)/$($cases.Count) cases passed (details: build/test-results/database_tests.txt)"
    if ($dbExit -ne 0) {
        $cases | Where-Object { $_ -notmatch '\|PASSED\|' } | ForEach-Object { Write-Host $_ }
        if ($cases.Count -eq 0) { $lines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ } }
        throw "FAILED: some database test cases failed."
    }

    # 3. Build + unit tests + end-to-end
    Step "3/3 Build, unit tests and GUI tests (ctest)"
    $configureLog = Join-Path $results "cmake_configure.log"
    $cmakeArgs = @("--preset", $Preset)
    if ($env:EXTRA_CMAKE_ARGS) { $cmakeArgs += ($env:EXTRA_CMAKE_ARGS -split ' ') }
    & cmake @cmakeArgs | Out-File -FilePath $configureLog -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Get-Content $configureLog; throw "FAILED: cmake --preset $Preset" }
    & cmake --build --preset $Preset
    if ($LASTEXITCODE -ne 0) { throw "FAILED: build" }
    $junit = Join-Path $results "ctest.xml"
    & ctest --preset $Preset --output-on-failure --output-junit $junit
    if ($LASTEXITCODE -ne 0) { throw "FAILED: some tests did not pass (ctest)." }

    # A silently skipped end-to-end test is not accepted (e.g. missing password, database unreachable)
    if (Select-String -Path $junit -Pattern 'status="notrun"|<skipped' -Quiet) {
        throw "FAILED: some tests were skipped - check the database connection / QLTTTA_E2E_PASSWORD."
    }
    Write-Host ""
    Write-Host "ALL TESTS PASSED: database $($passed.Count)/$($cases.Count) cases, unit tests + end-to-end GUI tests passed."
} finally {
    foreach ($name in $previousEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnv[$name]) }
}
