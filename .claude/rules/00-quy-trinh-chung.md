# Quy trình chung khi sinh/sửa code (áp dụng cho mọi thành viên)

Mục tiêu: dù thành viên nào nhờ Claude Code làm, kết quả phải **cùng cấu trúc, cùng format, cùng cách báo cáo**,
để nhóm trưởng ghép lại không phải sửa và ai cũng giải thích được khi vấn đáp.

## 1. Các bước bắt buộc
1. **Hiểu yêu cầu**: thuộc tầng nào (CSDL / domain / application / infrastructure / presentation / test / báo cáo).
   Đọc quy tắc của loại file đó trong `.claude/rules/` và **mẫu tham khảo** trước khi viết:
   - CSDL: `usp_HocVien_Them` (`04_procedures.sql`), `trg_PHIEUTHU_CapNhatDaDong` (`05_triggers.sql`)
   - C++: module Học viên (`HocVien` → `IHocVienRepository` → `HocVienService` → `SqlHocVienRepository` → `HocVienPage`)
   - Test: `tests/tst_application.cpp` (repository giả), `tests/tst_e2e_gui.cpp`, `database/12_kiem_thu.sql`
2. **Làm theo mẫu**: cùng cách đặt tên, cùng bố cục file, cùng cách xử lý lỗi. Không tự chế kiểu mới khi đã có mẫu.
3. **Phạm vi nhỏ nhất**: chỉ sửa phần được giao. Không đổi tên/di chuyển file, không format lại cả file,
   không "tiện tay" sửa chỗ khác - ghi vào mục "Đề xuất" của báo cáo thay vì sửa.
4. **Format phần đã sửa**: C++ chạy `git clang-format` (chỉ format dòng thay đổi; không chạy `clang-format -i` cả file).
5. **Kiểm thử**: thêm/sửa test cho thay đổi (xem `tests.md`), chạy test liên quan; trước khi tạo PR chạy
   `scripts/test_all.sh` (Windows: `scripts\test_all.ps1`). Không sửa kỳ vọng của test cũ để cho "xanh".
6. **Báo cáo kết quả theo mẫu ở mục 3.**

## 2. Quy ước chung
- Chat với thành viên bằng **tiếng Việt**; comment trong code tiếng Việt có dấu, ngắn, giải thích *vì sao*.
- Tên trong code: tiếng Việt **không dấu** (`themMoi`, `HocVienService`, `usp_GhiDanh`); chuỗi giao diện có dấu.
- Commit message tiếng Việt `type(scope): mô tả` (feat, fix, test, docs, ci, refactor, chore); PR tiếng Anh qua `/imcp-create-pr`.
- `git status` có thay đổi không phải của mình (người khác/phiên khác đang làm): **không** `git add -A`,
  không stash/checkout/reset. Commit **chỉ đường dẫn của mình**: `git commit --only -m "..." -- <file của mình>`
  (lệnh `git commit` thường lấy CẢ vùng staging, kể cả `git mv` người khác đã stage), rồi kiểm tra
  `git show --stat HEAD` trước khi push và báo lại cho người dùng.
- Không đưa mật khẩu thật, `.env`, `build/`, `dist/` vào commit hay câu trả lời (mật khẩu demo ở `docs/SETUP.md` là dữ liệu thử).
- Hỏi lại khi yêu cầu mơ hồ ảnh hưởng tới thiết kế CSDL hoặc phân quyền; còn lại chọn theo mẫu có sẵn và ghi rõ giả định.

## 3. Mẫu báo cáo kết quả (cuối mỗi lượt làm việc)
```markdown
**Kết quả:** <1-2 câu: đã làm được gì>

| File | Thay đổi | Lý do |
|---|---|---|
| `database/04_procedures.sql` | thêm `usp_...` | ... |

**Kiểm thử:** `<lệnh đã chạy>` → <kết quả thật, vd "39/39 ca ĐẠT", "4/4 test passed">; <chưa kiểm thử được gì, vì sao>

**Giải thích khi vấn đáp** (cho thành viên phụ trách phần này):
- <khái niệm môn học được dùng: trigger tập hợp, ownership chaining, cursor...>
- <vì sao chọn cách này thay vì cách khác>

**Còn lại / cần quyết định:** <việc chưa làm, đề xuất, câu hỏi cho nhóm trưởng>
```
Không ghi "đã kiểm thử" khi chưa chạy; dán đúng con số kết quả.

## 4. Định nghĩa "xong" (Definition of Done)
- [ ] Đúng quy tắc tầng + mẫu tham khảo; không SQL ngoài `infrastructure/repositories`
- [ ] Đối tượng CSDL mới đã GRANT trong `06_security.sql` và có ca kiểm thử trong `12_kiem_thu.sql` (+ `#MongDoi`)
- [ ] Use case mới có unit test; màn hình mới được e2e mở qua `PhanQuyen`
- [ ] `git clang-format` sạch; build không thêm warning
- [ ] Đã chạy kiểm thử và báo kết quả thật; tài liệu/báo cáo cập nhật nếu thay đổi thiết kế (`/imcp-update-report`)
