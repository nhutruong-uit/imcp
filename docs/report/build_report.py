#!/usr/bin/env python3
"""Sinh báo cáo đồ án IE103 (docs/report/IE103_Group1_Report.docx).

Cách dùng:
    python3 docs/report/build_report.py

Nội dung nằm trong thư mục content/ (mỗi chương một file). Mã SQL được trích trực tiếp từ database/*.sql,
từ điển dữ liệu và kết quả truy vấn/kiểm thử lấy từ data/*.json|txt (xuất từ CSDL thật), hình chụp màn hình
lấy từ images/screens (tools/qlttta_screenshots). Sau khi sinh, mở file bằng Word và chọn "Yes" khi được hỏi
cập nhật field (hoặc Ctrl+A rồi F9) để Word đánh lại mục lục, danh mục hình/bảng và số trang.
Yêu cầu: pip install python-docx
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from content import chapter1_2, chapter3, chapter4, chapter5, chapter6_8, front_matter  # noqa: E402
from report_lib import Report  # noqa: E402

OUTPUT = HERE / "IE103_Group1_Report.docx"


def main() -> None:
    r = Report(HERE / "template" / "uit_report_template.docx")
    front_matter.trang_bia(r)
    front_matter.checklist(r)
    front_matter.phan_cong(r)
    front_matter.muc_luc(r)
    chapter1_2.chuong1(r)
    chapter1_2.chuong2(r)
    chapter3.chuong3(r)
    chapter4.chuong4(r)
    chapter5.chuong5(r)
    chapter6_8.chuong6(r)
    chapter6_8.chuong7(r)
    chapter6_8.chuong8(r)
    chapter6_8.tai_lieu(r)
    chapter6_8.phu_luc(r)
    r.enable_update_fields_on_open()
    r.save(OUTPUT)
    print(f"Đã tạo {OUTPUT.relative_to(HERE.parent.parent)}")


if __name__ == "__main__":
    main()
