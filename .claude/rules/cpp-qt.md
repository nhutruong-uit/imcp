---
paths:
  - "src/**"
  - "tools/**"
  - "CMakeLists.txt"
---
# Quy tắc C++ / Qt (src/, tools/)

Bổ sung cho mục "C++ / Qt" trong `CLAUDE.md` và cookbook `docs/ARCHITECTURE.md` mục 4.

## Bố cục một module (mẫu: Học viên) - đủ 7 phần, đúng thư mục
| Tầng | File | Ghi chú |
|---|---|---|
| domain | `src/domain/entities/GhiDanh.{h,cpp}` | struct dữ liệu + `kiemTra()` trả `QStringList` lỗi |
| application | `src/application/ports/IGhiDanhRepository.h` | interface thuần ảo, trả `Result<T>`/`VoidResult` |
| application | `src/application/services/GhiDanhService.{h,cpp}` | use case: kiểm tra quy tắc rồi gọi port |
| infrastructure | `src/infrastructure/repositories/SqlGhiDanhRepository.{h,cpp}` | **SQL duy nhất ở đây**, gọi `usp_` |
| presentation | `src/presentation/ghidanh/GhiDanhPage.{h,cpp}` (+ `.ui` nếu là form) | không include `infrastructure/` |
| app | `AppContainer` + `AppServices` | nối repository → service → trang |
| phân quyền | `ChucNang::...` trong `PhanQuyen.cpp`, `MainWindow::trangCho` | menu theo vai trò |
Thêm file mới vào `CMakeLists.txt` của đúng tầng.

## Đặt tên
- Lớp/struct PascalCase tiếng Việt không dấu (`GhiDanhService`); hàm, biến camelCase (`themMoi`, `boLoc`).
- Thành viên lớp tiền tố `m_` (`m_repository`); hằng/enum PascalCase (`ChucNang::CongNo`).
- Hàm repository: `timKiem`, `layTheoMa`, `them`, `capNhat`, `xoa`; service: `timKiem`, `layChiTiet`, `themMoi`, `capNhat`, `xoa`.
- `objectName` cho widget mà test cần tìm: camelCase tiếng Việt (`tuKhoa`, `nutThem`, `bangHocVien`);
  nhãn cần kiểm tra dùng `setProperty("vaiTro", "...")`. objectName PascalCase (`PageTitle`, `ErrorText`) dành cho style (Theme).

## Mẫu code
- Lỗi đi qua `Result<T>`/`VoidResult`, không ném exception qua tầng:
  `if (!q.exec()) return Result<QString>::failure(loiCua(q));`
- Gọi thủ tục có OUTPUT: lô lệnh `SET NOCOUNT ON; DECLARE @x ...; EXEC ... @Out = @x OUTPUT; SELECT @x;`,
  tham số `?` + `addBindValue`, NULL qua `SqlHelpers::chuoiHoacNull`. Không nối chuỗi giá trị vào SQL.
- Chuỗi giao diện: `QStringLiteral("Tiếng Việt có dấu")`. Tiền/ngày: `Format::tien`, `Format::ngay`.
- Hộp thoại: `UiHelpers::baoLoi`, `UiHelpers::xacNhan` (nút "Đồng ý/Không"); nút: `UiHelpers::nutChinh/nutPhu`.
- Màu, font chỉ đặt trong `Theme`/stylesheet - không hard-code màu trong trang (trừ biểu đồ).
- Kiểm tra quyền **không** chỉ ở giao diện: ẩn nút là UX, quyền thật do CSDL (GRANT) quyết định.

## Format và include
- Format theo `.clang-format` (LLVM, 4 cách, 110 cột). Chỉ format phần đã sửa: `git clang-format` (hoặc
  `git clang-format --staged`). Không reformat cả file cũ - repo còn file chưa theo chuẩn, sẽ format riêng một lần.
- Thứ tự include: header của chính file → header dự án (`"domain/..."`, `"application/..."`) → Qt (`<QString>`) → STL.
- C++17, Qt ≥ 6.5; thêm include đủ cho GCC/MinGW (CI Windows) - đừng dựa vào include gián tiếp của Clang.
