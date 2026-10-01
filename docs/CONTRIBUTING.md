# Quy trình làm việc nhóm

## Nhánh Git

```
feature/<ten-ngan>  ──PR──▶  develop  ──PR (nhóm trưởng duyệt)──▶  main  ──▶  GitHub Release (file cài)
fix/<ten-ngan>               (CI build + test Win/Mac)                        (tự động đóng gói)
docs/<ten-ngan>
```

- **Không push thẳng** vào `develop` và `main`. Mỗi thay đổi đi qua Pull Request.
- PR vào `develop`: CI (`ci.yml`) phải xanh trên **cả macOS và Windows**.
- PR `develop → main` = phát hành: `release.yml` đóng gói `.exe`/`.zip`/`.dmg` và tạo Release `vX.Y.Z-build.N`.
  Trước khi phát hành, tăng `project(VERSION ...)` trong `CMakeLists.txt` nếu có tính năng mới.
- Nên bật *Settings > Branches > Branch protection* cho `develop`, `main`: bắt buộc PR + CI xanh.
  (Repo private cần GitHub Pro — sinh viên đăng ký miễn phí qua GitHub Student Developer Pack.)

## Thành viên không lập trình đóng góp thế nào?

Mọi thành viên đều đóng góp qua GitHub (lịch sử commit là minh chứng phân công khi vấn đáp):
1. Mở **Issue** khi phát hiện lỗi dữ liệu/nghiệp vụ hoặc muốn đề xuất (gắn nhãn `database`, `report`, `app`).
2. Sửa tài liệu/báo cáo: tạo nhánh `docs/...` ngay trên giao diện web GitHub (*Edit file* → *Create a new branch* → PR).
3. Sửa script SQL phần mình phụ trách: dùng **GitHub Desktop** (Windows/macOS) để clone, tạo nhánh, commit, push, mở PR.

## Quy ước

### Commit (tiếng Việt, theo Conventional Commits)
```
feat(hocvien): thêm tìm kiếm theo số điện thoại phụ huynh
fix(db): sửa trigger trùng lịch khi lớp chưa có ngày kết thúc
docs(report): bổ sung mục 3.7 ràng buộc toàn vẹn
```

### CSDL (`database/`)
- Bảng VIẾT HOA không dấu (`HOCVIEN`), cột PascalCase (`MaHV`, `HoTen`), ràng buộc đặt tên
  `PK_`, `FK_<CON>_<CHA>`, `CK_<BANG>_<Cot>`, `UQ_`, `DF_`; tiền tố `usp_` (thủ tục), `fn_`, `vw_`, `trg_`.
- Chuỗi tiếng Việt luôn là `NVARCHAR` + tiền tố `N'...'`.
- Giữ tương thích **SQL Server 2012** (không `CREATE OR ALTER`, `DROP ... IF EXISTS`, `STRING_AGG`, `TRIM`, JSON).
- Đối tượng mới phải được `GRANT` cho đúng role trong `06_security.sql`.
- Sau khi sửa: chạy lại toàn bộ `scripts/db_init` để chắc chắn script chạy được từ đầu.

### C++ / Qt
- Tuân thủ chiều phụ thuộc trong [ARCHITECTURE.md](ARCHITECTURE.md): `presentation` không include `infrastructure`.
- Tên lớp/hàm nghiệp vụ dùng tiếng Việt không dấu (`HocVienService::themMoi`) cho khớp CSDL và báo cáo.
- Chuỗi hiển thị tiếng Việt viết thẳng trong `QStringLiteral("...")`, file mã nguồn UTF-8.
- Định dạng bằng `clang-format` (file `.clang-format` ở gốc repo; Qt Creator: *Beautifier*).
- Mỗi use case mới cần ít nhất một unit test trong `tests/` (dùng repository giả).

## Checklist Pull Request
- [ ] Build và unit test chạy được trên máy (`cmake --build`, `ctest`)
- [ ] Nếu sửa CSDL: `db_init` chạy lại từ đầu không lỗi, đã cập nhật `06_security.sql`
- [ ] Đã thử bằng tài khoản demo của vai trò liên quan
- [ ] Cập nhật tài liệu/báo cáo nếu thay đổi thiết kế

## Dùng Claude Code (được giảng viên cho phép)
- Đọc `CLAUDE.md` ở gốc repo: Claude Code tự áp dụng các quy ước trên.
- Mỗi thành viên phải **hiểu và giải thích được** phần mình phụ trách: khi nhờ Claude viết/sửa,
  yêu cầu Claude giải thích từng câu lệnh và tự chạy thử trong SSMS.
- Không commit thông tin bí mật (mật khẩu thật, file `.env`).
