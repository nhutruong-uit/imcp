"""Chapter 6 (troubleshooting) and the appendices (command summary, parts still to be written)."""
from chapters.common import demo_accounts


def chapter6(g):
    g.h1("CHƯƠNG 6. XỬ LÝ SỰ CỐ")

    g.h2("6.1. Kiểm tra kết nối không cần giao diện")
    g.p("Ứng dụng có chế độ kiểm tra kết nối chạy trên dòng lệnh: đăng nhập bằng tài khoản cho trước với cấu "
        "hình máy chủ đã lưu (hoặc máy chủ ghi trong biến `QLTTTA_SERVER`), in kết quả rồi thoát. Kết quả là "
        "`OK: <họ tên> (<vai trò>)` hoặc `ERROR: <thông báo lỗi>`.")
    user = demo_accounts()[0][0]
    g.code("Terminal (macOS)",
           f"QLTTTA_USER={user} QLTTTA_PASSWORD='<mật khẩu>' \\\n"
           "  /Applications/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection", lang="text")
    g.p("Trên Windows, QLTTTA là ứng dụng giao diện nên PowerShell không chờ nó chạy xong và không hiện chữ nó in "
        "ra. Thêm `| Out-Host` ở cuối lệnh: PowerShell chờ kết quả, in dòng `OK`/`ERROR`, và `$LASTEXITCODE` cho "
        "mã thoát (0 hoặc 1). Biến `QLTTTA_SERVER` là tùy chọn (ví dụ `localhost` cho SQL Server cài trên máy).")
    g.code("PowerShell (Windows)",
           f"$env:QLTTTA_USER = '{user}'; $env:QLTTTA_PASSWORD = '<mật khẩu>'; $env:QLTTTA_SERVER = 'localhost'\n"
           "& \"<thư mục chứa QLTTTA.exe>\\QLTTTA.exe\" --check-connection | Out-Host\n"
           "$LASTEXITCODE", lang="text")

    g.h2("6.2. Lỗi thường gặp")
    g.table(["Hiện tượng / thông báo", "Nguyên nhân thường gặp", "Cách xử lý"], [
        ["**Không kết nối được máy chủ SQL Server**", "SQL Server chưa chạy; sai địa chỉ hoặc cổng; tường lửa "
         "chặn cổng 1433",
         "macOS/Docker: mở Docker Desktop, `docker ps` phải thấy container `Up`, nếu không chạy "
         "`docker compose start`. Windows: kiểm tra dịch vụ SQL Server đang chạy, ô Máy chủ đúng instance "
         "(`localhost\\SQLEXPRESS`), đã bật TCP/IP (mục 2.3.3)."],
        ["**Sai tên đăng nhập hoặc mật khẩu, hoặc tài khoản đã bị khóa**",
         "Gõ sai; mật khẩu đã đổi; tài khoản bị khóa; CSDL vừa khởi tạo lại",
         "Gõ lại (phân biệt hoa/thường). Sau khi chạy lại script khởi tạo, mật khẩu demo trở về mặc định. Nhờ "
         "quản lý kiểm tra trạng thái tài khoản ở màn hình Tài khoản."],
        ["**Không mở được cơ sở dữ liệu**", "Ô CSDL sai; chưa chạy script khởi tạo",
         "Ô CSDL phải là `QLTTTA`; chạy lại bước khởi tạo CSDL (Chương 2)."],
        ["**Lỗi chứng chỉ bảo mật của máy chủ**", "Máy chủ dùng chứng chỉ tự ký",
         "Bật **Tin cậy chứng chỉ máy chủ** trong Cấu hình máy chủ; trên Windows nên cài ODBC Driver 18."],
        ["Không lưu được file Excel/PDF (hiện thông báo lỗi khi xuất)",
         "File cùng tên đang mở trong Excel/trình đọc PDF, hoặc thư mục không cho ghi",
         "Đóng file đang mở hoặc chọn thư mục khác rồi xuất lại."],
        ["**Không tìm thấy ODBC Driver cho SQL Server trên máy** (Windows)", "Máy không có driver phù hợp",
         "Cài **Microsoft ODBC Driver 18 for SQL Server** rồi mở lại ứng dụng."],
        ["**Thiếu plugin Qt ODBC (qsqlodbc)**", "Bộ cài bị hỏng hoặc thiếu file",
         "Cài lại ứng dụng (hoặc giải nén lại bản portable)."],
        ["macOS báo không mở được QLTTTA", "Ứng dụng không đăng ký với Apple (Gatekeeper)",
         "**System Settings > Privacy & Security > Open Anyway**, hoặc lệnh `xattr` ở mục 3.2."],
        ["macOS báo không dùng được phiên bản QLTTTA này với phiên bản macOS hiện tại",
         "macOS cũ hơn mức ứng dụng cần (mục 1.4)", "Nâng cấp macOS (**System Settings > General > Software "
         "Update**) rồi mở lại ứng dụng."],
        ["Bộ cài báo **QLTTTA needs Windows 10 version 1809 or later...**", "Windows cũ hơn mức ứng dụng cần "
         "(mục 1.4)", "Cập nhật Windows (**Settings > Windows Update**) rồi chạy lại bộ cài."],
        ["Windows hiện **Windows protected your PC**", "SmartScreen chặn ứng dụng chưa ký số",
         "Bấm **More info > Run anyway**."],
        ["Trang Tổng quan: buổi học hôm nay, doanh thu tháng này bằng 0; Lịch học - điểm danh của tuần này trống",
         "Dữ liệu mẫu đã cũ (ngày tính theo lần chạy script khởi tạo)", "Chạy lại bước khởi tạo CSDL (mục 2.4)."],
        ["Giờ tạo tài khoản, giờ đăng nhập cuối lệch vài tiếng",
         "Thời điểm được lưu theo giờ UTC và hiển thị theo múi giờ của máy chạy ứng dụng",
         "Kiểm tra cài đặt múi giờ (time zone) của máy tính."],
        ["**Bạn không có quyền thực hiện thao tác này (SQL Server từ chối)**",
         "Vai trò không được phép thao tác đó", "Đăng nhập bằng tài khoản có vai trò phù hợp (Bảng 1.1)."],
        ["**Học viên đang có dữ liệu ghi danh, không thể xóa**", "Học viên đã ghi danh lớp",
         "Không xóa; sửa trạng thái học viên thành **Ngừng học** (mục 5.2.4)."],
        ["Script `db_init` dừng giữa chừng", "Sai mật khẩu `sa`; SQL Server chưa khởi động xong; chạy không "
         "phải từ thư mục mã nguồn",
         "Chờ 20-30 giây sau `docker compose up -d` rồi chạy lại; kiểm tra mật khẩu trong `.env`; đứng ở thư "
         "mục gốc mã nguồn."],
        ["Chữ tiếng Việt bị lỗi khi tự chạy script bằng `sqlcmd`", "Thiếu tham số mã UTF-8",
         "Thêm `-f 65001` và `-I` như script `db_init`, hoặc dùng `db_init`."],
        ["Windows: **Sai tên đăng nhập hoặc mật khẩu** với tài khoản demo dù gõ đúng (SQL Server vừa cài)",
         "SQL Server chỉ bật Windows Authentication (mặc định khi cài)",
         "Bật Mixed Mode bằng hai lệnh ở mục 2.3.1 (PowerShell quyền quản trị)."],
        ["Windows: **Không kết nối được máy chủ SQL Server** khi ô Máy chủ là `localhost,1433`",
         "TCP/IP của SQL Server đang tắt (mặc định của bản Developer/Express)",
         "Đổi ô Máy chủ thành `localhost` (hoặc `localhost\\SQLEXPRESS`), hoặc bật TCP/IP (mục 2.3.3)."],
        ["Windows, máy không cài SQL Server (Docker hoặc máy chủ khác): **Không kết nối được máy chủ SQL Server**, "
         "kèm dòng **Driver \"SQL Server\" có sẵn của Windows không kết nối được**",
         "Máy chưa có ODBC Driver 18/17; driver \"SQL Server\" có sẵn của Windows không "
         "đăng nhập được", "Cài **Microsoft ODBC Driver 18 for SQL Server** (mục 2.3.2) rồi mở lại ứng dụng."],
        ["Trình cài SQL Server báo *This version of the installer is no longer supported*",
         "Trình cài SQL Server 2022 đã bị Microsoft ngừng", "Tải bản SQL Server 2025 (mục 2.3.1)."],
        ["PowerShell báo `running scripts is disabled on this system`", "Windows chưa cho chạy script `.ps1`",
         "`powershell -ExecutionPolicy Bypass -File .\\scripts\\<tên script>.ps1 ...`"],
        ["PowerShell báo `sqlcmd` *is not recognized*", "Cửa sổ PowerShell mở từ trước khi cài SQL Server",
         "Mở cửa sổ PowerShell mới; vẫn lỗi thì `winget install Microsoft.Sqlcmd`."],
    ], widths_cm=[4.6, 4.2, 7.2], caption="Lỗi thường gặp và cách xử lý", size=9.5)

    g.h2("6.3. Khi cần hỗ trợ thêm")
    g.p("Tài liệu kỹ thuật chi tiết nằm trong mã nguồn: `docs/SETUP.md` (cài đặt môi trường, kiểm thử), "
        "`docs/DATABASE.md` (cấu trúc CSDL, phân quyền), `docs/ARCHITECTURE.md` (kiến trúc ứng dụng). Khi báo "
        "lỗi cho nhóm, gửi kèm: hệ điều hành, cách cài SQL Server (Docker hay cài trực tiếp), giá trị ô Máy "
        "chủ, thông báo lỗi nguyên văn và kết quả lệnh kiểm tra kết nối ở mục 6.1.")


def appendix_commands(g):
    g.h1_unnumbered("PHỤ LỤC A. TÓM TẮT LỆNH")
    g.table(["Việc", "macOS (Terminal)", "Windows (PowerShell)"], [
        ["Tải mã nguồn", "`git clone https://github.com/nhutruong-uit/imcp.git`", "Như macOS"],
        ["Bật SQL Server (Docker)", "`docker compose up -d`", "`docker compose up -d`"],
        ["Khởi tạo CSDL (Docker)", "`SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker imcp-mssql`",
         "`$env:SQL_PASSWORD = '<mật khẩu sa>'`\n`.\\scripts\\db_init.ps1 -Docker imcp-mssql`"],
        ["Khởi tạo CSDL (SQL Server cài trên máy)", "-",
         "Developer: `.\\scripts\\db_init.ps1`\nExpress: `.\\scripts\\db_init.ps1 -Server \"localhost\\SQLEXPRESS\"`"],
        ["Tắt / bật SQL Server (Docker)", "`docker compose stop` / `docker compose start`", "Như macOS"],
        ["Mở ứng dụng lần đầu", "`xattr -dr com.apple.quarantine /Applications/QLTTTA.app`",
         "SmartScreen: **More info > Run anyway**"],
    ], widths_cm=[3.6, 6.4, 6.0], size=9.5, bold_first_col=True)


def appendix_placeholders(g):
    """List of the placeholders left in the document (only while there are some)."""
    if not g.placeholders:
        return
    g.h1_unnumbered("PHỤ LỤC B. CÁC MỤC CẦN BỔ SUNG")
    g.p("Danh sách sinh tự động từ các khung **[CẦN BỔ SUNG]** trong tài liệu. Viết tiếp trong "
        "`docs/user-guide/chapters/*.py` (thay lời gọi `g.placeholder(...)` bằng nội dung thật; ảnh Windows lưu "
        "vào `docs/user-guide/images/windows/` với đúng tên file ghi trong khung) rồi chạy lại "
        "`python3 docs/user-guide/build_user_guide.py`. Phụ lục này tự biến mất khi không còn mục nào.")
    g.table(["STT", "Mục", "Nền tảng", "Nội dung cần bổ sung"],
            [[str(i), section, platform, text] for i, (section, platform, text) in enumerate(g.placeholders, 1)],
            widths_cm=[1.2, 1.8, 2.2, 10.8], size=9.5, align=["center", "center", "center", "left"])
