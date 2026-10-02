---
name: imcp-update-report
description: Cập nhật báo cáo đồ án IE103 (docs/report) cho khớp với mã nguồn và CSDL hiện tại - xuất lại dữ liệu từ CSDL thật, ảnh màn hình, sơ đồ, sinh docx, xuất PDF bằng Word và kiểm tra. Dùng khi người dùng nói "cập nhật báo cáo", "update report", "/imcp-update-report", hoặc sau khi thay đổi CSDL/giao diện/test cần phản ánh vào báo cáo. Tham số tùy chọn - all (mặc định), data, screens, diagrams, docx, pdf, nopdf; có thể kèm mô tả nội dung cần sửa.
---

# Cập nhật báo cáo đồ án (QLTTTA)

Báo cáo được **sinh bằng script** từ `docs/report/noidung/*.py` + dữ liệu thật trong `docs/report/data/`.
Không bao giờ sửa trực tiếp file `.docx`. Trao đổi với người dùng bằng tiếng Việt. Tuân theo `.claude/rules/report.md`.

Tham số: `all` (mặc định) | `data` | `screens` | `diagrams` | `docx` | `pdf` | `nopdf` (làm hết trừ PDF).
Nếu người dùng kèm yêu cầu sửa nội dung (vd "thêm mục về trigger mới"), làm bước 4 theo yêu cầu đó.

## 0. Chuẩn bị
- `git status --short`: ghi nhận thay đổi đang có của người khác - **không** đụng/stage chúng.
- Xác định phần báo cáo bị ảnh hưởng từ lần cập nhật trước:
  ```bash
  LAST=$(git log -1 --format=%h -- docs/report/BaoCao_DoAn_IE103_Nhom1.docx)
  git diff --stat "$LAST"..HEAD -- database src tests scripts docs/report/noidung docs/report/diagrams
  ```
  | Thay đổi ở | Cần làm |
  |---|---|
  | `database/*.sql` | bước 2 (dữ liệu) - mã SQL trong báo cáo tự trích lại khi sinh docx |
  | `database/12_kiem_thu.sql`, `tests/` | bước 2 + xem lại mô tả kiểm thử (Chương 4.9, 5.7, 6.6) |
  | `src/presentation/` hoặc dữ liệu mẫu | bước 3 (ảnh màn hình) |
  | `docs/report/diagrams/*.dot` | bước 3b (sơ đồ) |
  | `docs/report/noidung/` | chỉ bước 5-7 |

## 1. CSDL sạch + toàn bộ kiểm thử đạt (bắt buộc với `all`, `data`, `screens`)
```bash
docker ps --format '{{.Names}}'          # container: sql2022 hoặc imcp-mssql
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker sql2022
```
Khởi tạo lại CSDL từ đầu (dữ liệu mẫu tính theo ngày chạy) và chạy hết kiểm thử. **Có bước hỏng thì dừng**,
báo người dùng - báo cáo không được trình bày kết quả kiểm thử sai. Không in mật khẩu sa.

## 2. Xuất dữ liệu thật cho báo cáo
```bash
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" python3 docs/report/cong_cu/xuat_du_lieu.py --docker sql2022
```
Ghi `data/schema.json`, `data/ket_qua_truy_van.json` (kể cả `doi_tuong`: số bảng, thủ tục, trigger, ràng buộc...)
và `data/kiem_thu.txt` (chỉ ghi khi mọi ca đạt). Xem `git diff --stat docs/report/data` và giải thích thay đổi
(số liệu đổi theo ngày chạy là bình thường; cấu trúc/cột đổi thì kiểm tra chương dùng mục đó).
Thêm truy vấn minh họa mới: bổ sung vào `TRUY_VAN` trong `xuat_du_lieu.py`, rồi đọc bằng `ket_qua()["ten"]`.

## 3. Ảnh màn hình (khi giao diện hoặc dữ liệu hiển thị thay đổi)
```bash
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' ./build/macos-debug/tools/qlttta_screenshots
git status --short docs/report/images/screens
```
Xem (Read) từng ảnh đã thay đổi để chắc nội dung đúng (không trang trống, không lỗi quyền ngoài ý muốn).
**3b. Sơ đồ** (khi `.dot` thay đổi): `cd docs/report/diagrams && dot -Tpng <ten>.dot -o ../images/diagrams/<ten>.png`,
xem lại ảnh.

## 4. Sửa nội dung (khi có yêu cầu hoặc thiết kế thay đổi)
- Sửa đúng chương trong `docs/report/noidung/` (chung, phan_dau, chuong1_2, chuong3, chuong4, chuong5, chuong6_8).
- Số liệu lấy từ `doi_tuong()`, `kiem_thu()`, `ket_qua()`, `schema()` - không gõ cứng con số.
- Mã SQL dùng `sql_object(...)`/`sql_block(...)` để trích từ `database/*.sql`.
- Tìm chỗ còn mô tả cũ: `grep -rn "<tên đối tượng/hành vi cũ>" docs/report/noidung`.

## 5. Sinh docx
```bash
python3 docs/report/build_report.py
```
Lỗi Python thì sửa `noidung`/`report_lib.py` rồi chạy lại. Nếu có skill docx với `validate.py`, kiểm tra thêm.

## 6. Xuất PDF (bỏ qua với `nopdf`)
- macOS + Microsoft Word: `./docs/report/cong_cu/xuat_pdf.sh` (mở bằng `open -a`, cập nhật mục lục/danh mục
  hình/bảng, lưu PDF vào `docs/report/BaoCao_DoAn_IE103_Nhom1.pdf`). Nếu Word hiện **"Grant File Access"**,
  dừng lại và nhờ người dùng tự bấm *Select...* - không tự bấm hộp thoại cấp quyền.
- Windows hoặc không có Word: nhờ người dùng mở docx bằng Word → Ctrl+A, F9 → *Save As* PDF.

## 7. Kiểm tra kết quả
```bash
swift docs/report/cong_cu/kiem_tra_pdf.swift kiemtra docs/report/BaoCao_DoAn_IE103_Nhom1.pdf "<chuỗi mới cần thấy>"
swift docs/report/cong_cu/kiem_tra_pdf.swift anh docs/report/BaoCao_DoAn_IE103_Nhom1.pdf <thư mục tạm> <các trang đã đổi>
```
- Mã thoát 1 = còn lỗi field của Word (mục lục/tham chiếu) → xuất lại PDF.
- Xem (Read) `tong_hop.png` của các trang đã đổi: bảng không tràn lề, hình không vỡ, không trang trắng thừa.
- So số trang với lần trước (`git show HEAD:docs/report/BaoCao_DoAn_IE103_Nhom1.pdf` → kiểm tra lại) và giải thích nếu đổi.

## 8. Commit và báo cáo
- Chỉ `git add` các file báo cáo đã sinh/sửa: `docs/report/noidung`, `data`, `images`, `diagrams`, `cong_cu`,
  `BaoCao_DoAn_IE103_Nhom1.docx`, `.pdf` (thư mục `docs/report/.build/` đã được ignore).
- Commit tiếng Việt: `docs(report): <nội dung cập nhật>`. Không push thẳng `main`; cần PR thì dùng `/imcp-create-pr`.
- Trả lời theo mẫu báo cáo trong `.claude/rules/00-quy-trinh-chung.md`: phần nào cập nhật, số trang,
  kết quả kiểm thử thật (x/y ca), trang cần thành viên phụ trách đọc lại.
