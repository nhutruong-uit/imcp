# Exports the report PDF with Microsoft Word (Windows) - the Windows version of export_pdf.sh: updates the table of
# contents, the lists of figures/tables and the page numbers, then saves the PDF next to the docx.
#   .\docs\report\tools\export_pdf.ps1                                           # the report
#   .\docs\report\tools\export_pdf.ps1 docs\user-guide\QLTTTA_User_Guide.docx    # another generated document
#   powershell -ExecutionPolicy Bypass -File docs\report\tools\export_pdf.ps1 ... # when PowerShell blocks scripts
#
# Like export_pdf.sh, the docx updated by Word (fields filled in, NO updateFields flag) is copied over the input
# docx => opening it in Word no longer asks "update the fields in this document?". Word is driven through COM
# (hidden window) instead of AppleScript; it then searches the updated text for Word field errors ("Error! Bookmark
# not defined"...), the check that check_pdf.swift does on macOS: exit code 1 when one is found.
# Needs Microsoft Word for Windows (desktop). The working copy stays in docs\report\.build (ignored by git).
param(
    [string]$Docx = ""
)
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 drives Word through the Office type library, which some Office installations do not register
# completely (TYPE_E_CANTLOADLIBRARY); PowerShell 7 calls Word without it, so the script runs there when installed
if ($PSVersionTable.PSVersion.Major -lt 6 -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $forward = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
    if ($Docx) { $forward += @("-Docx", $Docx) }
    & pwsh @forward
    exit $LASTEXITCODE
}

$root =(Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$report = Join-Path $root "docs\report"
$build = Join-Path $report ".build"
if (-not $Docx) { $Docx = Join-Path $report "IE103_Group1_Report.docx" }
if (-not (Test-Path $Docx)) { throw "$Docx not found - generate it first (e.g. python docs\report\build_report.py)." }
$Docx = (Resolve-Path $Docx).Path
$pdf = [IO.Path]::ChangeExtension($Docx, ".pdf")
$name = Split-Path $Docx -Leaf                 # working copy in .build
$work = Join-Path $build $name
$workPdf = [IO.Path]::ChangeExtension($work, ".pdf")
New-Item -ItemType Directory -Force -Path $build | Out-Null

# 1. Working copy without the updateFields flag (settings.xml) and the w:dirty flags of the fields (document.xml):
#    with either of them Word asks "update the fields in this document?" when it opens the file, which blocks the
#    automation. Step 2 updates the fields itself.
Copy-Item $Docx $work -Force
$lock = Join-Path $build ("~$" + $name)        # lock file left by a failed export
if (Test-Path $lock) { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
Add-Type -AssemblyName System.IO.Compression
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }   # ZipFile on Windows PowerShell 5.1
$zip = [IO.Compression.ZipFile]::Open($work, [IO.Compression.ZipArchiveMode]::Update)
try {
    $patterns = @{ "word/settings.xml" = '<w:updateFields\b[^>]*/>'; "word/document.xml" = '\s+w:dirty="(true|1|on)"' }
    foreach ($part in $patterns.Keys) {
        $entry = $zip.GetEntry($part)
        if (-not $entry) { continue }
        $reader = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8)
        $xml = $reader.ReadToEnd()
        $reader.Close()
        $entry.Delete()
        $writer = New-Object IO.StreamWriter($zip.CreateEntry($part).Open(), (New-Object Text.UTF8Encoding($false)))
        $writer.Write(($xml -replace $patterns[$part], ""))
        $writer.Close()
    }
} finally {
    $zip.Dispose()
}

# 2. Word (hidden): update every field (caption numbers, cross references), then the table of contents and the
#    lists of figures/tables (page numbers); keep the updated docx and export the PDF
$fieldErrors = @("Error! Bookmark not defined", "Error! Reference source not found",
                 "No table of contents entries found", "Lỗi! Không tìm thấy nguồn tham chiếu",
                 "Lỗi! Thẻ đánh dấu chưa được xác định")
$wordBefore = @(Get-Process WINWORD -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
try {
    $word = New-Object -ComObject Word.Application
} catch {
    throw "Microsoft Word is not installed (or cannot be started through COM): export the PDF by hand, see docs\report\README.md."
}
$found = @()
$document = $null
try {
    $word.Visible = $false
    $word.DisplayAlerts = 0                    # wdAlertsNone: no dialog may wait for a click
    if (Test-Path $workPdf) { Remove-Item $workPdf -Force }
    # Open(FileName, ConfirmConversions, ReadOnly, AddToRecentFiles)
    $document = $word.Documents.Open($work, $false, $false, $false)
    $document.Fields.Update() | Out-Null
    foreach ($toc in $document.TablesOfContents) { $toc.Update() }
    foreach ($tof in $document.TablesOfFigures) { $tof.Update() }
    $text = $document.Content.Text
    foreach ($e in $fieldErrors) { if ($text.Contains($e)) { $found += $e } }
    $document.Save()
    $document.ExportAsFixedFormat($workPdf, 17)   # 17 = wdExportFormatPDF
    $document.Close(0)                         # 0 = wdDoNotSaveChanges (already saved)
    $document = $null
} catch {
    # Windows PowerShell 5.1 goes through the Office type library, which some Office installations do not register
    # completely; PowerShell 7 calls Word without it
    if ("$_" -match "TYPE_E_CANTLOADLIBRARY|Unable to cast COM object") {
        throw "Word cannot be driven from Windows PowerShell on this computer ($_). Run the script with PowerShell 7: pwsh -File docs\report\tools\export_pdf.ps1"
    }
    throw
} finally {
    try {
        if ($document) { $document.Close(0) }
        # Quit only a Word that has no other document open (the user may be working in the same Word instance)
        if ($word.Documents.Count -eq 0) { $word.Quit() }
    } catch {
        # Word could not be driven at all: stop the hidden Word started by this script (no window, new process)
        Get-Process WINWORD -ErrorAction SilentlyContinue |
            Where-Object { $wordBefore -notcontains $_.Id -and $_.MainWindowHandle -eq 0 } |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
if (-not (Test-Path $workPdf) -or (Get-Item $workPdf).Length -eq 0) { throw "Word did not create the PDF." }

Copy-Item $workPdf $pdf -Force
Copy-Item $work $Docx -Force
Write-Host "Exported $($pdf.Substring($root.Length + 1)) (the docx was replaced by the version Word updated: table of contents, page numbers)"
if ($found.Count -gt 0) {
    $found | ForEach-Object { Write-Host "WORD FIELD ERROR `"$_`"" }
    exit 1
}
Write-Host "No Word field errors."
