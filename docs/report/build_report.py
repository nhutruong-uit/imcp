#!/usr/bin/env python3
"""Sinh báo cáo đồ án IE103 (docs/report/BaoCao_DoAn_IE103_Nhom1.docx).

Cách dùng:
    python3 docs/report/build_report.py

Nội dung nằm trong thư mục noidung/ (mỗi chương một file). Mã SQL được trích trực tiếp từ database/*.sql,
từ điển dữ liệu và kết quả truy vấn/kiểm thử lấy từ data/*.json|txt (xuất từ CSDL thật), hình chụp màn hình
lấy từ images/screens (tools/qlttta_screenshots). Sau khi sinh, mở file bằng Word và chọn "Yes" khi được hỏi
cập nhật field (hoặc Ctrl+A rồi F9) để Word đánh lại mục lục, danh mục hình/bảng và số trang.
Yêu cầu: pip install python-docx
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from noidung import chuong1_2, chuong3, chuong4, chuong5, chuong6_8, phan_dau  # noqa: E402
from report_lib import Report  # noqa: E402

OUTPUT = HERE / "BaoCao_DoAn_IE103_Nhom1.docx"


def main() -> None:
    r = Report(HERE / "template" / "mau_bao_cao_uit.docx")
    phan_dau.trang_bia(r)
    phan_dau.checklist(r)
    phan_dau.phan_cong(r)
    phan_dau.muc_luc(r)
    chuong1_2.chuong1(r)
    chuong1_2.chuong2(r)
    chuong3.chuong3(r)
    chuong4.chuong4(r)
    chuong5.chuong5(r)
    chuong6_8.chuong6(r)
    chuong6_8.chuong7(r)
    chuong6_8.chuong8(r)
    chuong6_8.tai_lieu(r)
    chuong6_8.phu_luc(r)
    r.enable_update_fields_on_open()
    r.save(OUTPUT)
    print(f"Đã tạo {OUTPUT.relative_to(HERE.parent.parent)}")


if __name__ == "__main__":
    main()
