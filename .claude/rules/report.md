---
paths:
  - "docs/report/**"
---
# Quy tắc báo cáo đồ án (docs/report/)

- Báo cáo **sinh bằng script**: sửa nội dung trong `docs/report/noidung/*.py`, không sửa trực tiếp file `.docx`
  (lần sinh sau sẽ ghi đè). Cập nhật cả quy trình bằng skill `/imcp-update-report`.
- Mỗi chương do một thành viên phụ trách (bảng phân công trong `noidung/phan_dau.py`, `docs/PLAN.md`); sửa chương
  của người khác thì ghi rõ trong báo cáo kết quả.
- **Không ghi cứng số liệu** lấy được từ CSDL: dùng `doi_tuong()` (số bảng, thủ tục, trigger, ràng buộc...),
  `kiem_thu()` (ca kiểm thử), `ket_qua()` (kết quả truy vấn), `schema()` (từ điển dữ liệu) trong `noidung/chung.py`.
  Dữ liệu sinh lại bằng `docs/report/cong_cu/xuat_du_lieu.py`.
- Mã SQL trong báo cáo trích tự động từ `database/*.sql` (`sql_object`, `sql_block`) - không chép tay code vào nội dung.
- Văn phong học thuật, ngôi "nhóm", câu ngắn; thuật ngữ tiếng Anh để trong `code` hoặc kèm nghĩa tiếng Việt lần đầu.
  Định dạng inline: `**đậm**`, `*nghiêng*`, `` `code` ``. Hình/bảng luôn có chú thích (caption) mô tả nội dung.
- Sơ đồ: sửa nguồn `diagrams/*.dot` rồi `dot -Tpng` ra `images/diagrams/`; ảnh màn hình chỉ sinh bằng
  `tools/qlttta_screenshots` (không chụp tay, để mọi máy ra cùng kích thước/dữ liệu).
- Sau khi sinh PDF: kiểm tra `swift docs/report/cong_cu/kiem_tra_pdf.swift kiemtra <pdf>` (không còn lỗi field
  của Word) và xem ảnh các trang đã đổi (`... anh <pdf> <thư mục> <trang>`).
