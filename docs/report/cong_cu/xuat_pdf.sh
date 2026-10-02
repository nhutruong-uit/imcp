#!/usr/bin/env bash
# Xuất PDF báo cáo bằng Microsoft Word (macOS): cập nhật mục lục, danh mục hình/bảng, số trang rồi lưu PDF.
#   ./docs/report/cong_cu/xuat_pdf.sh
#
# Word trên macOS chạy trong sandbox: file được mở bằng "open -a" (như bấm đúp trong Finder) nên macOS tự cấp
# quyền đọc file cho Word. Nếu Word vẫn hiện "Grant File Access", NGƯỜI DÙNG bấm "Select..." và chọn file
# (không tự động bấm hộp thoại cấp quyền). Không xóa thư mục .build để quyền đã cấp còn hiệu lực.
# Windows: mở BaoCao_DoAn_IE103_Nhom1.docx bằng Word -> Ctrl+A, F9 (cập nhật field) -> File > Save As > PDF.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
REPORT="$ROOT/docs/report"
BUILD="$REPORT/.build"
DOCX="$REPORT/BaoCao_DoAn_IE103_Nhom1.docx"
PDF="$REPORT/BaoCao_DoAn_IE103_Nhom1.pdf"

[[ "$(uname)" == "Darwin" ]] || { echo "Script chỉ chạy trên macOS (Windows: xuất PDF thủ công, xem đầu file)." >&2; exit 2; }
[[ -d "/Applications/Microsoft Word.app" ]] || { echo "Chưa cài Microsoft Word." >&2; exit 2; }
[[ -f "$DOCX" ]] || { echo "Chưa có $DOCX - chạy python3 docs/report/build_report.py trước." >&2; exit 2; }
mkdir -p "$BUILD"   # KHÔNG xóa thư mục này, Word sẽ mất quyền truy cập đã cấp

# Bản sao bỏ cờ updateFields: nếu còn, Word hỏi "Update fields?" và làm treo tự động hóa
python3 - "$DOCX" "$BUILD/report.docx" <<'PY'
import sys
from docx import Document
from docx.oxml.ns import qn
d = Document(sys.argv[1])
el = d.settings.element.find(qn("w:updateFields"))
if el is not None:
    d.settings.element.remove(el)
d.save(sys.argv[2])
PY
rm -f "$BUILD/report.pdf"

# Mở bằng LaunchServices (AppleScript "open" của Word bị sandbox chặn âm thầm với file chưa được cấp quyền)
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
            -- mục lục, danh mục hình, danh mục bảng đều là "table of contents"
            repeat with i from 1 to (count of tables of contents of d)
                update (table of contents i of d)
            end repeat
            save as d file name (item 1 of argv) file format format PDF
            close d saving no
        end tell
    end timeout
end run
APPLESCRIPT
PID=$!

# Nếu Word hỏi quyền truy cập file thì báo người dùng tự bấm (không tự động bấm hộp thoại cấp quyền)
DA_BAO=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 3
  if [[ $DA_BAO -eq 0 ]] && osascript -e 'tell application "System Events" to tell (first process whose name is "Microsoft Word") to get name of every window' 2>/dev/null | grep -q "Grant File Access"; then
    echo ">>> Word đang hỏi quyền: bấm \"Select...\" rồi chọn file docs/report/.build/report.docx"
    DA_BAO=1
  fi
done
wait "$PID" || { echo "Lỗi khi xuất PDF bằng Word." >&2; exit 1; }
[[ -s "$BUILD/report.pdf" ]] || { echo "Word không tạo được file PDF." >&2; exit 1; }
cp "$BUILD/report.pdf" "$PDF"
echo "Đã xuất ${PDF#"$ROOT"/}"
