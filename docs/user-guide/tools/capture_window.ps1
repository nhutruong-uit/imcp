# Captures one window into docs\user-guide\images\windows\<name>.png - the screenshots of the user guide that
# tools\qlttta_screenshots cannot take (installers, SQL Server tools, Docker Desktop, SmartScreen). The guide shows
# the image instead of its yellow placeholder on the next build_user_guide.py run.
#
# Usage (PowerShell, in the repo folder):
#   .\docs\user-guide\tools\capture_window.ps1 -List                         # images the guide expects, done or missing
#   .\docs\user-guide\tools\capture_window.ps1 -Name ssms_run_script         # 5 s countdown: click the window to capture
#   .\docs\user-guide\tools\capture_window.ps1 -Name x -Delay 10             # more time to bring the window to the front
#   .\docs\user-guide\tools\capture_window.ps1 -Name x -Title "^Setup - "    # the window whose title matches (no click)
#   then: py docs\user-guide\build_user_guide.py   (the image replaces its placeholder)
#   powershell -ExecutionPolicy Bypass -File docs\user-guide\tools\capture_window.ps1 ...   # when scripts are blocked
# Only the window is saved (no desktop, no other windows), at the screen's real resolution. A window that needs
# administrator rights (SQL Server Configuration Manager, a UAC prompt) is opened by you; this script only reads its
# pixels and never clicks anything. Used by capture_installer.ps1 too (-Handle).
param(
    [string]$Name = "",
    [int]$Delay = 5,
    [string]$Title = "",
    [long]$Handle = 0,
    [string]$OutFile = "",
    [switch]$List
)
$ErrorActionPreference = "Stop"
$guide = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$imageDir = Join-Path $guide "images\windows"

if ($List) {
    # The file names come from the g.figure_or_placeholder(WINDOWS_IMAGES / "<name>.png", ...) calls of the chapters
    $names = Select-String -Path (Join-Path $guide "chapters\*.py") -Pattern 'WINDOWS_IMAGES / "([a-z0-9_]+)\.png"' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($n in $names) {
        $state = if (Test-Path (Join-Path $imageDir "$n.png")) { "done   " } else { "MISSING" }
        Write-Host "$state $n"
    }
    exit 0
}
if ($Name -notmatch '^[a-z0-9_]+$') { throw "Give the image name without .png, e.g. -Name ssms_run_script (see -List)." }

Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]"QltttaCapture").Type) {   # once per PowerShell session
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class QltttaCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out RECT rect, int size);
}
"@
}
# Physical pixels: without this, Windows scales the coordinates of a high-DPI screen and the image is cut off
[void][QltttaCapture]::SetProcessDpiAwarenessContext([IntPtr](-4))   # PER_MONITOR_AWARE_V2

if ($Handle -ne 0) {
    $hwnd = [IntPtr]$Handle
} elseif ($Title) {
    $window = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match $Title } | Select-Object -First 1
    if (-not $window) { throw "No window whose title matches '$Title'." }
    $hwnd = $window.MainWindowHandle
} else {
    for ($s = $Delay; $s -gt 0; $s--) { Write-Host "Click the window to capture... $s"; Start-Sleep -Seconds 1 }
    $hwnd = [QltttaCapture]::GetForegroundWindow()
}
if (-not [QltttaCapture]::IsWindowVisible($hwnd)) { throw "The window is not visible." }

# PrintWindow draws the window even when another window covers it; the visible frame (DWM bounds) leaves out
# the invisible resize border and the shadow that GetWindowRect includes
$win = New-Object QltttaCapture+RECT
$frame = New-Object QltttaCapture+RECT
[void][QltttaCapture]::GetWindowRect($hwnd, [ref]$win)
if ([QltttaCapture]::DwmGetWindowAttribute($hwnd, 9, [ref]$frame, 16) -ne 0) { $frame = $win }   # 9 = DWMWA_EXTENDED_FRAME_BOUNDS
$full = New-Object System.Drawing.Bitmap ($win.Right - $win.Left), ($win.Bottom - $win.Top)
$graphics = [System.Drawing.Graphics]::FromImage($full)
$hdc = $graphics.GetHdc()
$printed = [QltttaCapture]::PrintWindow($hwnd, $hdc, 2)   # 2 = PW_RENDERFULLCONTENT
$graphics.ReleaseHdc($hdc)
$graphics.Dispose()
if (-not $printed) { $full.Dispose(); throw "Windows could not draw this window (PrintWindow failed)." }
$crop = New-Object System.Drawing.Rectangle ($frame.Left - $win.Left), ($frame.Top - $win.Top), ($frame.Right - $frame.Left), ($frame.Bottom - $frame.Top)
$image = $full.Clone($crop, $full.PixelFormat)
$full.Dispose()

$file = if ($OutFile) { $OutFile } else { Join-Path $imageDir "$Name.png" }
New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent) | Out-Null
$image.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved $file ($($image.Width) x $($image.Height))"
$image.Dispose()
