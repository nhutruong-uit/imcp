# Records the demo video of the application by itself (Windows, or macOS/Linux with PowerShell 7) - PowerShell version
# of record_demo.sh: builds tools\qlttta_demo_video, which signs in as the four demo accounts, plays through the
# screens and encodes docs\demo\QLTTTA_Demo_vi.mp4 with ffmpeg (how it works, what the video shows and how to change
# the story: docs\demo\README.md).
#
# Usage (PowerShell, in the repo folder):
#   .\scripts\record_demo.ps1                                  # Vietnamese video -> docs\demo\QLTTTA_Demo_vi.mp4
#   .\scripts\record_demo.ps1 -InitDb                          # load the seed data first (re-creates QLTTTA!), Windows Authentication
#   .\scripts\record_demo.ps1 -InitDb -User sa                 # ... SQL Server Authentication (password: $env:SQL_PASSWORD)
#   .\scripts\record_demo.ps1 -InitDb -Docker imcp-mssql       # ... sqlcmd inside a Docker container
#   .\scripts\record_demo.ps1 -Lang en -Out build\demo_en.mp4  # English video, written outside docs\
#   .\scripts\record_demo.ps1 -Chapters manager,teacher -Out build\try.mp4   # only some chapters (to try a change)
#
# -InitDb runs scripts\db_init.ps1 first: the demo changes a little data, and the seed dates are relative to the day
# it was loaded, so a fresh load gives the same video every time. Without it the database is used as it is.
# -Server is the SQL Server address of the application and of -InitDb (default "localhost"; $env:QLTTTA_SERVER
# overrides it for the application only). Demo account password: $env:QLTTTA_DEMO_PASSWORD (default as in
# docs\SETUP.md). -Preset selects the CMake preset (default windows-debug / macos-debug / linux-debug);
# $env:EXTRA_CMAKE_ARGS adds CMake arguments; $env:QLTTTA_FFMPEG names the ffmpeg program; QLTTTA_DEMO_FPS,
# QLTTTA_DEMO_SIZE and QLTTTA_DEMO_CRF are described in tools\demo_video_tool.cpp.
# Windows: needs ffmpeg (winget install Gyan.FFmpeg), $env:QT_ROOT_DIR and MinGW/Ninja/CMake on PATH as described in
# docs\SETUP.md. The sa password only travels in $env:SQL_PASSWORD (never as an argument).
param(
    [string]$Lang = "vi",
    [string]$Out = "",
    [string]$Chapters = "",
    [string]$Server = "localhost",
    [string]$User = "",
    [string]$Docker = "",
    [switch]$InitDb,
    [string]$Preset = ""
)
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Preset) { $Preset = if ($IsMacOS) { "macos-debug" } elseif ($IsLinux) { "linux-debug" } else { "windows-debug" } }
$ffmpeg = if ($env:QLTTTA_FFMPEG) { $env:QLTTTA_FFMPEG } else { "ffmpeg" }
if (-not (Get-Command $ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg was not found in PATH (Windows: winget install Gyan.FFmpeg; macOS: brew install ffmpeg)."
}

# Save the environment variables and restore them afterwards (nothing stays in the PowerShell session)
$previousEnv = @{}
foreach ($name in "QT_QPA_PLATFORM", "QLTTTA_SERVER", "QLTTTA_DEMO_PASSWORD", "QLTTTA_DEMO_LANG", "QLTTTA_DEMO_OUT",
                  "QLTTTA_DEMO_CHAPTERS", "PATH") {
    $previousEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
Push-Location $root   # the tool reads docs\demo\captions.tsv and writes docs\demo\ relative to the repository root
try {
    if ($InitDb) {
        Write-Host ""; Write-Host "==== Load the seed data ===="
        if ($Docker -and -not $User) { $User = "sa" }
        if ($User -and -not $env:SQL_PASSWORD) { throw "Missing password: set the SQL_PASSWORD environment variable." }
        & (Join-Path $PSScriptRoot "db_init.ps1") -Server $Server -User $User -Docker $Docker
    }

    Write-Host ""; Write-Host "==== Build the recording tool ===="
    $cmakeArgs = @("--preset", $Preset, "-DQLTTTA_BUILD_TOOLS=ON")
    if ($env:EXTRA_CMAKE_ARGS) { $cmakeArgs += ($env:EXTRA_CMAKE_ARGS -split ' ') }
    & cmake @cmakeArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "FAILED: cmake --preset $Preset" }
    & cmake --build --preset $Preset --target qlttta_demo_video
    if ($LASTEXITCODE -ne 0) { throw "FAILED: build" }
    # Qt puts the .exe of a MinGW build in the build folder itself, other builds under tools/
    $tool = Get-ChildItem -Path (Join-Path $root "build/$Preset") -Recurse -File |
        Where-Object { $_.Name -eq "qlttta_demo_video" -or $_.Name -eq "qlttta_demo_video.exe" } | Select-Object -First 1
    if (-not $tool) { throw "qlttta_demo_video was not built." }

    Write-Host ""; Write-Host "==== Record ===="
    if ($env:QT_ROOT_DIR) { $env:PATH = (Join-Path $env:QT_ROOT_DIR "bin") + [IO.Path]::PathSeparator + $env:PATH }   # Qt DLLs (Windows)
    $env:QT_QPA_PLATFORM = "offscreen"   # no window appears and no screen recording permission is needed
    if (-not $env:QLTTTA_SERVER) { $env:QLTTTA_SERVER = if ($Docker) { "localhost,1433" } else { $Server } }
    if (-not $env:QLTTTA_DEMO_PASSWORD) { $env:QLTTTA_DEMO_PASSWORD = "Demo@2026" }   # demo accounts, not a real password
    $env:QLTTTA_DEMO_LANG = $Lang
    if ($Out) { $env:QLTTTA_DEMO_OUT = $Out } else { Remove-Item Env:QLTTTA_DEMO_OUT -ErrorAction SilentlyContinue }
    if ($Chapters) { $env:QLTTTA_DEMO_CHAPTERS = $Chapters } else { Remove-Item Env:QLTTTA_DEMO_CHAPTERS -ErrorAction SilentlyContinue }
    & $tool.FullName
    if ($LASTEXITCODE -ne 0) { throw "FAILED: the recording tool stopped (exit code $LASTEXITCODE)." }

    $video = if ($Out) { $Out } else { "docs/demo/QLTTTA_Demo_$Lang.mp4" }
    $sizeMb = [math]::Round((Get-Item $video).Length / 1MB, 1)
    Write-Host ""
    Write-Host "Done: $video ($sizeMb MB). A video larger than 15 MB is too heavy for git: raise QLTTTA_DEMO_CRF or lower QLTTTA_DEMO_FPS."
} finally {
    Pop-Location
    foreach ($name in $previousEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnv[$name]) }
}
