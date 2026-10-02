#!/usr/bin/env bash
# Exports the report PDF with Microsoft Word (macOS): updates the table of contents, the lists of figures/tables
# and the page numbers, then saves the PDF.
#   ./docs/report/tools/export_pdf.sh
#
# The docx updated by Word (table of contents and page numbers filled in, NO updateFields flag) is copied over
# IE103_Group1_Report.docx => opening the report in Word no longer asks "update the fields in this document?".
#
# Word on macOS runs in a sandbox: the file is opened with "open -a" (like a double click in Finder), so macOS
# grants Word read access itself. If Word still shows "Grant File Access", the USER clicks "Select..." and picks
# the file (never click permission dialogs automatically). Do not delete .build, so the granted access stays valid.
# Windows: open IE103_Group1_Report.docx in Word -> Ctrl+A, F9 (update fields) -> File > Save As > PDF.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
REPORT="$ROOT/docs/report"
BUILD="$REPORT/.build"
DOCX="$REPORT/IE103_Group1_Report.docx"
PDF="$REPORT/IE103_Group1_Report.pdf"

[[ "$(uname)" == "Darwin" ]] || { echo "This script only runs on macOS (Windows: export the PDF by hand, see the top of this file)." >&2; exit 2; }
[[ -d "/Applications/Microsoft Word.app" ]] || { echo "Microsoft Word is not installed." >&2; exit 2; }
[[ -f "$DOCX" ]] || { echo "$DOCX not found - run python3 docs/report/build_report.py first." >&2; exit 2; }
mkdir -p "$BUILD"   # NEVER delete this folder: Word would lose the access it was granted

# Working copy without the updateFields flag and the w:dirty flags of the fields (table of contents, lists of
# figures/tables): with either of them Word asks "update the fields in this document?" when it opens the file, and
# that dialog blocks the automation. The AppleScript below updates the tables of contents itself.
python3 - "$DOCX" "$BUILD/report.docx" <<'PY'
import sys
from docx import Document
from docx.oxml.ns import qn
d = Document(sys.argv[1])
el = d.settings.element.find(qn("w:updateFields"))
if el is not None:
    d.settings.element.remove(el)
for fld in d.element.body.iter(qn("w:fldChar")):
    fld.attrib.pop(qn("w:dirty"), None)
d.save(sys.argv[2])
PY
rm -f "$BUILD/report.pdf"
# A "~$report.docx" lock left by a failed export stops Word from opening the document => delete it unless Word has it open
if ! osascript -e 'tell application "Microsoft Word" to get name of every document' 2>/dev/null | grep -q "report.docx"; then
  rm -f "$BUILD/~\$report.docx"
fi

# Open through LaunchServices (the sandbox silently blocks Word's AppleScript "open" for files without granted access)
open -a "Microsoft Word" "$BUILD/report.docx"
for _ in $(seq 1 60); do
  sleep 2
  osascript -e 'tell application "Microsoft Word" to get name of every document' 2>/dev/null | grep -q "report.docx" && break
done

osascript - "$BUILD/report.pdf" <<'APPLESCRIPT' &
on run argv
    with timeout of 900 seconds
        tell application "Microsoft Word"
            set d to document "report.docx"
            -- the table of contents and the lists of figures/tables are all "tables of contents"
            repeat with i from 1 to (count of tables of contents of d)
                update (table of contents i of d)
            end repeat
            save d   -- keep the docx with updated fields (copied back to the report at the end)
            save as d file name (item 1 of argv) file format format PDF
            close d saving no
        end tell
    end timeout
end run
APPLESCRIPT
PID=$!

# If Word asks for file access, tell the user to answer it (never click permission dialogs automatically)
NOTIFIED=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 3
  if [[ $NOTIFIED -eq 0 ]] && osascript -e 'tell application "System Events" to tell (first process whose name is "Microsoft Word") to get name of every window' 2>/dev/null | grep -q "Grant File Access"; then
    echo ">>> Word is asking for file access: click \"Select...\" and pick docs/report/.build/report.docx"
    NOTIFIED=1
  fi
done
wait "$PID" || { echo "Word failed to export the PDF." >&2; exit 1; }
[[ -s "$BUILD/report.pdf" ]] || { echo "Word did not create the PDF." >&2; exit 1; }
cp "$BUILD/report.pdf" "$PDF"
cp "$BUILD/report.docx" "$DOCX"
echo "Exported ${PDF#"$ROOT"/} (the docx was replaced by the version Word updated: table of contents, page numbers)"
