# Takes the screenshots of the QLTTTA installer for the user guide by itself: runs the setup.exe built by
# scripts\package.ps1 with /CURRENTUSER (the answer "Install for me only (recommended)" of the "Select install mode"
# dialog, whose command links UI Automation cannot click: no administrator rights, no UAC prompt), clicks through the
# wizard with UI Automation (the accessibility interface of Windows), captures every page with capture_window.ps1,
# then uninstalls silently. Results:
#   docs\user-guide\images\windows\installer_finish.png   the last page, used by chapter 3 of the guide
#   build\installer-pages\NN_<page>.png + pages.txt       every page and its texts (button names quoted in the guide)
# The SmartScreen warning only appears for a DOWNLOADED file and is a Windows security dialog: take that one by hand
# with capture_window.ps1 -Name installer_smartscreen (this script never clicks a system dialog).
#
# Usage (PowerShell, in the repo folder, after .\scripts\package.ps1 with Inno Setup 6):
#   .\docs\user-guide\tools\capture_installer.ps1
#   .\docs\user-guide\tools\capture_installer.ps1 -Setup dist\QLTTTA-0.1.0-windows-x64-setup.exe
param(
    [string]$Setup = ""
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if (-not $Setup) {
    $found = Get-ChildItem (Join-Path $root "dist") -Filter "QLTTTA-*-windows-x64-setup.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $found) { throw "No dist\QLTTTA-*-windows-x64-setup.exe: run .\scripts\package.ps1 (with Inno Setup 6) first." }
    $Setup = $found.FullName
}
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
function Get-Installed {
    Get-ChildItem $uninstallKey -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DisplayName -like "QLTTTA*" } | Select-Object -First 1
}
if (Get-Installed) { throw "QLTTTA is already installed for this user: uninstall it first, so the pages are the ones of a first install." }

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$capture = Join-Path $PSScriptRoot "capture_window.ps1"
$pagesDir = Join-Path $root "build\installer-pages"
New-Item -ItemType Directory -Force -Path $pagesDir | Out-Null
Get-ChildItem $pagesDir -File | Remove-Item -Force
$ua = [System.Windows.Automation.AutomationElement]
$scope = [System.Windows.Automation.TreeScope]

# Top-level window whose title matches (the wizard runs in setup.tmp, a child process of setup.exe)
function Find-Window([string]$pattern, [int]$seconds = 60) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($w in $ua::RootElement.FindAll($scope::Children, [System.Windows.Automation.Condition]::TrueCondition)) {
            if ($w.Current.Name -match $pattern) { return $w }
        }
        Start-Sleep -Milliseconds 300
    }
    throw "No window '$pattern' after $seconds s."
}
# Enabled button whose caption (without the & of its shortcut key) matches. The wizard is a Delphi (VCL) form: its
# buttons appear as "Pane" elements of class TNewButton, without the Invoke pattern, but each is a real Win32 window
function Find-Button($window, [string]$pattern) {
    foreach ($b in $window.FindAll($scope::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        $c = $b.Current
        if ($c.ClassName -match "Button" -and $c.NativeWindowHandle -ne 0 -and ($c.Name -replace "&", "") -match $pattern -and
            $c.IsEnabled -and -not $c.IsOffscreen) { return $b }
    }
    return $null
}
function Wait-Button($window, [string]$pattern, [int]$seconds = 120) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        $b = Find-Button $window $pattern
        if ($b) { return $b }
        Start-Sleep -Milliseconds 300
    }
    throw "No button '$pattern' after $seconds s."
}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class QltttaButton {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
"@
# BM_CLICK (0x00F5) = a click on that button, posted so the script does not wait for the click to be handled;
# the mouse and the keyboard of the user are not used
function Click($button) {
    [void][QltttaButton]::PostMessage([IntPtr]$button.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
}
$script:page = 0
function Save-Page($window, [string]$label) {
    Start-Sleep -Milliseconds 700   # let the page finish drawing
    $script:page++
    $file = Join-Path $pagesDir ("{0:d2}_{1}.png" -f $script:page, $label)
    & $capture -Name $label -Handle $window.Current.NativeWindowHandle -OutFile $file | Out-Null
    $texts = $window.FindAll($scope::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
        ForEach-Object { $_.Current.Name -replace "&", "" } | Where-Object { $_ -and $_.Length -lt 120 } | Select-Object -Unique
    Add-Content -Path (Join-Path $pagesDir "pages.txt") -Value ("== {0:d2} {1}: {2}" -f $script:page, $label, ($texts -join " | ")) -Encoding utf8
    return $file
}

$started = Get-Date
Write-Host ">> $Setup"
# Desktop shortcut task unticked: the run must not leave a shortcut behind if the uninstall step fails
Start-Process -FilePath $Setup -ArgumentList "/CURRENTUSER", '/MERGETASKS="!desktopicon"' | Out-Null
try {
    # 1. Wizard pages up to Install, then the last page
    $wizard = Find-Window "^Setup - "
    for ($i = 0; $i -lt 6; $i++) {
        $next = Find-Button $wizard "^Next"
        if (-not $next) { break }
        Save-Page $wizard ("page" + ($i + 1)) | Out-Null
        Click $next
        Start-Sleep -Milliseconds 800
    }
    Save-Page $wizard "ready" | Out-Null
    Click (Wait-Button $wizard "^Install$")
    $finish = Wait-Button $wizard "^Finish$"
    $last = Save-Page $wizard "finish"
    $imageDir = Join-Path $root "docs\user-guide\images\windows"
    New-Item -ItemType Directory -Force -Path $imageDir | Out-Null
    Copy-Item $last (Join-Path $imageDir "installer_finish.png") -Force
    # "Launch QLTTTA" stays ticked (as in the screenshot): the app started by Finish is closed below
    Click $finish
    Start-Sleep -Seconds 3
    Get-Process QLTTTA -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt $started } | Stop-Process -Force
} finally {
    # 2. Silent uninstall (also after a failure, so the machine is left as it was); a wizard still open after a
    #    failure is closed first (nothing is installed before the Install button)
    Get-Process | Where-Object { $_.ProcessName -like "QLTTTA-*-setup*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    $installed = Get-Installed
    if ($installed) {
        $uninstaller = ($installed.UninstallString -replace '"', "")
        Write-Host ">> uninstall: $uninstaller"
        Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait
    }
}
Get-Content (Join-Path $pagesDir "pages.txt")
if (Get-Installed) { throw "The silent uninstall did not finish: uninstall QLTTTA in Settings > Apps." }
Write-Host "Done: docs\user-guide\images\windows\installer_finish.png; every page in build\installer-pages\"
