# Hướng dẫn cài đặt môi trường

Có 3 mức sử dụng, chọn mức phù hợp:

| Mức | Ai | Cần cài |
|---|---|---|
| A. Chạy thử / chấm bài | Giảng viên, thành viên không lập trình | SQL Server + file cài QLTTTA (GitHub Releases) |
| B. Làm việc với CSDL | Mọi thành viên (trình bày phần CSDL) | SQL Server + SSMS hoặc VS Code (extension mssql) |
| C. Phát triển ứng dụng | Nhóm trưởng (+ Claude Code) | Mức B + Qt 6, CMake, Ninja, ODBC driver |

---

## 1. SQL Server và khởi tạo CSDL (bắt buộc với mọi mức)

### Windows
1. Cài **SQL Server 2022 Developer** hoặc **Express** (miễn phí) và **SSMS**.
2. Khởi tạo CSDL, chọn một trong hai cách:
   - PowerShell tại thư mục repo: `.\scripts\db_init.ps1` (Windows Authentication), hoặc
     `.\scripts\db_init.ps1 -Server "localhost\SQLEXPRESS"` nếu dùng bản Express.
   - Hoặc mở SSMS, chạy lần lượt `database/00_create_database.sql` → `07_seed_data.sql`
     (bật *Query > SQLCMD Mode* không bắt buộc).

### macOS (Apple Silicon) / Linux
SQL Server chạy trong Docker:
1. Cài Docker Desktop, bật *Settings > General > Use Rosetta for x86_64/amd64 emulation*.
2. Tạo file `.env` ở thư mục gốc repo: `MSSQL_SA_PASSWORD=<mật khẩu mạnh>`, rồi `docker compose up -d`
   (lệnh này đồng nghĩa bạn chấp nhận điều khoản SQL Server Developer Edition).
3. Khởi tạo CSDL (dùng sqlcmd có sẵn trong container):
   ```bash
   SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker imcp-mssql
   ```
4. Xem/chạy SQL: VS Code + extension **SQL Server (mssql)**, kết nối `localhost,1433`, user `sa`.

> Script tương thích SQL Server **2012 trở lên** (không dùng `CREATE OR ALTER`, `STRING_AGG`...).
> Dữ liệu mẫu tính ngày **tương đối theo ngày chạy**, nên chạy lại `db_init` trước buổi báo cáo
> để có lớp đang học, doanh thu tháng hiện tại...

### Tài khoản demo (mật khẩu chung: `Demo@2026`)

| Tên đăng nhập | Vai trò | Thấy được |
|---|---|---|
| `ql_quan` | Quản lý | Toàn bộ: học viên, lớp, công nợ, doanh thu, lương, tài khoản |
| `gvu_lan` | Giáo vụ (CN Quận 1) | Học viên, lớp, lịch học, kết quả, công nợ (không xem lương/doanh thu) |
| `gvu_ha` | Giáo vụ (CN Thủ Đức) | như trên |
| `kt_minh` | Kế toán | Học viên (chỉ xem), công nợ, doanh thu, lương |
| `kt_tung` | Kế toán | như trên |
| `gv_john`, `gv_hoanganh`, `gv_hoa`, `gv_bao` | Giáo viên | Chỉ lớp, lịch dạy, lương của chính mình |

Đây là **user của SQL Server** (contained database user) nên cũng đăng nhập được bằng SSMS
(chọn *Options > Connection Properties > Connect to database: QLTTTA*) để minh họa phân quyền.
Đổi mật khẩu ngay nếu triển khai thật.

---

## 2. Chạy ứng dụng từ file cài (mức A)

Tải file trong mục **Releases** của repo (giảng viên được mời làm collaborator để tải):

- **Windows**: `QLTTTA-x.y.z-windows-x64-setup.exe` (không cần quyền admin) hoặc bản `portable.zip`.
  SmartScreen cảnh báo → *More info* → *Run anyway*.
- **macOS (Apple Silicon)**: mở `.dmg`, kéo `QLTTTA.app` vào Applications. Lần đầu mở bị chặn →
  *System Settings > Privacy & Security > Open Anyway* (hoặc `xattr -dr com.apple.quarantine /Applications/QLTTTA.app`).
  Bản macOS đã kèm driver FreeTDS, không cần cài thêm.

Màn hình đăng nhập → *Cấu hình máy chủ*: `localhost,1433` (Docker) hoặc `localhost` / `TEN-MAY\SQLEXPRESS` (Windows), CSDL `QLTTTA`.

Kiểm tra kết nối không cần giao diện (chẩn đoán lỗi):
```bash
QLTTTA_USER=ql_quan QLTTTA_PASSWORD='Demo@2026' /Applications/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection
```

---

## 3. Môi trường phát triển (mức C)

### macOS
```bash
brew install qt qt-unixodbc unixodbc freetds cmake ninja
# Driver Microsoft (tùy chọn, ứng dụng dùng FreeTDS nếu không có). Bạn sẽ được hỏi đồng ý EULA:
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18

cmake --preset macos-debug
cmake --build --preset macos-debug
ctest --preset macos-debug
open build/macos-debug/src/app/QLTTTA.app
```
Mở bằng **Qt Creator** (*File > Open File or Project > CMakeLists.txt*) hoặc VS Code (extension CMake Tools).

### Windows
1. Cài **Qt Online Installer** (cần tài khoản Qt miễn phí), chọn:
   *Qt 6.8.x > MinGW 64-bit*, *Developer and Designer Tools > MinGW 13.1 64-bit, CMake, Ninja*, *Qt Creator*.
2. Mở Qt Creator → *Open Project* → chọn `CMakeLists.txt` → chọn kit *Desktop Qt 6.8.x MinGW 64-bit* → Run.
3. Dòng lệnh (PowerShell, đã thêm `C:\Qt\Tools\mingw1310_64\bin`, `C:\Qt\Tools\Ninja`, `C:\Qt\Tools\CMake_64\bin` vào PATH):
   ```powershell
   $env:QT_ROOT_DIR = "C:\Qt\6.8.3\mingw_64"
   cmake --preset windows-debug; cmake --build --preset windows-debug; ctest --preset windows-debug
   ```

### Kiểm thử end-to-end qua giao diện (cần CSDL đã nạp dữ liệu mẫu)
Bài test `tests/tst_e2e_gui.cpp` gõ phím, bấm nút trên các màn hình thật (đăng nhập, học viên, giáo viên,
kế toán, đổi mật khẩu) với CSDL thật; dữ liệu thêm trong lúc test được xóa lại. Không đặt mật khẩu thì test tự SKIP (CI).
```bash
QLTTTA_E2E_PASSWORD='Demo@2026' ctest --preset macos-debug -R e2e --output-on-failure
```

### Đóng gói file cài trên máy cá nhân
- macOS: `./scripts/package-macos.sh` → `dist/QLTTTA-x.y.z-macos-arm64.dmg`
- Windows: cài thêm Inno Setup 6, chạy `.\scripts\package-windows.ps1` → `dist\...-setup.exe` và `...-portable.zip`

CI tự làm việc này khi merge vào `main` (xem [CONTRIBUTING.md](CONTRIBUTING.md)).

### Chụp ảnh màn hình cho báo cáo
```bash
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' ./build/macos-debug/tools/qlttta_screenshots
# ảnh lưu ở docs/report/images/screens
```

---

## 4. Xử lý sự cố thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `SSL Provider: OpenSSL library could not be loaded` (driver Microsoft trên macOS) | Driver tìm OpenSSL ở `/opt/homebrew/opt/openssl`: `ln -s openssl@3 /opt/homebrew/opt/openssl` |
| CMake báo trình biên dịch "broken", lỗi `tapi ... unknown architecture arm64e` | SDK của Command Line Tools mới hơn Xcode. Thêm `-DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` khi configure (hoặc `EXTRA_CMAKE_ARGS` cho script đóng gói) |
| Ứng dụng báo "Không kết nối được máy chủ" | Kiểm tra container/dịch vụ SQL Server, cổng 1433, tường lửa; Windows Express dùng `localhost\SQLEXPRESS` và bật TCP/IP trong SQL Server Configuration Manager |
| "Sai tên đăng nhập..." khi đăng nhập bằng SSMS với user demo | Phải chọn database `QLTTTA` trong Connection Properties (user nằm trong CSDL, không phải login cấp server) |
| `EXECUTE permission was denied on fn_...` trên SQL Server 2019+ | Chạy lại `00_create_database.sql` (đã tắt Scalar UDF Inlining) hoặc `ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF` |
| Dashboard "Buổi học hôm nay", ngày tạo tài khoản... lệch 1 ngày / 7 giờ (SQL Server trong Docker) | Container chạy giờ UTC. `docker-compose.yml` đã đặt `TZ=Asia/Ho_Chi_Minh`; container tạo bằng `docker run` thì thêm `-e TZ=Asia/Ho_Chi_Minh` (phải tạo lại container), rồi chạy lại `db_init` |
| Font tiếng Việt lỗi trong script khi chạy sqlcmd | Thêm `-f 65001` (UTF-8) và `-I` (QUOTED_IDENTIFIER) như trong `scripts/db_init` |
