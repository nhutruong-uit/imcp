# CLAUDE.md - hướng dẫn cho Claude Code trong repo QLTTTA

Đồ án IE103 (Quản lý thông tin, UIT): ứng dụng quản lý trung tâm tiếng Anh. Trọng tâm chấm điểm là
**CSDL SQL Server**; ứng dụng Qt là phần trình bày (menu/form/report). Thành viên nhóm phải giải thích
được code khi vấn đáp → luôn giải thích ngắn gọn bằng tiếng Việt những gì bạn thay đổi.

## Lệnh thường dùng

```bash
# CSDL (SQL Server trong Docker, container sql2022 hoặc imcp-mssql)
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/db_init.sh --docker sql2022

# Build + test (macOS). Nếu CMake báo compiler broken: thêm -DCMAKE_OSX_SYSROOT=<SDK của Xcode>
cmake --preset macos-debug && cmake --build --preset macos-debug && ctest --preset macos-debug

# CHẠY TOÀN BỘ KIỂM THỬ (bắt buộc trước khi tạo PR): db_init -> 12_kiem_thu.sql -> build -> unit + e2e
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker sql2022
# Bản PowerShell (Windows; trên macOS chạy được bằng pwsh): giữ hai bản .sh/.ps1 cùng các bước khi sửa
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" pwsh -File scripts/test_all.ps1 -Docker sql2022

# Chỉ kiểm thử end-to-end qua giao diện với CSDL thật (9 kịch bản; tự SKIP nếu thiếu biến môi trường)
QLTTTA_E2E_PASSWORD='Demo@2026' ctest --preset macos-debug -R e2e --output-on-failure

# Kiểm tra kết nối/đăng nhập không cần giao diện
QLTTTA_USER=ql_quan QLTTTA_PASSWORD='Demo@2026' build/macos-debug/src/app/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection

# Chụp màn hình (kiểm tra giao diện với dữ liệu thật)
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' build/macos-debug/tools/qlttta_screenshots
```

## Quy tắc bắt buộc

### CSDL (`database/`)
- Tương thích **SQL Server 2012+**: không `CREATE OR ALTER`, `DROP ... IF EXISTS`, `STRING_AGG`, `TRIM`,
  `CONCAT_WS`, JSON, RLS. Dùng mẫu `IF OBJECT_ID(N'dbo.x', N'P') IS NOT NULL DROP PROCEDURE dbo.x; GO`.
- Mọi file bắt đầu bằng `USE QLTTTA; GO; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; GO`.
- Đặt tên: bảng VIẾT HOA không dấu, cột PascalCase, `usp_`/`fn_`/`vw_`/`trg_`, ràng buộc `PK_/FK_/CK_/UQ_/DF_`.
- Lỗi nghiệp vụ: `THROW 5xxxx, N'thông báo tiếng Việt', 1;` (thủ tục) hoặc `RAISERROR + ROLLBACK` (trigger).
  Ứng dụng hiển thị nguyên văn thông báo.
- Trigger phải xử lý **tập hợp** (inserted/deleted nhiều dòng).
- Đối tượng mới → GRANT cho role trong `06_security.sql`; role nghiệp vụ không có quyền trên bảng gốc.
- Ứng dụng không INSERT/UPDATE bảng trực tiếp: mọi thao tác ghi đi qua thủ tục.
- Sau khi sửa: chạy `scripts/test_all.sh` (gồm `db_init` từ đầu + `12_kiem_thu.sql`), thử bằng tài khoản demo.
- Nghiệp vụ/ràng buộc/quyền mới → thêm ca kiểm thử vào `12_kiem_thu.sql` **và** đăng ký mã ca + mẫu thông báo
  trong bảng `#MongDoi` (ca "Từ chối" phải bị từ chối đúng lý do). Không sửa kỳ vọng của ca cũ để test "xanh"
  trừ khi đặc tả thay đổi thật - khi đó nói rõ trong PR.

### C++ / Qt (`src/`)
- Clean Architecture, chiều phụ thuộc: `presentation → application → domain ← infrastructure`; `app` nối dây.
  `presentation` **không** include `infrastructure/` và không chứa SQL. SQL chỉ nằm trong `infrastructure/repositories`.
- Module mới làm theo cookbook ở `docs/ARCHITECTURE.md` mục 4, mẫu tham khảo là module Học viên.
- Lỗi trả về bằng `Result<T>`/`VoidResult` (không ném exception qua các tầng).
- Tên nghiệp vụ tiếng Việt không dấu (`HocVienService::themMoi`), chuỗi giao diện tiếng Việt có dấu trong `QStringLiteral`.
- Gọi thủ tục có OUTPUT: lô lệnh `SET NOCOUNT ON; DECLARE @x ...; EXEC ... @Out = @x OUTPUT; SELECT @x;`.
  NULL truyền bằng `SqlHelpers::chuoiHoacNull`.
- Use case mới phải có unit test trong `tests/` với repository giả; màn hình mới phải được mở trong
  e2e (`moiVaiTro_moMoiChucNang_coDuLieu` tự phủ mọi chức năng trong `PhanQuyen`).
- C++17, Qt ≥ 6.5 (CI Windows dùng Qt 6.8 LTS + MinGW, macOS dùng Qt Homebrew).

### Git
- Làm trên nhánh `feature/...`, PR vào `develop`; không push thẳng `develop`/`main` (branch protection đã chặn:
  bắt buộc PR + CI xanh trên macOS và Windows + nhánh cập nhật theo base, áp dụng cả admin).
- Commit message tiếng Việt dạng `feat(scope): ...`, `fix(db): ...`.
- **PR (tiêu đề + mô tả) viết bằng tiếng Anh**: dùng skill `/create-pr` (`.claude/skills/create-pr/SKILL.md`),
  skill chạy `test_all` trước rồi mới tạo PR.
- Không commit mật khẩu thật, `.env`, thư mục `build/`, `dist/`.

## Tài khoản demo
Mật khẩu chung và danh sách: `docs/SETUP.md`. Vai trò: `ql_quan` (quản lý), `gvu_lan` (giáo vụ),
`kt_minh` (kế toán), `gv_john` (giáo viên).
