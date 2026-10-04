"""Chapters 1-3: introduction, SQL Server + database, installing the application."""
from chapters.common import FEATURES, ROLES, WINDOWS_IMAGES, allowed_features, app_version


def chapter1(g):
    g.h1("CHƯƠNG 1. GIỚI THIỆU")

    g.h2("1.1. Mục đích của tài liệu")
    g.p("Tài liệu hướng dẫn cài đặt và sử dụng phần mềm **QLTTTA** (Quản lý Trung tâm Tiếng Anh) - sản phẩm "
        "đồ án môn Quản lý thông tin (IE103) của Nhóm 1. Nội dung gồm: chuẩn bị máy chủ SQL Server và cơ sở "
        "dữ liệu (CSDL), cài ứng dụng trên **macOS** và **Windows**, đăng nhập, và cách dùng từng chức năng "
        "theo vai trò người dùng. Chương cuối tổng hợp các lỗi thường gặp và cách khắc phục.")

    g.h2("1.2. Tổng quan phần mềm")
    g.p("QLTTTA là ứng dụng desktop (Qt 6) quản lý chuỗi trung tâm tiếng Anh: học viên, khóa học, lớp học "
        "và lịch học, ghi danh, học phí và công nợ, điểm danh, kết quả học tập, lương giáo viên. Toàn bộ dữ "
        "liệu nằm trong CSDL **SQL Server**; mỗi người dùng đăng nhập bằng một tài khoản SQL Server thật, vì "
        "vậy chính CSDL quyết định người dùng được xem và sửa dữ liệu nào. Ứng dụng chỉ là phần giao diện.")
    g.bullets([
        "**Menu theo vai trò**: mỗi vai trò (quản lý, giáo vụ, kế toán, giáo viên) chỉ thấy các chức năng "
        "của mình.",
        "**Form nhập liệu cho mọi bước nghiệp vụ**: danh mục (khóa học, giáo viên, nhân viên, chi nhánh - phòng "
        "học, khuyến mãi), học viên, kiểm tra xếp lớp, mở lớp và lịch học, ghi danh, thu học phí và in phiếu thu, "
        "điểm danh, nhập điểm, xét kết quả, chốt lương, tài khoản, sao lưu; dữ liệu được kiểm tra cả ở ứng dụng "
        "lẫn CSDL.",
        "**Danh sách tra cứu** có lọc nhanh, sắp xếp theo cột, dòng tổng cộng, xuất **Excel (CSV)** và "
        "**báo cáo PDF**.",
        "**Hai ngôn ngữ giao diện**: tiếng Việt (mặc định) và tiếng Anh, đổi ngay khi đang dùng.",
        "**Chạy trên macOS và Windows**, kết nối tới SQL Server trên cùng máy hoặc trên máy khác trong mạng.",
    ])

    g.h2("1.3. Vai trò người dùng và chức năng")
    g.p("Bảng dưới liệt kê các mục menu mà mỗi vai trò nhìn thấy (đọc trực tiếp từ mã nguồn của ứng dụng). "
        "Ngoài việc ẩn/hiện menu, SQL Server còn kiểm tra quyền (`GRANT`/`DENY`) ở mọi thao tác: nếu một "
        "người dùng cố truy cập dữ liệu ngoài quyền, CSDL vẫn từ chối.")
    allowed = allowed_features()
    roles = [r for r in ROLES if r in allowed]
    rows = [[FEATURES[f][1], FEATURES[f][0]] + ["✓" if f in allowed[r] else "" for r in roles]
            for f in FEATURES]
    g.table(["Nhóm menu", "Chức năng"] + [ROLES[r] for r in roles], rows,
            widths_cm=[2.8, 4.4] + [2.2] * len(roles), caption="Chức năng hiển thị theo vai trò", size=10.5,
            align=["left", "left"] + ["center"] * len(roles))
    g.bullets([
        "**Quản lý** và **Giáo vụ** được thêm, sửa, xóa học viên; **Kế toán** chỉ xem danh sách học viên.",
        "**Giáo vụ** chỉ xem **Khóa học** và **Giáo viên**; các danh mục do **Quản lý** cập nhật.",
        "**Giáo viên** chỉ thấy lớp mình dạy, lịch dạy, sổ điểm và bảng lương của chính mình; chỉ điểm danh, "
        "nhập điểm cho lớp mình dạy.",
        "**Doanh thu tháng này** trên trang Tổng quan chỉ hiện với vai trò có quyền xem doanh thu "
        "(quản lý, kế toán); giáo vụ thấy dòng chữ \"Không có quyền\".",
    ])

    g.h2("1.4. Yêu cầu hệ thống")
    g.table(["Thành phần", "macOS", "Windows"], [
        ["Hệ điều hành", "macOS 12 Monterey trở lên, máy chip Apple Silicon", "Windows 10 hoặc 11, 64-bit"],
        ["SQL Server", "SQL Server 2022 chạy trong Docker Desktop",
         "SQL Server 2012+ cài trên máy (Express/Developer) hoặc chạy trong Docker Desktop"],
        ["Trình điều khiển (driver) kết nối", "Có sẵn trong ứng dụng (FreeTDS), không cần cài thêm",
         "ODBC Driver 18 (hoặc 17) for SQL Server: có sẵn khi máy đã cài SQL Server 2025, máy khác cần cài "
         "thêm (mục 2.3.2)"],
        ["Màn hình", "Tối thiểu 1024 × 640", "Tối thiểu 1024 × 640"],
        ["Quyền quản trị máy", "Cần khi cài Docker Desktop", "Cần khi cài SQL Server; bản cài ứng dụng "
                                                             "không cần quyền Administrator"],
    ], widths_cm=[3.4, 6.0, 6.6], caption="Yêu cầu phần cứng và phần mềm", size=10.5, bold_first_col=True)

    g.h2("1.5. Các bước cài đặt tổng quát")
    g.p("Dù dùng hệ điều hành nào, quy trình đều gồm bốn bước. Phương án SQL Server cho từng loại máy ở "
        "Bảng 1.3 bên dưới.")
    g.steps([
        "Chuẩn bị **SQL Server** (Docker hoặc cài trực tiếp) - Chương 2.",
        "**Khởi tạo CSDL** `QLTTTA` và dữ liệu mẫu bằng các script trong thư mục `database/` - Chương 2.",
        "**Cài ứng dụng** QLTTTA - Chương 3.",
        "Mở ứng dụng, khai báo **máy chủ** trong *Cấu hình máy chủ* và **đăng nhập** - Chương 4.",
    ])
    g.table(["Máy", "Phương án SQL Server khuyên dùng", "Địa chỉ máy chủ khai báo trong ứng dụng"], [
        ["macOS", "A - Docker (mục 2.2)", "`localhost,1433`"],
        ["Windows, đã cài SQL Server Express", "B - cài trực tiếp (mục 2.3)", "`localhost\\SQLEXPRESS`"],
        ["Windows, đã cài SQL Server Developer (instance mặc định)", "B - cài trực tiếp (mục 2.3)",
         "`localhost`"],
        ["Windows, đã có Docker Desktop", "A - Docker (mục 2.2)", "`localhost,1433`"],
        ["Máy chạy ứng dụng khác máy chạy SQL Server", "A hoặc B trên máy chủ",
         "`<địa chỉ IP>,1433`, ví dụ `192.168.1.10,1433`"],
    ], widths_cm=[5.2, 4.8, 6.0], caption="Chọn phương án SQL Server theo máy", size=10.5)

    g.h2("1.6. Quy ước trình bày")
    g.bullets([
        "Chữ **đậm**: tên nút, menu, ô nhập trên màn hình (theo giao diện tiếng Việt), ví dụ **Đăng nhập**.",
        "Chữ `đỏ đơn sắc`: lệnh, đường dẫn, giá trị cần gõ chính xác, ví dụ `localhost,1433`.",
        "`<...>`: phần cần thay bằng giá trị của bạn, ví dụ `<mật khẩu sa>`.",
        "Lệnh macOS chạy trong ứng dụng **Terminal**; lệnh Windows chạy trong **PowerShell**, đứng ở thư mục "
        "mã nguồn đã tải về (mục 2.1).",
    ])
    g.tip("Khung xanh lá là mẹo giúp thao tác nhanh hơn; khung đỏ là lưu ý để tránh mất dữ liệu hoặc lỗi.")
    g.placeholder("Khung vàng đánh dấu phần chưa viết xong (thường là các bước cần kiểm tra trên máy "
                  "Windows). Tìm nhanh bằng Ctrl+F với từ khóa \"CẦN BỔ SUNG\"; danh sách đầy đủ ở Phụ lục B.",
                  platform="ví dụ", listed=False)


def chapter2(g):
    g.h1("CHƯƠNG 2. CÀI ĐẶT SQL SERVER VÀ KHỞI TẠO CƠ SỞ DỮ LIỆU")
    g.p("Ứng dụng cần một máy chủ SQL Server có CSDL `QLTTTA`. Chương này hướng dẫn hai phương án: "
        "**A - Docker** (bắt buộc trên macOS, dùng được trên Windows) và **B - cài SQL Server trực tiếp trên "
        "Windows**. Chỉ cần làm **một** phương án. Bước khởi tạo CSDL dùng script của nhóm nên cần mã nguồn.")

    g.h2("2.1. Tải mã nguồn")
    g.p("Các script tạo CSDL nằm trong thư mục `database/` của kho mã nguồn "
        "`https://github.com/nhutruong-uit/imcp` (kho riêng tư: giảng viên được mời làm cộng tác viên). "
        "Có hai cách tải:")
    g.bullets([
        "Có Git: `git clone https://github.com/nhutruong-uit/imcp.git` rồi `cd imcp`.",
        "Không có Git: trên trang GitHub chọn **Code > Download ZIP**, giải nén, rồi mở Terminal/PowerShell "
        "tại thư mục vừa giải nén.",
    ])
    g.p("Các script `database/00_create_database.sql` → `database/07_seed_data.sql` tạo CSDL, bảng, hàm, view, "
        "thủ tục, trigger, phân quyền và dữ liệu mẫu (gồm các tài khoản demo ở mục 4.3). Các file 08-13 là "
        "script demo và kiểm thử, không cần chạy để dùng ứng dụng.")

    g.h2("2.2. Phương án A - SQL Server trong Docker")
    g.h3("2.2.1. Cài Docker Desktop")
    g.p("**macOS:**")
    g.steps([
        "Tải **Docker Desktop for Mac (Apple Silicon)** tại `https://www.docker.com/products/docker-desktop/`, "
        "mở file `.dmg` và kéo Docker vào **Applications**.",
        "Mở Docker Desktop, chờ biểu tượng cá voi trên thanh menu báo *Docker Desktop is running*.",
        "Vào **Settings > General**, bật **Use Rosetta for x86_64/amd64 emulation on Apple Silicon**, bấm "
        "**Apply & restart** (image SQL Server chỉ có bản x86-64, Rosetta giúp chạy nhanh và ổn định).",
    ])
    g.p("**Windows:**")
    g.placeholder("Các bước cài Docker Desktop trên Windows 10/11: yêu cầu WSL 2 (lệnh `wsl --install`, "
                  "khởi động lại máy), tải bộ cài, tùy chọn \"Use WSL 2 instead of Hyper-V\", kiểm tra bằng "
                  "`docker version`. Kiểm tra lại trên máy Windows và bổ sung ảnh nếu cần.")
    g.figure_or_placeholder(WINDOWS_IMAGES / "docker_desktop_running.png",
                            "Docker Desktop đang chạy trên Windows",
                            "cửa sổ Docker Desktop trên Windows ở trạng thái đang chạy (Engine running).")

    g.h3("2.2.2. Khởi động SQL Server")
    g.p("Tại thư mục mã nguồn có sẵn file `docker-compose.yml` mô tả container SQL Server 2022 tên "
        "`imcp-mssql` (cổng 1433, dữ liệu lưu trong volume `mssql-data`). Múi giờ của container không ảnh "
        "hưởng: CSDL lưu thời điểm theo giờ UTC và tự tính ngày theo giờ của trung tâm.")
    g.steps([
        "Tạo file `.env` ở thư mục gốc mã nguồn với nội dung một dòng `MSSQL_SA_PASSWORD=<mật khẩu sa>`. "
        "Mật khẩu của tài khoản quản trị `sa` phải từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký hiệu. "
        "File này chứa mật khẩu nên không bao giờ được đưa lên Git (đã có trong `.gitignore`).",
        "Chạy `docker compose up -d`. Lần đầu Docker tải image SQL Server (dung lượng lớn) nên mất vài phút. "
        "Chạy lệnh này nghĩa là bạn đồng ý điều khoản giấy phép SQL Server Developer Edition.",
        "Kiểm tra bằng `docker ps`: dòng `imcp-mssql` có trạng thái `Up`. Chờ thêm khoảng 20 giây để SQL "
        "Server khởi động xong trước khi khởi tạo CSDL.",
    ])
    g.p("Trên macOS, tạo file `.env` bằng Terminal:")
    g.code("Terminal (macOS)", "echo 'MSSQL_SA_PASSWORD=<mật khẩu sa>' > .env\ndocker compose up -d\ndocker ps",
           lang="text")
    g.placeholder("Cách tạo file `.env` trên Windows. Đề xuất dùng PowerShell "
                  "`Set-Content -Path .env -Value 'MSSQL_SA_PASSWORD=<mật khẩu sa>' -Encoding ascii` "
                  "(Notepad dễ lưu thành `.env.txt`). Kiểm tra `docker compose up -d` đọc được file này.")

    g.h3("2.2.3. Khởi tạo CSDL")
    g.p("Script `db_init` chạy lần lượt các file `00` → `07` bằng công cụ `sqlcmd` có sẵn trong container, "
        "nên máy không cần cài thêm gì. Thay `imcp-mssql` bằng tên container mà `docker ps` hiển thị nếu khác.")
    g.code("Terminal (macOS)", "SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker imcp-mssql",
           lang="text")
    g.code("PowerShell (Windows)", "$env:SQL_PASSWORD = '<mật khẩu sa>'\n"
                                   ".\\scripts\\db_init.ps1 -Docker imcp-mssql", lang="text")
    g.p("Khi thành công, dòng cuối cùng là `Done. The QLTTTA database is ready`. Nếu một file báo lỗi, script "
        "dừng ngay và in tên file đó (xem Chương 6).")
    g.tip("Nếu PowerShell báo `running scripts is disabled on this system` (Windows chưa cho chạy script), gọi "
          "script qua `powershell -ExecutionPolicy Bypass -File`, ví dụ "
          "`powershell -ExecutionPolicy Bypass -File .\\scripts\\db_init.ps1 -Docker imcp-mssql`. Tham số này chỉ "
          "có tác dụng cho lần chạy đó, không đổi cài đặt của máy.")

    g.h3("2.2.4. Bật, tắt SQL Server hằng ngày")
    g.table(["Việc cần làm", "Lệnh (chạy tại thư mục mã nguồn)"], [
        ["Tắt SQL Server (giữ nguyên dữ liệu)", "`docker compose stop`"],
        ["Bật lại SQL Server", "`docker compose start` (hoặc bấm ▶ ở container trong Docker Desktop)"],
        ["Xem trạng thái", "`docker ps`"],
    ], widths_cm=[6.0, 10.0], caption="Các lệnh Docker thường dùng", size=10.5)
    g.p("Container được đặt `restart: unless-stopped`: sau khi khởi động lại máy, SQL Server tự chạy khi "
        "Docker Desktop mở (trừ khi đã tắt bằng `docker compose stop`).")
    g.warning("Lệnh `docker compose down -v` xóa luôn volume `mssql-data`, tức là **mất toàn bộ CSDL**. Chỉ "
              "dùng khi muốn làm lại từ đầu, sau đó phải chạy lại bước 2.2.3.")

    g.h2("2.3. Phương án B - SQL Server cài trực tiếp trên Windows")
    g.h3("2.3.1. Cài SQL Server")
    g.p("Tải **SQL Server 2025 Express** hoặc **Developer** (đều miễn phí) từ trang của Microsoft "
        "`https://www.microsoft.com/sql-server/sql-server-downloads`. Trình cài SQL Server 2022 đã bị Microsoft "
        "ngừng (chạy sẽ báo *This version of the installer is no longer supported*); máy đã có sẵn SQL Server "
        "2012-2022 thì dùng luôn. Bản Express tạo instance tên `SQLEXPRESS` (địa chỉ `localhost\\SQLEXPRESS`); bản "
        "Developer tạo instance mặc định (địa chỉ `localhost`).")
    g.p("Ứng dụng đăng nhập bằng **tài khoản SQL Server** (không phải tài khoản Windows), nên máy chủ **bắt buộc** "
        "bật chế độ **Mixed Mode** (*SQL Server and Windows Authentication mode*). Cài theo mặc định (kiểu "
        "**Basic**, hoặc bằng `setup_dev.ps1`) thì SQL Server **chỉ bật Windows Authentication**: CSDL vẫn khởi "
        "tạo được, nhưng ứng dụng báo **Sai tên đăng nhập hoặc mật khẩu** dù gõ đúng. Chọn Mixed Mode ngay khi "
        "cài (kiểu cài **Custom**), hoặc bật sau khi cài bằng hai lệnh dưới đây trong PowerShell mở bằng quyền "
        "quản trị (`Win + X` > **Terminal (Admin)**). Lệnh thứ hai khởi động lại dịch vụ SQL Server để áp dụng.")
    g.code("PowerShell (Windows, quyền quản trị)",
           "sqlcmd -S localhost -E -C -Q \"EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', "
           "N'Software\\Microsoft\\MSSQLServer\\MSSQLServer', N'LoginMode', REG_DWORD, 2\"\n"
           "Restart-Service MSSQLSERVER", lang="text")
    g.p("Lệnh thứ nhất in `(0 rows affected)`; lệnh thứ hai có thể in *WARNING: Waiting for service ... to stop* "
        "trong vài giây. Kiểm tra bằng lệnh dưới đây: kết quả `0` là Mixed Mode đã bật (`1` là chưa, khởi động lại "
        "dịch vụ thêm lần nữa).")
    g.code("PowerShell (Windows)",
           "sqlcmd -S localhost -E -C -h -1 -Q \"SELECT SERVERPROPERTY('IsIntegratedSecurityOnly')\"", lang="text")
    g.p("Bản Express: thay `localhost` bằng `localhost\\SQLEXPRESS` và `MSSQLSERVER` bằng `'MSSQL$SQLEXPRESS'`. "
        "Tài khoản `sa` vẫn bị khóa; các tài khoản demo nằm trong CSDL `QLTTTA` nên không cần `sa`.")
    g.placeholder("Các bước chi tiết của trình cài SQL Server 2025 Express/Developer bằng giao diện: chọn kiểu "
                  "cài Basic hay Custom, màn hình Instance Configuration (tên instance), Database Engine "
                  "Configuration (Mixed Mode, mật khẩu sa, Add Current User).")
    g.figure_or_placeholder(WINDOWS_IMAGES / "sql_server_authentication_mode.png",
                            "Chọn chế độ xác thực Mixed Mode khi cài SQL Server",
                            "màn hình Database Engine Configuration > Server Configuration của trình cài SQL "
                            "Server, đang chọn Mixed Mode.")

    g.h3("2.3.2. Cài công cụ quản trị và driver")
    g.bullets([
        "**SQL Server Management Studio (SSMS)** - công cụ xem dữ liệu và chạy script (không bắt buộc để dùng "
        "ứng dụng, nhưng cần cho cách khởi tạo CSDL thứ hai ở mục 2.3.4).",
        "**Microsoft ODBC Driver 18 for SQL Server** - driver kết nối của ứng dụng. Khi máy không có driver "
        "18/17, ứng dụng còn thử driver \"SQL Server\" có sẵn của Windows, nhưng trên Windows 11 với SQL Server "
        "2025 driver này không đăng nhập được (đã kiểm tra), nên hãy coi driver 18 là bắt buộc.",
    ])
    g.p("Trình cài SQL Server 2025 đã cài kèm **ODBC Driver 17 và 18 for SQL Server** cùng lệnh `sqlcmd`, nên máy "
        "cài SQL Server không cần tải driver riêng. Máy **chỉ chạy ứng dụng** - SQL Server nằm trên máy khác hoặc "
        "chạy trong Docker (phương án A) - thì phải cài driver 18: tải tại "
        "`https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server` (bản x64), hoặc "
        "`winget install --id Microsoft.msodbcsql.18`. Xem các driver đã cài bằng PowerShell:")
    g.code("PowerShell (Windows)",
           "Get-OdbcDriver -Platform 64-bit | Where-Object Name -match 'SQL Server' | Select-Object Name",
           lang="text")

    g.h3("2.3.3. Bật kết nối TCP/IP")
    g.p("Bản Developer và Express **tắt TCP/IP** sau khi cài (dịch vụ **SQL Server Browser** cũng tắt). Ứng dụng "
        "chạy **trên cùng máy** với SQL Server vẫn kết nối được khi ô Máy chủ là `localhost` (hoặc "
        "`localhost\\SQLEXPRESS`), không cần bật TCP/IP. Địa chỉ có cổng như `localhost,1433` (giá trị mặc định "
        "của ứng dụng) thì cần TCP/IP: khi TCP/IP còn tắt, ứng dụng chờ khoảng 10 giây rồi báo **Không kết nối "
        "được máy chủ SQL Server**.")
    g.p("Bật TCP/IP khi máy khác cần kết nối tới, hoặc khi muốn dùng địa chỉ có cổng: mở **SQL Server "
        "Configuration Manager** (với SQL Server 2025 có thể gõ `SQLServerManager17.msc` trong hộp **Run**, "
        "`Win + R`) > **SQL Server Network Configuration > Protocols for MSSQLSERVER** (hoặc **SQLEXPRESS**), bật "
        "**TCP/IP**, rồi khởi động lại dịch vụ **SQL Server** trong mục **SQL Server Services**.")
    g.placeholder("Xác nhận trên Windows các bước bật TCP/IP trong SQL Server Configuration Manager; có cần bật "
                  "dịch vụ SQL Server Browser để máy khác dùng địa chỉ `<tên máy>\\SQLEXPRESS` không; có cần đặt "
                  "cổng cố định 1433 (tab IP Addresses > IPAll) khi máy khác kết nối tới không.")
    g.figure_or_placeholder(WINDOWS_IMAGES / "sql_configuration_manager_tcpip.png",
                            "Bật giao thức TCP/IP trong SQL Server Configuration Manager",
                            "SQL Server Configuration Manager, mục Protocols for SQLEXPRESS, TCP/IP = Enabled.")

    g.h3("2.3.4. Khởi tạo CSDL")
    g.p("**Cách 1 - PowerShell** (tại thư mục mã nguồn, dùng `sqlcmd` cài trên máy):")
    g.code("PowerShell (Windows)",
           "# Windows Authentication, instance mặc định (Developer)\n"
           ".\\scripts\\db_init.ps1\n"
           "# Bản Express\n"
           ".\\scripts\\db_init.ps1 -Server \"localhost\\SQLEXPRESS\"\n"
           "# Đăng nhập bằng sa (SQL Server Authentication)\n"
           "$env:SQL_PASSWORD = '<mật khẩu sa>'\n"
           ".\\scripts\\db_init.ps1 -Server \"localhost\\SQLEXPRESS\" -User sa", lang="text")
    g.p("Trình cài SQL Server 2025 đã kèm lệnh `sqlcmd`: mở **cửa sổ PowerShell mới** sau khi cài để lệnh có trong "
        "PATH (kiểm tra bằng `sqlcmd -?`). Máy chưa có `sqlcmd` (ví dụ SQL Server cài từ lâu) thì cài bằng "
        "`winget install Microsoft.Sqlcmd`. Cách 1 dùng tài khoản Windows đang đăng nhập (người cài SQL Server là "
        "quản trị của máy chủ) nên chạy được cả trước khi bật Mixed Mode. Script in tên từng file `>> 00_...` → "
        "`>> 07_seed_data.sql`, dòng cuối là `Done. The QLTTTA database is ready`.")
    g.p("**Cách 2 - SSMS**: kết nối tới máy chủ bằng tài khoản quản trị (Windows Authentication hoặc `sa`), "
        "mở lần lượt từng file `database/00_create_database.sql` → `database/07_seed_data.sql` (**File > Open "
        "> File**), bấm **Execute** (F5) và chờ chạy xong mới mở file tiếp theo. Không cần bật *SQLCMD Mode*.")
    g.figure_or_placeholder(WINDOWS_IMAGES / "ssms_run_script.png",
                            "Chạy script khởi tạo CSDL trong SSMS",
                            "SSMS sau khi chạy xong một script (ví dụ 07_seed_data.sql), tab Messages báo "
                            "thành công.")

    g.h3("2.3.5. Cho máy khác kết nối tới (không bắt buộc)")
    g.placeholder("Nếu ứng dụng chạy trên máy khác với máy cài SQL Server: mở cổng TCP 1433 trong Windows "
                  "Defender Firewall (Inbound Rule), lấy địa chỉ IP bằng `ipconfig`, khai báo "
                  "`<IP>,1433` trong ứng dụng. Kiểm tra lại các bước trên Windows.")

    g.h2("2.4. Nạp lại dữ liệu mẫu trước buổi demo")
    g.p("Dữ liệu mẫu dùng ngày **tính theo ngày chạy script** (lớp đang học, doanh thu tháng này, lịch học "
        "tuần này...). Trước mỗi buổi demo, chạy lại bước khởi tạo CSDL (mục 2.2.3 hoặc 2.3.4) để các con số "
        "trên trang Tổng quan và lịch học có ý nghĩa.")
    g.warning("Script `00_create_database.sql` **xóa CSDL `QLTTTA` cũ** rồi tạo lại. Mọi dữ liệu nhập thêm "
              "(học viên mới, mật khẩu đã đổi...) sẽ mất; mật khẩu các tài khoản demo trở về mặc định.")


def chapter3(g):
    version = app_version()
    g.h1("CHƯƠNG 3. CÀI ĐẶT ỨNG DỤNG")

    g.h2("3.1. Tải bộ cài")
    g.p("Bộ cài nằm ở trang **Releases** của kho mã nguồn (`https://github.com/nhutruong-uit/imcp/releases`). "
        f"Với phiên bản {version}, tên các file là:")
    g.table(["Hệ điều hành", "File", "Ghi chú"], [
        ["macOS (Apple Silicon)", f"`QLTTTA-{version}-macos-arm64.dmg`", "Kèm sẵn driver FreeTDS"],
        ["Windows 64-bit", f"`QLTTTA-{version}-windows-x64-setup.exe`", "Bộ cài, không cần quyền Administrator"],
        ["Windows 64-bit", f"`QLTTTA-{version}-windows-x64-portable.zip`", "Bản chạy ngay, không cần cài"],
    ], widths_cm=[3.6, 7.4, 5.0], caption="Các file cài đặt", size=10.5)
    g.p("Nhóm phát triển có thể tự đóng gói từ mã nguồn: `./scripts/package-macos.sh` (macOS) và "
        "`.\\scripts\\package-windows.ps1` (Windows), kết quả nằm trong thư mục `dist/`.")

    g.h2("3.2. Cài đặt trên macOS")
    g.steps([
        "Mở file `.dmg`, kéo **QLTTTA.app** vào thư mục **Applications**.",
        "Mở QLTTTA lần đầu. Vì ứng dụng không đăng ký với Apple, macOS báo không mở được: bấm **Done** (hoặc "
        "**OK**).",
        "Vào **System Settings > Privacy & Security**, kéo xuống phần **Security**, bấm **Open Anyway** cạnh "
        "dòng QLTTTA và xác nhận bằng mật khẩu máy. Từ lần sau ứng dụng mở bình thường.",
    ])
    g.p("Thay cho bước 2-3, có thể chạy lệnh sau trong Terminal:")
    g.code("Terminal (macOS)", "xattr -dr com.apple.quarantine /Applications/QLTTTA.app", lang="text")
    g.p("Bản macOS đã kèm driver kết nối SQL Server (FreeTDS), không cần cài thêm thành phần nào.")

    g.h2("3.3. Cài đặt trên Windows")
    g.h3("3.3.1. Dùng bộ cài setup.exe")
    g.steps([
        f"Chạy `QLTTTA-{version}-windows-x64-setup.exe`. Nếu Windows hiện **Windows protected your PC** "
        "(SmartScreen), bấm **More info > Run anyway** (ứng dụng sinh viên không có chữ ký số thương mại).",
        "Hộp thoại **Select install mode**: chọn **Install for me only (recommended)** (cài cho riêng người dùng "
        "hiện tại, không cần quyền Administrator) hoặc **Install for all users** (cho mọi người dùng, Windows hỏi "
        "quyền Administrator).",
        "Trang **Select Destination Location**: giữ thư mục đề xuất hoặc bấm **Browse...** để chọn thư mục khác, "
        "rồi bấm **Next**.",
        "Trang **Select Additional Tasks**: giữ hoặc bỏ dấu ở **Create a desktop shortcut** (biểu tượng ngoài màn "
        "hình), bấm **Next**.",
        "Trang **Ready to Install**: bấm **Install**. Ở trang cuối (**Completing the QLTTTA - English Center "
        "Management Setup Wizard**), để dấu ở **Launch QLTTTA** nếu muốn mở ứng dụng ngay, rồi bấm **Finish**.",
    ])
    g.p("Bộ cài tạo mục **QLTTTA** và **Installation guide** (hướng dẫn ngắn bằng tiếng Anh) trong menu Start. "
        "Cài cho riêng người dùng hiện tại thì ứng dụng nằm ở `%LOCALAPPDATA%\\Programs\\QLTTTA` và không cần "
        "quyền Administrator.")
    g.tip("Cài không hiện hộp thoại (ví dụ cài sẵn cho nhiều máy phòng thực hành), cho riêng người dùng, không tạo "
          f"biểu tượng ngoài màn hình: `QLTTTA-{version}-windows-x64-setup.exe /VERYSILENT /CURRENTUSER "
          "/MERGETASKS=\"!desktopicon\"`. Gỡ im lặng: `unins000.exe /VERYSILENT` trong thư mục cài.")
    g.placeholder("Kiểm tra trên Windows thư mục cài mặc định khi chọn **Install for all users** (dự kiến "
                  "`C:\\Program Files\\QLTTTA`, cần quyền Administrator).")
    g.figure_or_placeholder(WINDOWS_IMAGES / "installer_smartscreen.png",
                            "Cảnh báo SmartScreen khi chạy bộ cài",
                            "hộp thoại Windows protected your PC sau khi bấm More info (thấy nút Run anyway).")
    g.figure_or_placeholder(WINDOWS_IMAGES / "installer_finish.png",
                            "Bước cuối của bộ cài QLTTTA trên Windows",
                            "màn hình cuối của bộ cài QLTTTA (Launch QLTTTA, nút Finish).")

    g.h3("3.3.2. Dùng bản portable")
    g.p(f"Giải nén `QLTTTA-{version}-windows-x64-portable.zip` vào một thư mục bất kỳ (ví dụ `D:\\QLTTTA`) "
        "và chạy `QLTTTA.exe`. Không giải nén lẫn với bản cũ; muốn gỡ chỉ cần xóa thư mục.")

    g.h3("3.3.3. Driver kết nối")
    g.p("Ứng dụng tự tìm driver theo thứ tự: **ODBC Driver 18 for SQL Server**, **ODBC Driver 17 for SQL "
        "Server**, rồi driver **SQL Server** có sẵn của Windows. Driver cuối này không đăng nhập được vào SQL "
        "Server 2025 trên Windows 11, nên máy chưa có driver 18/17 cần cài ODBC Driver 18 (mục 2.3.2). Nếu gặp lỗi "
        "chứng chỉ/TLS khi đăng nhập, bật **Tin cậy chứng chỉ máy chủ** trong phần cấu hình máy chủ.")

    g.h2("3.4. Nơi lưu cấu hình và gỡ cài đặt")
    g.p("Ứng dụng ghi nhớ địa chỉ máy chủ, tên CSDL, tên đăng nhập gần nhất và ngôn ngữ giao diện (không lưu "
        "mật khẩu):")
    g.table(["Hệ điều hành", "Nơi lưu cấu hình", "Gỡ cài đặt"], [
        ["macOS", "`~/Library/Preferences/com.uit-ie103.QLTTTA.plist`",
         "Kéo **QLTTTA.app** từ Applications vào Thùng rác"],
        ["Windows", "Registry `HKEY_CURRENT_USER\\Software\\UIT-IE103\\QLTTTA`",
         "**Settings > Apps > Installed apps > QLTTTA > Uninstall** (bản portable: xóa thư mục)"],
    ], widths_cm=[2.8, 7.4, 5.8], caption="Cấu hình đã lưu và cách gỡ ứng dụng", size=10.5)
    g.p("Gỡ cài đặt xóa thư mục ứng dụng và các mục trong menu Start nhưng **giữ lại cấu hình** đã lưu trong "
        "registry, nên cài lại vẫn nhớ máy chủ cũ. Muốn xóa hẳn cấu hình (Windows), chạy trong PowerShell:")
    g.code("PowerShell (Windows)", "Remove-Item -Path 'HKCU:\\Software\\UIT-IE103\\QLTTTA' -Recurse", lang="text")
    g.placeholder("Xác nhận trên Windows đường dẫn gỡ cài đặt trong Settings (Windows 10 và 11 khác nhau).")

    g.h2("3.5. Chạy từ mã nguồn (dành cho nhóm phát triển)")
    g.p("Thành viên nhóm có thể build ứng dụng bằng Qt 6, CMake và Ninja thay vì dùng bộ cài. Script "
        "`scripts/setup_dev` kiểm tra máy và chỉ cài những gì còn thiếu: bộ công cụ build, SQL Server (macOS: "
        "container Docker; Windows: instance đã cài, container đang chạy hoặc SQL Server 2025 Developer), khởi tạo "
        "CSDL rồi chạy toàn bộ kiểm thử. Trong Claude Code, gõ `/imcp-setup` để chạy script này. Chi tiết và các "
        "tùy chọn nằm trong `docs/SETUP.md` (mục 3).")
    g.code("Terminal (macOS)", "./scripts/setup_dev.sh --check             # chỉ báo còn thiếu gì\n"
                               "./scripts/setup_dev.sh --accept-licenses   # cài đặt toàn bộ", lang="text")
    g.code("PowerShell (Windows)",
           "powershell -ExecutionPolicy Bypass -File scripts\\setup_dev.ps1 -Check\n"
           "powershell -ExecutionPolicy Bypass -File scripts\\setup_dev.ps1 -AcceptLicenses", lang="text")
    g.p("Tham số `--accept-licenses` (`-AcceptLicenses`) nghĩa là bạn đồng ý giấy phép SQL Server Developer Edition "
        "(và điều khoản Docker Desktop trên macOS). Sau đó build và chạy ứng dụng:")
    g.code("Terminal (macOS)", "cmake --preset macos-debug\ncmake --build --preset macos-debug\n"
                               "open build/macos-debug/src/app/QLTTTA.app", lang="text")
    g.code("PowerShell (Windows, cửa sổ mới sau setup_dev)",
           "cmake --preset windows-debug\ncmake --build --preset windows-debug\n"
           ".\\build\\windows-debug\\QLTTTA.exe", lang="text")
