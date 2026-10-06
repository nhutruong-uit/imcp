# Sets up a development machine for QLTTTA in one command (Windows) - PowerShell version of setup_dev.sh:
#   1. Base tools (winget): Git (also gives Claude Code its bash), GitHub CLI, Python 3 + pipx
#   2. Build toolchain (aqtinstall, same as CI): Qt 6.8 MinGW, MinGW 13.1, CMake, Ninja in C:\Qt, then the user
#      variables QT_ROOT_DIR and PATH of docs\SETUP.md
#   3. clang-format of the team version (.clang-format-version, through pipx): check_changes and the Claude Code hook
#   4. SQL Server: the instance already installed (MSSQLSERVER, SQLEXPRESS) or a running Docker container; otherwise
#      SQL Server 2025 Developer (winget); sqlcmd (go-sqlcmd) when it is missing
#   5. Editor: the recommended VS Code extensions (.vscode\extensions.json), when VS Code is installed
#   6. Git: identity, origin/develop, GitHub CLI login (checked only - you do these yourself)
#   7. Verify: db_init.ps1, sign in as a demo account, then test_all.ps1
# Every step checks first and installs only what is missing, so it is safe to re-run. Steps that accept a license
# (SQL Server Developer, Microsoft ODBC Driver 18) only run with -AcceptLicenses. Windows asks for administrator
# rights (UAC) when an installer needs them. On macOS/Linux this script runs setup_dev.sh with the same options.
#
# Usage (PowerShell in the repo folder; -ExecutionPolicy Bypass because Windows blocks scripts by default):
#   powershell -ExecutionPolicy Bypass -File scripts\setup_dev.ps1 -Check            # report only, change nothing
#   powershell -ExecutionPolicy Bypass -File scripts\setup_dev.ps1 -AcceptLicenses   # set up everything
#   powershell -ExecutionPolicy Bypass -File scripts\setup_dev.ps1                   # open-source tools only
#   options: -Server <instance> (e.g. "localhost\SQLEXPRESS"), -Docker <container> (sa password: $env:SQL_PASSWORD
#            or read from the container), -WithMsOdbc (Microsoft ODBC Driver 18: SQL Server 2025 on this PC brings
#            it; needed with -Docker or a SQL Server on another PC, see docs\ARCHITECTURE.md section 6), -SkipTests
#            (stop before step 7), -QtDir (default C:\Qt)
# Demo account password for the tests: $env:QLTTTA_E2E_PASSWORD (default as in docs\SETUP.md).
# Exit code 0 when the machine is ready, 1 when a line of the summary needs attention.
param(
    [switch]$Check,
    [switch]$AcceptLicenses,
    [switch]$WithMsOdbc,
    [switch]$SkipTests,
    [string]$Server = "",
    [string]$Docker = "",
    [string]$QtDir = "C:\Qt"
)
$ErrorActionPreference = "Stop"

if ($IsMacOS -or $IsLinux) {
    $shArgs = @()
    if ($Check) { $shArgs += "--check" }
    if ($AcceptLicenses) { $shArgs += "--accept-licenses" }
    if ($WithMsOdbc) { $shArgs += "--with-msodbc" }
    if ($SkipTests) { $shArgs += "--skip-tests" }
    if ($Docker) { $shArgs += @("--container", $Docker) }
    & (Join-Path $PSScriptRoot "setup_dev.sh") @shArgs
    exit $LASTEXITCODE
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$preset = "windows-debug"
$qtVersion = "6.8.3"   # same Qt as the Windows job of .github\workflows\ci.yml
$qtRootDir = Join-Path $QtDir "$qtVersion\mingw_64"
$tools = @(
    @{ Name = "MinGW 13.1"; Tool = "tools_mingw1310"; Variant = "qt.tools.win64_mingw1310"; Bin = "Tools\mingw1310_64\bin"; Exe = "g++.exe" },
    @{ Name = "Ninja"; Tool = "tools_ninja"; Variant = "qt.tools.ninja"; Bin = "Tools\Ninja"; Exe = "ninja.exe" },
    @{ Name = "CMake"; Tool = "tools_cmake"; Variant = "qt.tools.cmake"; Bin = "Tools\CMake_64\bin"; Exe = "cmake.exe" }
)
$wanted = (Get-Content (Join-Path $root ".clang-format-version") -Raw).Trim()
$demoPassword = if ($env:QLTTTA_E2E_PASSWORD) { $env:QLTTTA_E2E_PASSWORD } else { "Demo@2026" }   # demo accounts, not a real password

$summary = New-Object System.Collections.Generic.List[string]
$script:notReady = $false
function Step([string]$name) { Write-Host ""; Write-Host "==== $name ====" }
# Report <status> <component> <detail>: OK / INSTALLED / WARN are fine, MISSING / SKIPPED / ACTION / FAILED are not
function Report([string]$status, [string]$name, [string]$detail) {
    $summary.Add(("{0,-9} {1,-24} {2}" -f $status, $name, $detail))
    if (@("OK", "INSTALLED", "WARN") -notcontains $status) { $script:notReady = $true }
}
function Test-Command([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
# Runs a native command and returns its exit code and output. Windows PowerShell 5.1 turns stderr lines into
# errors when they are redirected, so "Stop" is relaxed here.
function Invoke-Native([string]$exe, [string[]]$arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $exe @arguments 2>&1 | Out-String
        return @{ Code = $LASTEXITCODE; Text = $output }
    } catch {
        return @{ Code = 1; Text = $_.Exception.Message }
    } finally {
        $ErrorActionPreference = $previous
    }
}
# Installers change the PATH of new processes only: add their new folders to this session too
function Update-SessionPath {
    $current = @($env:Path -split ";" | Where-Object { $_ })
    $saved = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $added = @($saved -split ";" | Where-Object { $_ -and $current -notcontains $_ })
    $env:Path = ($current + $added) -join ";"
}
function Add-UserPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) { $parts = @($userPath -split ";" | Where-Object { $_ }) }
    if ($parts -notcontains $dir) { [Environment]::SetEnvironmentVariable("Path", (($parts + $dir) -join ";"), "User") }
    if (($env:Path -split ";") -notcontains $dir) { $env:Path = "$env:Path;$dir" }
}
# Install-Winget <id> <component> <command>: installs a winget package when <command> is missing
function Install-Winget([string]$id, [string]$name, [string]$command) {
    if (Test-Command $command) { Report "OK" $name (Get-Command $command).Source; return $true }
    if ($Check) { Report "MISSING" $name "winget install --id $id"; return $false }
    if (-not (Test-Command "winget")) { Report "SKIPPED" $name "needs winget"; return $false }
    Write-Host ">> winget install $id"
    & winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
    $code = $LASTEXITCODE
    Update-SessionPath
    if (Test-Command $command) { Report "INSTALLED" $name $id; return $true }
    Report "FAILED" $name "winget install --id $id (exit code $code)"
    return $false
}

# 1. Base tools
Step "1/7 Base tools"
if (Test-Command "winget") {
    Report "OK" "winget" "Windows Package Manager"
} else {
    Report "ACTION" "winget" "install 'App Installer' from the Microsoft Store, then re-run"
}
Install-Winget "Git.Git" "Git" "git" | Out-Null
Install-Winget "GitHub.cli" "GitHub CLI" "gh" | Out-Null

# Python: the "py" launcher, or a real python.exe (not the Microsoft Store alias in WindowsApps)
function Find-Python {
    if (Test-Command "py") { return @((Get-Command "py").Source, "-3") }
    $python = Get-Command "python" -ErrorAction SilentlyContinue
    if ($python -and $python.Source -notlike "*\WindowsApps\*") { return @($python.Source) }
    return @()
}
$python = @(Find-Python)
if ($python.Count -eq 0 -and -not $Check -and (Test-Command "winget")) {
    Write-Host ">> winget install Python.Python.3.12"
    & winget install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
    Update-SessionPath
    $python = @(Find-Python)
}
$pyExe = ""
$pyArgs = @()
if ($python.Count -gt 0) {
    $pyExe = $python[0]
    if ($python.Count -gt 1) { $pyArgs = @($python[1]) }
    Report "OK" "Python" $pyExe
} elseif ($Check) {
    Report "MISSING" "Python" "winget install --id Python.Python.3.12"
} elseif (-not (Test-Command "winget")) {
    Report "SKIPPED" "Python" "needs winget"
} else {
    Report "FAILED" "Python" "winget install --id Python.Python.3.12 failed"
}

# pipx runs Python tools (aqtinstall, clang-format) in their own environments; its commands go to ~\.local\bin
$pipxBin = Join-Path $env:USERPROFILE ".local\bin"
if (($env:Path -split ";") -notcontains $pipxBin) { $env:Path = "$env:Path;$pipxBin" }
$hasPipx = $false
if ($pyExe) {
    $hasPipx = (Invoke-Native $pyExe ($pyArgs + @("-m", "pipx", "--version"))).Code -eq 0
    if (-not $hasPipx -and -not $Check) {
        Write-Host ">> pip install --user pipx"
        & $pyExe @pyArgs -m pip install --user --upgrade pipx | Out-Host
        $hasPipx = (Invoke-Native $pyExe ($pyArgs + @("-m", "pipx", "--version"))).Code -eq 0
        if ($hasPipx) { & $pyExe @pyArgs -m pipx ensurepath | Out-Host }
    }
}
if ($hasPipx) { Report "OK" "pipx" "python -m pipx" }
elseif ($Check) { Report "MISSING" "pipx" "python -m pip install --user pipx" }
elseif (-not $pyExe) { Report "SKIPPED" "pipx" "needs Python" }
else { Report "FAILED" "pipx" "python -m pip install --user pipx failed" }
function Invoke-Pipx([string[]]$arguments) {
    & $pyExe @pyArgs -m pipx @arguments | Out-Host
    return $LASTEXITCODE -eq 0
}

# 2. Build toolchain: Qt, MinGW, CMake and Ninja from the Qt servers through aqtinstall (no Qt account needed)
Step "2/7 Build toolchain"
$toolchain = $true
$qtConfig = "lib\cmake\Qt6\Qt6Config.cmake"
if ($env:QT_ROOT_DIR -match "mingw" -and (Test-Path (Join-Path $env:QT_ROOT_DIR $qtConfig))) {
    $qtRootDir = $env:QT_ROOT_DIR   # a MinGW Qt installed before (e.g. with the Qt Online Installer)
    Report "OK" "Qt" "QT_ROOT_DIR=$qtRootDir"
} elseif (Test-Path (Join-Path $qtRootDir $qtConfig)) {
    Report "OK" "Qt" $qtRootDir
} elseif ($Check) {
    Report "MISSING" "Qt" "Qt $qtVersion MinGW in $QtDir"
    $toolchain = $false
} elseif (-not $hasPipx) {
    Report "SKIPPED" "Qt" "needs pipx"
    $toolchain = $false
} elseif (Invoke-Pipx @("run", "--spec", "aqtinstall", "aqt", "install-qt", "windows", "desktop", $qtVersion, "win64_mingw", "-O", $QtDir)) {
    Report "INSTALLED" "Qt" $qtRootDir
} else {
    Report "FAILED" "Qt" "aqt install-qt windows desktop $qtVersion win64_mingw failed"
    $toolchain = $false
}
foreach ($t in $tools) {
    $bin = Join-Path $QtDir $t.Bin
    if (Test-Path (Join-Path $bin $t.Exe)) {
        Report "OK" $t.Name $bin
    } elseif ($Check) {
        Report "MISSING" $t.Name "$($t.Tool) in $QtDir\Tools"
        $toolchain = $false
        continue
    } elseif (-not $hasPipx) {
        Report "SKIPPED" $t.Name "needs pipx"
        $toolchain = $false
        continue
    } elseif (Invoke-Pipx @("run", "--spec", "aqtinstall", "aqt", "install-tool", "windows", "desktop", $t.Tool, $t.Variant, "-O", $QtDir)) {
        Report "INSTALLED" $t.Name $bin
    } else {
        Report "FAILED" $t.Name "aqt install-tool windows desktop $($t.Tool) failed"
        $toolchain = $false
        continue
    }
    if (-not $Check) { Add-UserPath $bin }
}
if ($toolchain -and -not $Check) {
    # Qt's bin folder: the tests and the app load the Qt DLLs from PATH (CI's install-qt-action does the same)
    Add-UserPath (Join-Path $qtRootDir "bin")
    if ($env:QT_ROOT_DIR -ne $qtRootDir) {
        [Environment]::SetEnvironmentVariable("QT_ROOT_DIR", $qtRootDir, "User")   # read by CMakePresets.json
        $env:QT_ROOT_DIR = $qtRootDir
        Report "INSTALLED" "QT_ROOT_DIR" "$qtRootDir (user variable)"
    }
}

if ($WithMsOdbc) {
    $odbc18 = Get-OdbcDriver -Name "ODBC Driver 18 for SQL Server" -Platform "64-bit" -ErrorAction SilentlyContinue
    if ($odbc18) { Report "OK" "ODBC Driver 18" "Microsoft ODBC Driver 18 for SQL Server" }
    elseif ($Check) { Report "MISSING" "ODBC Driver 18" "winget install --id Microsoft.msodbcsql.18" }
    elseif (-not $AcceptLicenses) { Report "SKIPPED" "ODBC Driver 18" "needs -AcceptLicenses (Microsoft ODBC Driver license)" }
    else {
        & winget install --id Microsoft.msodbcsql.18 --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
        if ($LASTEXITCODE -eq 0) { Report "INSTALLED" "ODBC Driver 18" "Microsoft.msodbcsql.18" }
        else { Report "FAILED" "ODBC Driver 18" "winget install --id Microsoft.msodbcsql.18 (exit code $LASTEXITCODE)" }
    }
}

# 3. clang-format of the team version, the same pip package as CI (a different major version formats differently)
Step "3/7 clang-format"
function Get-ClangFormatVersion {
    if (-not (Test-Command "clang-format")) { return "" }
    $result = Invoke-Native "clang-format" @("--version")
    if ($result.Text -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
    return ""
}
function Test-ClangFormat {
    $have = Get-ClangFormatVersion
    if (-not $have -or $have.Split(".")[0] -ne $wanted.Split(".")[0]) { return $false }
    return (Invoke-Native "git" @("clang-format", "-h")).Code -eq 0
}
$found = Get-ClangFormatVersion
if (Test-ClangFormat) {
    Report "OK" "clang-format" "$found ($((Get-Command clang-format).Source))"
} elseif ($Check) {
    $detail = "team version $wanted"
    if ($found) { $detail += ", found $found" }
    Report "MISSING" "clang-format" $detail
} elseif (-not $hasPipx) {
    Report "SKIPPED" "clang-format" "needs pipx"
} elseif ((Invoke-Pipx @("install", "--force", "clang-format==$wanted")) -and (Test-ClangFormat)) {
    Add-UserPath $pipxBin   # new terminals and the Claude Code hook find clang-format too
    Report "INSTALLED" "clang-format" "$wanted (pipx, $pipxBin)"
} else {
    $detail = "pipx install clang-format==$wanted"
    if (Test-Command "clang-format") { $detail += "; $((Get-Command clang-format).Source) ($(Get-ClangFormatVersion)) comes first on PATH" }
    Report "FAILED" "clang-format" $detail
}

# 4. SQL Server: -Docker, -Server, an installed instance, a running Docker container, else SQL Server 2025 Developer.
#    Not 2022: Microsoft retired its 2022 web installer (the winget package still points to it and it stops with
#    "This version of the installer is no longer supported"). The database scripts use 2012+ syntax; the Docker
#    container (docker-compose.yml) and CI run SQL Server 2025 too.
Step "4/7 SQL Server"
$sqlPackage = "Microsoft.SQLServer.2025.Developer"
$sqlReady = $false
$saPassword = $env:SQL_PASSWORD
function Find-Instance {
    if (Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue) { return "localhost" }
    if (Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue) { return "localhost\SQLEXPRESS" }
    return ""
}
if (-not $Docker -and -not $Server) { $Server = Find-Instance }
if (-not $Docker -and -not $Server -and (Test-Command "docker") -and (Invoke-Native "docker" @("info")).Code -eq 0) {
    $running = (Invoke-Native "docker" @("ps", "--format", "{{.Names}} {{.Image}}")).Text -split "`r?`n" |
        Where-Object { $_ -match '^(\S+) \S*mssql/server' } | Select-Object -First 1
    if ($running -match '^(\S+) ') { $Docker = $Matches[1] }
}

if (-not $Docker -and -not $Server) {
    if ($Check) {
        Report "MISSING" "SQL Server" "winget install --id $sqlPackage"
    } elseif (-not $AcceptLicenses) {
        Report "SKIPPED" "SQL Server" "needs -AcceptLicenses (SQL Server Developer Edition license)"
    } elseif (-not (Test-Command "winget")) {
        Report "SKIPPED" "SQL Server" "needs winget"
    } else {
        # Downloads about 1.5 GB; Windows asks for administrator rights, the installing account becomes sysadmin
        Write-Host ">> winget install $sqlPackage (10-30 minutes)"
        & winget install --id $sqlPackage --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
        $code = $LASTEXITCODE
        Update-SessionPath
        $Server = Find-Instance
        if ($code -eq 3010) { Report "ACTION" "SQL Server" "installed, restart Windows, then re-run this script"; $Server = "" }
        elseif ($Server) { Report "INSTALLED" "SQL Server" "SQL Server 2025 Developer ($Server)" }
        else { Report "FAILED" "SQL Server" "winget install --id $sqlPackage (exit code $code)" }
    }
}

if ($Docker) {
    if (-not $saPassword) {
        $read = Invoke-Native "docker" @("exec", $Docker, "printenv", "MSSQL_SA_PASSWORD")
        if ($read.Code -eq 0) { $saPassword = $read.Text.Trim() }
    }
    $previousPassword = $env:SQLCMDPASSWORD
    try {
        $env:SQLCMDPASSWORD = $saPassword
        $probe = Invoke-Native "docker" @("exec", "-e", "SQLCMDPASSWORD", $Docker, "/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-C", "-l", "10", "-Q", "SELECT 1")
    } finally {
        $env:SQLCMDPASSWORD = $previousPassword
    }
    if (-not $saPassword) { Report "ACTION" "SQL Server container" "cannot read the sa password of ${Docker}: set `$env:SQL_PASSWORD and re-run" }
    elseif ($probe.Code -eq 0) { $sqlReady = $true; Report "OK" "SQL Server container" "$Docker, signed in as sa" }
    else { Report "FAILED" "SQL Server container" "cannot sign in as sa to $Docker (docker ps -a, docker logs $Docker)" }
} elseif ($Server) {
    $instanceName = if ($Server -match '\\(.+)$') { 'MSSQL$' + $Matches[1] } else { "MSSQLSERVER" }
    $service = Get-Service -Name $instanceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne "Running") {
        Report "ACTION" "SQL Server service" "$instanceName is stopped: start it in services.msc (needs administrator rights)"
    }
    if (-not (Test-Command "sqlcmd")) { Install-Winget "Microsoft.Sqlcmd" "sqlcmd" "sqlcmd" | Out-Null }
    if (Test-Command "sqlcmd") {
        # Windows Authentication: the account that installed SQL Server is sysadmin (needed by 13_server_tests.sql)
        $probe = Invoke-Native "sqlcmd" @("-S", $Server, "-E", "-C", "-l", "10", "-h", "-1", "-W", "-Q", "SET NOCOUNT ON; SELECT IS_SRVROLEMEMBER('sysadmin')")
        if ($probe.Code -ne 0) { Report "FAILED" "SQL Server" "cannot connect to $Server with Windows Authentication" }
        elseif ($probe.Text.Trim() -ne "1") { Report "ACTION" "SQL Server" "your Windows account is not sysadmin on $Server (server-level tests need it)" }
        else { $sqlReady = $true; Report "OK" "SQL Server" "$Server, Windows Authentication, sysadmin" }
    }
}

# 5. Editor extensions (clangd, CMake Tools, SQL Server); Microsoft C/C++ conflicts with clangd (docs\CONTRIBUTING.md)
Step "5/7 Editor"
function Get-Extensions([string]$key) {
    $text = Get-Content (Join-Path $root ".vscode\extensions.json") -Raw
    if ($text -notmatch ('"' + $key + '"\s*:\s*\[([^\]]*)\]')) { return @() }
    return @([regex]::Matches($Matches[1], '"([A-Za-z0-9-]+\.[A-Za-z0-9.-]+)"') | ForEach-Object { $_.Groups[1].Value })
}
if (Test-Command "code") {
    $haveExt = @((Invoke-Native "code" @("--list-extensions")).Text -split "`r?`n" | ForEach-Object { $_.Trim().ToLower() })
    $newExt = @(Get-Extensions "recommendations" | Where-Object { $haveExt -notcontains $_.ToLower() })
    if ($newExt.Count -eq 0) { Report "OK" "VS Code extensions" ((Get-Extensions "recommendations") -join " ") }
    elseif ($Check) { Report "MISSING" "VS Code extensions" ($newExt -join " ") }
    else {
        foreach ($ext in $newExt) { Invoke-Native "code" @("--install-extension", $ext) | Out-Null }
        Report "INSTALLED" "VS Code extensions" ($newExt -join " ")
    }
    foreach ($ext in (Get-Extensions "unwantedRecommendations")) {
        if ($haveExt -contains $ext.ToLower()) { Report "WARN" "VS Code extensions" "$ext conflicts with clangd: code --uninstall-extension $ext" }
    }
} else {
    Report "WARN" "VS Code" "not found - skipped (Qt Creator or Cursor also work)"
}

# 6. Git and GitHub (identity and login belong to you, so they are only checked)
Step "6/7 Git and GitHub"
if (Test-Command "git") {
    $name = (Invoke-Native "git" @("-C", $root, "config", "user.name")).Text.Trim()
    $email = (Invoke-Native "git" @("-C", $root, "config", "user.email")).Text.Trim()
    if ($name -and $email) { Report "OK" "git identity" "$name <$email>" }
    else { Report "ACTION" "git identity" 'git config --global user.name "Your Name"; git config --global user.email <email>' }
    $hasBase = (Invoke-Native "git" @("-C", $root, "rev-parse", "--verify", "-q", "origin/develop")).Code -eq 0
    if (-not $hasBase -and -not $Check) {
        Invoke-Native "git" @("-C", $root, "fetch", "-q", "origin") | Out-Null
        $hasBase = (Invoke-Native "git" @("-C", $root, "rev-parse", "--verify", "-q", "origin/develop")).Code -eq 0
    }
    if ($hasBase) { Report "OK" "origin/develop" "base branch of check_changes" }
    else { Report "MISSING" "origin/develop" "git fetch origin" }
}
if (Test-Command "gh") {
    if ((Invoke-Native "gh" @("auth", "status")).Code -eq 0) { Report "OK" "GitHub CLI login" "used by /imcp-create-pr and /imcp-review" }
    else { Report "ACTION" "GitHub CLI login" "gh auth login --web --git-protocol https" }
}

# 7. Verify: database init, a demo sign-in, then the full test suite (the command every PR needs)
Step "7/7 Verify"
$tested = $false
if ($Check -or $SkipTests) {
    Write-Host "Not run (-Check / -SkipTests)."
} elseif (-not $toolchain -or -not $sqlReady -or -not (Test-ClangFormat)) {
    Report "SKIPPED" "scripts\test_all.ps1" "fix the lines above first"
} else {
    $previousEnv = @{}
    foreach ($var in "SQL_PASSWORD", "SQLCMDPASSWORD", "QLTTTA_E2E_PASSWORD") { $previousEnv[$var] = [Environment]::GetEnvironmentVariable($var) }
    try {
        $env:QLTTTA_E2E_PASSWORD = $demoPassword
        if ($Docker) {
            $env:SQL_PASSWORD = $saPassword
            & (Join-Path $PSScriptRoot "db_init.ps1") -Docker $Docker
            $env:SQLCMDPASSWORD = $demoPassword
            $login = Invoke-Native "docker" @("exec", "-e", "SQLCMDPASSWORD", $Docker, "/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", "-U", "ql_quan", "-d", "QLTTTA", "-C", "-l", "10", "-Q", "SELECT 1")
        } else {
            & (Join-Path $PSScriptRoot "db_init.ps1") -Server $Server
            $env:SQLCMDPASSWORD = $demoPassword
            $login = Invoke-Native "sqlcmd" @("-S", $Server, "-d", "QLTTTA", "-U", "ql_quan", "-C", "-l", "10", "-Q", "SELECT 1")
        }
        $env:SQLCMDPASSWORD = $previousEnv["SQLCMDPASSWORD"]
        if ($login.Code -ne 0) {
            # Contained database users sign in with SQL Server Authentication: an instance installed with Windows
            # Authentication only rejects them
            Report "ACTION" "Demo sign-in" "ql_quan cannot sign in: turn on 'SQL Server and Windows Authentication mode' (SSMS > server Properties > Security, or the sqlcmd command of docs\SETUP.md section 1), restart the service, re-run"
        } elseif ($Docker) {
            & (Join-Path $PSScriptRoot "test_all.ps1") -Docker $Docker -NoInit
            Report "OK" "scripts\test_all.ps1" "ALL TESTS PASSED (database, server-level, unit and end-to-end tests)"
            $tested = $true
        } else {
            & (Join-Path $PSScriptRoot "test_all.ps1") -Server $Server -NoInit
            Report "OK" "scripts\test_all.ps1" "ALL TESTS PASSED (database, server-level, unit and end-to-end tests)"
            $tested = $true
        }
    } catch {
        Write-Host $_.Exception.Message
        Report "FAILED" "Verify" "$($_.Exception.Message) (see the output above and build\test-results\)"
    } finally {
        foreach ($var in $previousEnv.Keys) { [Environment]::SetEnvironmentVariable($var, $previousEnv[$var]) }
    }
}

Step "Summary"
foreach ($line in $summary) { Write-Host "  $line" }
if ($script:notReady) {
    Write-Host ""
    Write-Host "Not ready yet: handle the MISSING / SKIPPED / ACTION / FAILED lines, then re-run scripts\setup_dev.ps1"
    exit 1
}
if (-not $tested) { Write-Host "Tools are in place; the test suite was not run." }
$testCommand = if ($Docker) { ".\scripts\test_all.ps1 -Docker $Docker   # sa password in `$env:SQL_PASSWORD" } else { ".\scripts\test_all.ps1 -Server `"$Server`"" }
Write-Host ""
Write-Host "Ready. Open a NEW terminal (PATH and QT_ROOT_DIR changed), then:"
Write-Host "  Run the app:      .\build\$preset\QLTTTA.exe   (demo accounts: docs\SETUP.md)"
Write-Host "  Before every PR:  $testCommand"
Write-Host "  Then read:        AGENTS.md, docs\CONTRIBUTING.md, docs\ARCHITECTURE.md (reference module: Students)"
