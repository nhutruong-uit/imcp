# QLTTTA - Hệ thống quản lý trung tâm tiếng Anh

Đồ án môn **IE103 - Quản lý thông tin** · Lớp IE103.Q21.VB2 · Trường ĐH Công nghệ Thông tin - ĐHQG TP.HCM
Giảng viên hướng dẫn: TS. Võ Phương Bình · **Nhóm 1**

Ứng dụng desktop chạy trên **Windows và macOS** quản lý một chuỗi trung tâm tiếng Anh: học viên, khóa học,
lớp học và lịch học, ghi danh, học phí và công nợ, điểm danh, điểm số, chứng nhận, lương giáo viên.
Trọng tâm là **cơ sở dữ liệu SQL Server**: ràng buộc toàn vẹn, stored procedure, function, trigger,
cursor, view, phân quyền, sao lưu/phục hồi, XML/XQuery.

| Thành phần | Công nghệ |
|---|---|
| CSDL | Microsoft SQL Server 2012+ (T-SQL), contained database users |
| Ứng dụng | C++17, Qt 6 Widgets, Qt SQL (ODBC) |
| Kiến trúc | Clean Architecture: domain / application / infrastructure / presentation |
| Build & CI | CMake + Ninja, GitHub Actions (build, test, đóng gói `.exe`/`.zip`/`.dmg`) |

## Bắt đầu nhanh

```bash
# 1. Khởi tạo CSDL (SQL Server đang chạy, ví dụ Docker container "sql2022")
SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker sql2022

# 2. Build và chạy ứng dụng (macOS, Qt từ Homebrew)
cmake --preset macos-debug && cmake --build --preset macos-debug
open build/macos-debug/src/app/QLTTTA.app
```

Windows: xem [docs/SETUP.md](docs/SETUP.md). Tài khoản demo (quản lý, giáo vụ, kế toán, giáo viên) cũng được liệt kê ở đó.

## Cấu trúc thư mục

```
database/        Script SQL Server: 00 tạo CSDL ... 07 dữ liệu mẫu, 08-11 demo truy vấn/backup/import/phân tán
src/domain/        Thực thể + quy tắc nghiệp vụ (không phụ thuộc CSDL, giao diện)
src/application/   Use case (service) + port (interface repository) + ma trận phân quyền
src/infrastructure/ Kết nối ODBC, repository gọi stored procedure, lưu cấu hình
src/presentation/  Giao diện Qt Widgets (menu theo vai trò, form, báo cáo PDF/Excel)
src/app/           Composition root (khởi tạo và nối các tầng)
tests/             Unit test (Qt Test) với repository giả
tools/             Công cụ chụp màn hình tự động cho báo cáo
packaging/         Icon, Info.plist, bộ cài Inno Setup, hướng dẫn cài đặt
scripts/           Khởi tạo CSDL, đóng gói macOS/Windows
docs/              Tài liệu + báo cáo đồ án (docs/report)
```

## Tài liệu

- [docs/SETUP.md](docs/SETUP.md) - cài môi trường trên macOS/Windows, khởi tạo CSDL, tài khoản demo, đóng gói
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Clean Architecture, luồng xử lý, cách thêm một module mới
- [docs/DATABASE.md](docs/DATABASE.md) - thiết kế CSDL, danh mục đối tượng, ánh xạ với nội dung môn học
- [docs/PLAN.md](docs/PLAN.md) - kế hoạch đến ngày nộp, phân công thành viên, chuẩn bị vấn đáp
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - quy trình Git/GitHub, quy ước code, dùng Claude Code
- [docs/report/](docs/report/) - báo cáo đồ án (.docx, .pdf) và script sinh báo cáo

## Thành viên

| STT | Họ và tên | MSSV | Phụ trách chính |
|---|---|---|---|
| 1 | Trương Quang Như (nhóm trưởng) | 25540022 | Kiến trúc, lập trình ứng dụng, CI/CD, tích hợp |
| 2 | Đỗ Phạm Minh Trâm | 25540042 | Khảo sát nghiệp vụ, phân tích yêu cầu, ERD/CD |
| 3 | Nguyễn Việt Phú | 25540025 | Mô hình quan hệ, chuẩn hóa, ràng buộc toàn vẹn, trigger |
| 4 | Đỗ Bình Dương | 25540008 | Stored procedure, function, cursor, truy vấn SQL, XQuery |
| 5 | Nguyễn Bảo Giang | 25540009 | An ninh dữ liệu, backup/restore, import/export, CSDL tiên tiến |

Chi tiết phân công: [docs/PLAN.md](docs/PLAN.md).
