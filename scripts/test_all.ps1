# Runs the WHOLE test suite and stops at the first failing step (before creating a PR) - PowerShell version of test_all.sh:
#   1. Change checks against origin/develop (scripts\check_changes.ps1): format of the changed C++ lines, commit
#      messages, no build output / .env in the repository
#   2. Re-initialize the QLTTTA database from scratch (scripts\db_init.ps1) => always the same seed data
#   3. Database tests: database\12_tests.sql (constraints, business rules, functions/triggers/cursors, XML,
#      permissions, naming and least-privilege rules)
#   4. Server-level tests: database\13_server_tests.sql (backup/restore, BULK INSERT, distributed database,
#      account lockout with real sign-ins) - needs sysadmin and the MSOLEDBSQL provider (SQL Server 2019+)
#   5. Build the application + unit tests (incl. tst_conventions) + end-to-end GUI tests against the database
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\test_all.ps1                                   # Windows Authentication, server "localhost"
#   .\scripts\test_all.ps1 -Server "localhost\SQLEXPRESS"    # SQL Server Express
#   .\scripts\test_all.ps1 -User sa                          # SQL Server Authentication (password: $env:SQL_PASSWORD)
#   .\scripts\test_all.ps1 -Docker imcp-mssql                # SQL Server in Docker (sa password: $env:SQL_PASSWORD)
#   add -NoInit to skip step 2; -ChangeBase sets the base branch of step 1 (default origin/develop); -Preset selects the CMake preset (default windows-debug / macos-debug / linux-debug)
#   Without -Docker the SQL Server service reads the sample CSV (BULK INSERT) from a copy in %ProgramData%\QLTTTA
#   (/tmp on macOS/Linux); $env:SQL_CSV_PATH overrides it with the file's path on the SQL Server machine.
# Windows: needs $env:QT_ROOT_DIR and MinGW/Ninja/CMake on PATH as described in docs\SETUP.md.
# Demo account password for the end-to-end tests: $env:QLTTTA_E2E_PASSWORD (default as in docs\SETUP.md).
# The sa password only travels in $env:SQL_PASSWORD (never as an argument: it would stay in the PowerShell history).
param(
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Docker = "",
    [switch]$NoInit,
    [string]$Preset = "",
    [string]$ChangeBase = "origin/develop"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # read the UTF-8 output of sqlcmd -f 65001 (Vietnamese names) correctly
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Preset) { $Preset = if ($IsMacOS) { "macos-debug" } elseif ($IsLinux) { "linux-debug" } else { "windows-debug" } }
$Password = $env:SQL_PASSWORD
if ($Docker -and -not $User) { $User = "sa" }
if ($User -and -not $Password) { throw "Missing password: set the SQL_PASSWORD environment variable." }

$results = Join-Path $root "build/test-results"
New-Item -ItemType Directory -Force -Path $results | Out-Null
function Step([string]$name) { Write-Host ""; Write-Host "==== $name ====" }

# Save the environment variables and restore them afterwards (never leave the sa password in the session)
$previousEnv = @{}
foreach ($name in "SQLCMDPASSWORD", "QLTTTA_E2E_PASSWORD", "QLTTTA_SERVER", "DatabaseDir", "CsvPath") {
    $previousEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    if (-not $env:QLTTTA_E2E_PASSWORD) { $env:QLTTTA_E2E_PASSWORD = "Demo@2026" }   # demo accounts, not a real password
    if (-not $env:QLTTTA_SERVER) { $env:QLTTTA_SERVER = if ($Docker) { "localhost,1433" } else { $Server } }

    # 1. Change checks (fast, so they come first)
    Step "1/5 Change checks (scripts/check_changes.ps1)"
    & (Join-Path $PSScriptRoot "check_changes.ps1") -Base $ChangeBase
    if ($LASTEXITCODE -ne 0) { throw "FAILED: change checks." }

    # 2. Re-initialize the database
    if (-not $NoInit) {
        Step "2/5 Re-initialize the database"
        & (Join-Path $PSScriptRoot "db_init.ps1") -Server $Server -User $User -Docker $Docker
    }

    # Runs a test script of database\ into build/test-results\<log> (extra = extra sqlcmd arguments) and stops
    # the suite when a case fails (the script THROWs => sqlcmd -b returns an error code)
    $dbPassed = 0
    $dbTotal = 0
    function Invoke-DbTests([string]$file, [string]$logName, [string[]]$extra) {
        $log = Join-Path $results $logName
        if ($User) { $env:SQLCMDPASSWORD = $Password }
        if ($Docker) {
            docker cp (Join-Path $root "database/$file") "${Docker}:/tmp/$file" | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "FAILED: could not copy $file into the container $Docker" }
            $lines = docker exec -e SQLCMDPASSWORD $Docker /opt/mssql-tools18/bin/sqlcmd `
                -S localhost -U $User -C -I -b -f 65001 -d QLTTTA -W -s "|" @extra -i "/tmp/$file"
        } else {
            $sqlArgs = @("-S", $Server, "-d", "QLTTTA", "-C", "-I", "-b", "-f", "65001", "-W", "-s", "|") + $extra +
                       @("-i", (Join-Path $root "database/$file"))
            if ($User) { $sqlArgs += @("-U", $User) } else { $sqlArgs += "-E" }
            $lines = & sqlcmd @sqlArgs
        }
        $exitCode = $LASTEXITCODE
        $lines | Out-File -FilePath $log -Encoding utf8
        # Verdict column of the summary table: PASSED / FAILED (case codes Txx, Pxx, Sxx)
        $cases = @($lines | Where-Object { $_ -match '^[TPS]\d{2,3}\|' })
        $passed = @($cases | Where-Object { $_ -match '\|PASSED\|' })
        Write-Host "Result: $($passed.Count)/$($cases.Count) cases passed (details: build/test-results/$logName)"
        if ($exitCode -ne 0) {
            $cases | Where-Object { $_ -notmatch '\|PASSED\|' } | ForEach-Object { Write-Host $_ }
            if ($cases.Count -eq 0) { $lines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ } }
            throw "FAILED: some test cases of database/$file failed."
        }
        $script:dbPassed += $passed.Count
        $script:dbTotal += $cases.Count
    }

    # 3. Database tests
    Step "3/5 Database tests (database/12_tests.sql)"
    Invoke-DbTests "12_tests.sql" "database_tests.txt" @()

    # 4. Server-level tests: 13_server_tests.sql includes 11_distributed_demo.sql (:r, read by sqlcmd) and
    #    BULK INSERTs the sample CSV (read by the SQL Server service, so the file must be on the server machine)
    Step "4/5 Server-level tests (database/13_server_tests.sql)"
    if ($Docker) {
        docker cp (Join-Path $root "database/11_distributed_demo.sql") "${Docker}:/tmp/11_distributed_demo.sql" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAILED: could not copy 11_distributed_demo.sql into the container $Docker" }
        docker cp (Join-Path $root "database/samples/student_import.csv") "${Docker}:/tmp/student_import.csv" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAILED: could not copy student_import.csv into the container $Docker" }
        Invoke-DbTests "13_server_tests.sql" "server_tests.txt" @("-v", "DatabaseDir=/tmp", "CsvPath=/tmp/student_import.csv")
    } else {
        $csvPath = $env:SQL_CSV_PATH
        if (-not $csvPath) {
            $csvDir = if ($IsMacOS -or $IsLinux) { "/tmp" } else { Join-Path $env:ProgramData "QLTTTA" }
            New-Item -ItemType Directory -Force -Path $csvDir | Out-Null
            $csvPath = Join-Path $csvDir "student_import.csv"
            Copy-Item (Join-Path $root "database/samples/student_import.csv") $csvPath -Force
        }
        # The two sqlcmd variables travel as environment variables (sqlcmd reads a variable of the same name):
        # sqlcmd of Windows cannot parse -v "DatabaseDir=<folder with a space>" (e.g. D:\My Projects\imcp)
        $env:DatabaseDir = Join-Path $root "database"
        $env:CsvPath = $csvPath
        Invoke-DbTests "13_server_tests.sql" "server_tests.txt" @()
    }

    # 5. Build + unit tests + end-to-end
    Step "5/5 Build, unit tests and GUI tests (ctest)"
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
    if (Select-String -Path $junit -Pattern 'status="notrun"|status="skipped"|<skipped' -Quiet) {
        throw "FAILED: some tests were skipped - check the database connection / QLTTTA_E2E_PASSWORD."
    }
    Write-Host ""
    Write-Host "ALL TESTS PASSED: database $dbPassed/$dbTotal cases (12_tests + 13_server_tests), unit tests + end-to-end GUI tests passed."
} finally {
    foreach ($name in $previousEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnv[$name]) }
}
