# Báo cáo đồ án

- **`BaoCao_DoAn_IE103_Nhom1.pdf`** - bản PDF xuất từ Word (mục lục, số trang đã cập nhật) để nộp/gửi giảng viên.
- **`BaoCao_DoAn_IE103_Nhom1.docx`** - báo cáo (định dạng theo mẫu báo cáo UIT của nhóm).
  Mở bằng Word → chọn **Yes** khi được hỏi cập nhật field (hoặc `Ctrl+A` rồi `F9`) để Word đánh lại
  mục lục, danh mục hình, danh mục bảng và số trang. Xuất PDF: *File > Save As > PDF*.

## Sinh lại báo cáo sau khi sửa nội dung

Báo cáo được sinh bằng script để luôn khớp với mã nguồn và CSDL:

```bash
pip3 install python-docx
python3 docs/report/build_report.py
```

| Thành phần | Vị trí |
|---|---|
| Nội dung từng chương | `noidung/chuong*.py` (mỗi thành viên sửa chương mình phụ trách) |
| Trang bìa, checklist, bảng phân công | `noidung/phan_dau.py`, `noidung/chung.py` |
| Mã SQL trong khung code | trích tự động từ `database/*.sql` |
| Từ điển dữ liệu | `data/schema.json` (xuất từ CSDL thật) |
| Kết quả truy vấn, kiểm thử | `data/ket_qua_truy_van.json`, `data/kiem_thu.txt` |
| Sơ đồ (ERD, CD, use case, DFD...) | nguồn `diagrams/*.dot` → `images/diagrams/*.png` |
| Hình chụp màn hình ứng dụng | `images/screens/` (tạo bằng `tools/qlttta_screenshots`) |
| Khuôn định dạng | `template/mau_bao_cao_uit.docx` |

Vẽ lại sơ đồ sau khi sửa file `.dot` (cần `brew install graphviz`):
```bash
cd docs/report/diagrams && for f in *.dot; do dot -Tpng "$f" -o "../images/diagrams/${f%.dot}.png"; done
```

> Nếu chỉnh sửa trực tiếp trong Word thì lần sinh lại sau sẽ ghi đè. Nên sửa nội dung trong `noidung/`,
> hoặc khi đã chốt bản cuối thì chỉ sửa trong Word.
