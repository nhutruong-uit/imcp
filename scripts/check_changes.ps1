# Checks the CHANGES of the current branch against its base branch - PowerShell version of check_changes.sh:
#   1. clang-format on the changed C++ lines only (git clang-format, version pinned in .clang-format-version)
#   2. commit messages: English Conventional Commits "type(scope): summary", no AI attribution lines
#   3. no build output (build/, dist/) or .env file in the repository
# File conventions (SQL syntax and headers, layers, scripts, numbers in the docs) are tested by tst_conventions.
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\check_changes.ps1                  # against origin/develop (git fetch first)
#   .\scripts\check_changes.ps1 -Base origin/main
# Exit code 1 when a check fails. A missing base (shallow clone, no remote) is reported as SKIPPED.
param([string]$Base = "origin/develop")
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # commit subjects may contain Vietnamese text
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root
$types = "feat|fix|test|docs|ci|build|refactor|style|chore|perf|revert"
$script:failed = $false
function Fail([string]$message) { Write-Host "FAILED: $message"; $script:failed = $true }
# Runs git with stderr merged into the output. Windows PowerShell 5.1 turns redirected stderr lines into errors,
# which "Stop" would make fatal (a missing base or git clang-format would end the script before its message), so
# the preference is relaxed for the call; callers check $LASTEXITCODE.
function Invoke-Git {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & git @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $previous }
}

$baseCommit = Invoke-Git merge-base HEAD $Base
if ($LASTEXITCODE -ne 0 -or -not $baseCommit) {
    Write-Host "SKIPPED: base '$Base' not found (shallow clone or no remote) - run 'git fetch origin' to check the changes."
    exit 0
}
$baseCommit = "$baseCommit".Trim()
Write-Host "Changes since $Base ($(git rev-parse --short $baseCommit)):"

# 1. Format of the changed C++ lines (committed and uncommitted; new files once they are git-added)
$wanted = (Get-Content (Join-Path $root ".clang-format-version") -Raw).Trim()
$clangFormat = Get-Command clang-format -ErrorAction SilentlyContinue
Invoke-Git clang-format -h | Out-Null
if (-not $clangFormat -or $LASTEXITCODE -ne 0) {
    Fail "clang-format / git clang-format not found (install LLVM, or pip install clang-format==$wanted)"
} else {
    $have = ((clang-format --version) -join " ") -replace '^.*?(\d+\.\d+\.\d+).*$', '$1'
    if ($have.Split(".")[0] -ne $wanted.Split(".")[0]) {
        Write-Host "WARNING: clang-format $have is installed, the team uses $wanted - the result may differ from CI."
    }
    # "h,cpp" quoted: unquoted, PowerShell would pass h and cpp as two arguments through the function
    $format = (Invoke-Git clang-format --diff --extensions "h,cpp" $baseCommit -- src tests tools) -join "`n"
    if ($format -match "no modified files to format|did not modify any files") {
        Write-Host "  format: changed C++ lines follow .clang-format"
    } else {
        Write-Host $format
        Fail "changed C++ lines are not formatted - run: git clang-format $baseCommit"
    }
}

# 2. Commit messages (merge commits excluded)
$commits = @(git rev-list --no-merges "$baseCommit..HEAD" | Where-Object { $_ })
foreach ($c in $commits) {
    $subject = (git log -1 --format=%s $c) -join ""
    $short = (git rev-parse --short $c) -join ""
    if ($subject -cnotmatch "^($types)(\([a-z0-9._-]+\))?!?: [^ ]") {
        Fail "$short `"$subject`": use `"type(scope): summary`" with type = $($types -replace '\|', ', ')"
    }
    if ($subject -match '[^\x20-\x7E]') {
        Fail "$short `"$subject`": the subject must be English (ASCII only)"
    }
    if ($subject.Length -gt 100) {
        Fail "${short}: the subject is longer than 100 characters"
    }
    $message = (git log -1 --format=%B $c) -join "`n"
    if ($message -match 'Co-Authored-By:.*(Claude|anthropic)|Generated with .*Claude') {
        Fail "${short}: remove the AI attribution line (team rule, see AGENTS.md)"
    }
}
Write-Host "  commits: $($commits.Count) checked"

# 3. Files that never belong in the repository
$tracked = @(git ls-files -- build dist) + @(git ls-files | Where-Object { $_ -match '(^|/)\.env$' })
$tracked = @($tracked | Where-Object { $_ })
if ($tracked.Count -gt 0) {
    $tracked | ForEach-Object { Write-Host $_ }
    Fail "build output or .env files are tracked - git rm --cached them"
}

if ($script:failed) { exit 1 }
Write-Host "Change checks passed."
