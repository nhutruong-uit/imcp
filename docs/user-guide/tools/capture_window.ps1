# Captures windows for the user guide - the screenshots that tools\qlttta_screenshots cannot take (installers, SQL
# Server tools, Docker Desktop, SmartScreen). An image saved as docs\user-guide\images\windows\<name>.png replaces its
# yellow placeholder on the next build_user_guide.py run.
#
# Usage (PowerShell, in the repo folder):
#   .\docs\user-guide\tools\capture_window.ps1 -List                         # images the guide expects, done or missing
#   .\docs\user-guide\tools\capture_window.ps1 -Name ssms_run_script         # 5 s countdown: click the window to capture
#   .\docs\user-guide\tools\capture_window.ps1 -Name x -Delay 10             # more time to bring the window to the front
#   .\docs\user-guide\tools\capture_window.ps1 -Name x -Title "^Setup - "    # the window whose title matches (no click)
#   .\docs\user-guide\tools\capture_window.ps1 -Name sql_setup -Watch "SQL Server"
#       watch mode: while you click through a program, every time its window in front changes (title or process
#       name matching -Watch) it is saved as build\captures\sql_setup\NN.png; stops after -Minutes (default 20)
#       or Ctrl+C (-StopWhenClosed: when the watched window closes). Pick the right image afterwards and copy it to
#       images\windows\<name>.png.
#   then: py docs\user-guide\build_user_guide.py   (the image replaces its placeholder)
#   powershell -ExecutionPolicy Bypass -File docs\user-guide\tools\capture_window.ps1 ...   # when scripts are blocked
# Only the window is saved (no desktop, no other windows), at the screen's real resolution. A window that needs
# administrator rights (SQL Server Configuration Manager, the SQL Server installer) is opened by you; this script only
# reads its pixels and never clicks anything (a UAC prompt itself cannot be captured: Windows shows it on a separate
# secure desktop). Used by capture_installer.ps1 too (-Handle).
param(
    [string]$Name = "",
    [int]$Delay = 5,
    [string]$Title = "",
    [long]$Handle = 0,
    [string]$OutFile = "",
    [string]$Watch = "",
    [double]$Minutes = 20,
    [switch]$StopWhenClosed,
    [switch]$List
)
$ErrorActionPreference = "Stop"
$guide = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$root = (Resolve-Path (Join-Path $guide "..\..")).Path
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
using System.Text;
public static class QltttaCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out RECT rect, int size);
}
"@
}
# Physical pixels: without this, Windows scales the coordinates of a high-DPI screen and the image is cut off
[void][QltttaCapture]::SetProcessDpiAwarenessContext([IntPtr](-4))   # PER_MONITOR_AWARE_V2

# Visible frame of the window (DWM bounds): leaves out the invisible resize border and the shadow of GetWindowRect
function Get-Frame([IntPtr]$hwnd) {
    $frame = New-Object QltttaCapture+RECT
    if ([QltttaCapture]::DwmGetWindowAttribute($hwnd, 9, [ref]$frame, 16) -ne 0) {   # 9 = DWMWA_EXTENDED_FRAME_BOUNDS
        [void][QltttaCapture]::GetWindowRect($hwnd, [ref]$frame)
    }
    return $frame
}

# The pixels of the screen where the window is: works for every window, also one run as administrator, but the
# window must be in front - true right after the user clicked it
function Copy-FromScreen([IntPtr]$hwnd) {
    $frame = Get-Frame $hwnd
    $size = New-Object System.Drawing.Size ($frame.Right - $frame.Left), ($frame.Bottom - $frame.Top)
    $bitmap = New-Object System.Drawing.Bitmap $size.Width, $size.Height
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.CopyFromScreen($frame.Left, $frame.Top, 0, 0, $size)
    $g.Dispose()
    return $bitmap
}

# One flat color = the window did not draw itself
function Test-Blank($bitmap) {
    $first = $bitmap.GetPixel(0, 0).ToArgb()
    $stepX = [Math]::Max(1, [int]($bitmap.Width / 12))
    $stepY = [Math]::Max(1, [int]($bitmap.Height / 12))
    for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
        for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
            if ($bitmap.GetPixel($x, $y).ToArgb() -ne $first) { return $false }
        }
    }
    return $true
}

# PrintWindow asks the window to draw itself, even behind other windows; Windows refuses that request to a window of
# a program run as administrator (it then comes out blank), so the screen copy is the fallback
function Get-WindowImage([IntPtr]$hwnd) {
    $win = New-Object QltttaCapture+RECT
    [void][QltttaCapture]::GetWindowRect($hwnd, [ref]$win)
    $frame = Get-Frame $hwnd
    $full = New-Object System.Drawing.Bitmap ($win.Right - $win.Left), ($win.Bottom - $win.Top)
    $graphics = [System.Drawing.Graphics]::FromImage($full)
    $hdc = $graphics.GetHdc()
    $printed = [QltttaCapture]::PrintWindow($hwnd, $hdc, 2)   # 2 = PW_RENDERFULLCONTENT
    $graphics.ReleaseHdc($hdc)
    $graphics.Dispose()
    $crop = New-Object System.Drawing.Rectangle ($frame.Left - $win.Left), ($frame.Top - $win.Top), ($frame.Right - $frame.Left), ($frame.Bottom - $frame.Top)
    $image = $full.Clone($crop, $full.PixelFormat)
    $full.Dispose()
    if ($printed -and -not (Test-Blank $image)) { return $image }
    $image.Dispose()
    Write-Host "The window does not draw itself for this script (run as administrator?): copying it from the screen."
    return Copy-FromScreen $hwnd
}

# Small grayscale copy, to notice that the window shows another page (a blinking caret is not a change)
function Get-Signature($bitmap) {
    $small = New-Object System.Drawing.Bitmap 48, 36
    $g = [System.Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $g.DrawImage($bitmap, 0, 0, 48, 36)
    $g.Dispose()
    $values = New-Object int[] (48 * 36)
    for ($y = 0; $y -lt 36; $y++) {
        for ($x = 0; $x -lt 48; $x++) {
            $c = $small.GetPixel($x, $y)
            $values[$y * 48 + $x] = [int](($c.R + $c.G + $c.B) / 3)
        }
    }
    $small.Dispose()
    return ,$values
}

function Save-Image($image, [string]$file) {
    New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent) | Out-Null
    $image.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved $file ($($image.Width) x $($image.Height))"
}

if ($Watch) {
    $outDir = Join-Path $root "build\captures\$Name"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    Get-ChildItem $outDir -File | Remove-Item -Force
    Write-Host "Watching windows matching '$Watch' for $Minutes min: click through the program; Ctrl+C to stop."
    $deadline = (Get-Date).AddMinutes($Minutes)
    $last = $null
    $count = 0
    $seen = [IntPtr]::Zero
    while ((Get-Date) -lt $deadline -and $count -lt 99) {
        Start-Sleep -Milliseconds 1000
        # -StopWhenClosed: the program shows one window (e.g. SmartScreen); its closing ends the watch
        if ($StopWhenClosed -and $seen -ne [IntPtr]::Zero -and -not [QltttaCapture]::IsWindowVisible($seen)) { break }
        $hwnd = [QltttaCapture]::GetForegroundWindow()
        $processId = [uint32]0
        [void][QltttaCapture]::GetWindowThreadProcessId($hwnd, [ref]$processId)
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        $text = New-Object System.Text.StringBuilder 256
        [void][QltttaCapture]::GetWindowText($hwnd, $text, 256)
        if (-not $process -or -not ("$text" -match $Watch -or $process.ProcessName -match $Watch)) { continue }
        $seen = $hwnd
        $image = Copy-FromScreen $hwnd   # the window in front is the one the user works in
        $signature = Get-Signature $image
        $changed = -not $last -or $last.Length -ne $signature.Length
        if (-not $changed) {
            $sum = 0
            for ($i = 0; $i -lt $signature.Length; $i++) { $sum += [Math]::Abs($signature[$i] - $last[$i]) }
            $changed = ($sum / $signature.Length) -gt 1.5
        }
        if ($changed) {
            $count++
            Save-Image $image (Join-Path $outDir ("{0:d2}.png" -f $count))
            Add-Content -Path (Join-Path $outDir "windows.txt") -Value ("{0:d2} {1} | {2}" -f $count, $process.ProcessName, $text) -Encoding utf8
            $last = $signature
        }
        $image.Dispose()
    }
    Write-Host "$count image(s) in $outDir"
    exit 0
}

if ($Handle -ne 0) {
    $image = Get-WindowImage ([IntPtr]$Handle)
} elseif ($Title) {
    $window = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match $Title } | Select-Object -First 1
    if (-not $window) { throw "No window whose title matches '$Title'." }
    $image = Get-WindowImage $window.MainWindowHandle
} else {
    for ($s = $Delay; $s -gt 0; $s--) { Write-Host "Click the window to capture... $s"; Start-Sleep -Seconds 1 }
    $hwnd = [QltttaCapture]::GetForegroundWindow()
    if (-not [QltttaCapture]::IsWindowVisible($hwnd)) { throw "The window is not visible." }
    $image = Copy-FromScreen $hwnd
}
$file = if ($OutFile) { $OutFile } else { Join-Path $imageDir "$Name.png" }
Save-Image $image $file
$image.Dispose()
