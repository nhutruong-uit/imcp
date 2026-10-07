"""Chapter 6 - Presenting information (application); Chapter 7 - Advanced databases; Chapter 8 - Conclusion;
references, appendix."""
from content.common import (IMG, SQL, object_counts, database_tests, e2e_scenarios, macos_min_version, menu_by_role,
                            unit_test_suites)
from report_lib import sql_block

SCR = IMG / "screens"


def chapter6(r):
    r.h1("CHƯƠNG 6: TRÌNH BÀY THÔNG TIN - ỨNG DỤNG QLTTTA")

    r.h2("6.1. Kiến trúc ứng dụng")
    r.p("Ứng dụng desktop viết bằng **C++17 và Qt 6** (thống nhất ngôn ngữ C++ cả nhóm đã học), chạy trên Windows và "
        "macOS từ cùng một mã nguồn. Mã nguồn tổ chức theo **Clean Architecture**: các tầng bên trong (nghiệp vụ) không "
        "phụ thuộc tầng bên ngoài (giao diện, CSDL); chiều phụ thuộc được ép bằng cấu hình liên kết thư viện của CMake.")
    r.figure(IMG / "diagrams" / "architecture.png", "Clean Architecture của ứng dụng QLTTTA", width_cm=12.5)
    r.table(["Tầng", "Nội dung", "Ví dụ"], [
        ["domain", "Thực thể và quy tắc nghiệp vụ thuần, chỉ dùng Qt Core", "Student::validate() - dưới 18 tuổi phải có phụ huynh; ClassInfo, EnrollmentRequest, Result<T>"],
        ["application", "Use case + port (interface) mà tầng ngoài phải hiện thực; ma trận phân quyền menu và nút", "StudentService, ClassService, EnrollmentService, TuitionService, Permissions, IClassRepository"],
        ["infrastructure", "Kết nối ODBC, gọi thủ tục, ánh xạ lỗi SQL thành thông báo dễ hiểu, lưu cấu hình", "DatabaseManager, SqlStudentRepository, SqlClassRepository, SqlHelpers, SqlErrorMapper"],
        ["presentation", "Giao diện Qt Widgets song ngữ Việt/Anh; không chứa câu lệnh SQL", "LoginDialog, MainWindow, DataPage, FormDialog, StudentPage, ClassPage, form .ui, I18n"],
        ["app", "Composition root: khởi tạo đối tượng, nối các tầng", "main.cpp, AppContainer"],
    ], widths_cm=[2.6, 6.6, 6.8], caption="Các tầng của ứng dụng")
    r.p("Lợi ích cụ thể: toàn bộ SQL nằm ở tầng infrastructure nên dễ đối chiếu với thủ tục trong CSDL; use case được "
        "**kiểm thử đơn vị bằng repository giả** (không cần SQL Server); nếu đổi hệ quản trị CSDL chỉ cần viết lại tầng "
        "infrastructure (các lớp `Sql*Repository` và phần kết nối, ánh xạ lỗi riêng của SQL Server). Quy tắc nghiệp vụ được kiểm tra **hai lớp**: tại ứng dụng để phản hồi nhanh, và tại CSDL "
        "(CHECK/trigger/thủ tục) là nguồn sự thật cuối cùng.")

    r.h2("6.2. Đăng nhập và menu theo vai trò")
    r.p("Màn hình đăng nhập mở kết nối ODBC bằng chính tài khoản SQL Server của người dùng; ứng dụng tự thử lần lượt "
        "ODBC Driver 18 → 17 → driver “SQL Server” có sẵn của Windows (bản macOS kèm sẵn driver FreeTDS), nên chạy được "
        "trên máy chưa cài driver mới. Sau khi đăng nhập, menu bên trái được sinh theo vai trò (Chương 4 môn học - Menu).")
    r.figure(SCR / "login.png", "Màn hình đăng nhập (cấu hình máy chủ thu gọn)", width_cm=12)
    r.figure(SCR / "ql_quan_dashboard.png", "Tổng quan của Quản lý: chỉ số và doanh thu", width_cm=16)
    r.table(["Vai trò", "Menu hiển thị"], [[role, ", ".join(entries)] for role, entries in menu_by_role()],
            widths_cm=[3.0, 13.0], caption="Menu theo vai trò (Permissions::allowedFeatures)")
    r.p("Cùng ma trận `Permissions` còn sinh **thanh menu** (menu bar) của cửa sổ chính: menu Hệ thống (đổi mật khẩu, "
        "ngôn ngữ, đăng xuất, thoát; với Quản lý thêm Tài khoản và Sao lưu), một menu cho mỗi nhóm chức năng giống menu "
        "bên trái và menu Trợ giúp (hộp Giới thiệu: phiên bản, máy chủ, CSDL, người đang đăng nhập). Chín chức năng đầu có "
        "phím tắt Ctrl+1 … Ctrl+9 (⌘ trên macOS); trên macOS thanh menu nằm ở đỉnh màn hình theo chuẩn của hệ điều hành. "
        "Mỗi danh sách có thêm **menu ngữ cảnh** (nhấp chuột phải vào một dòng): dòng đó được chọn rồi menu lặp lại các "
        "nút của màn hình với cùng trạng thái bật/tắt, kèm sao chép ô, làm mới, xuất Excel và xem trước khi in. Phím tắt "
        "chung của các danh sách: F5 làm mới (⌘R trên macOS), Ctrl+F lọc nhanh, Ctrl+P xem trước khi in.")
    r.p("Trong một màn hình, các nút thay đổi dữ liệu chỉ được tạo khi `Permissions::canEdit` cho phép: kế toán chỉ "
        "xem Học viên, giáo vụ chỉ xem Khóa học và Giáo viên (danh mục do Quản lý cập nhật). Giáo vụ không có menu Thu "
        "học phí vì CSDL cấm role này thu tiền (`DENY EXECUTE` trên `usp_Receipt_Create`, ca kiểm thử P16).")
    r.figure(SCR / "gv_john_my_teaching_schedule.png", "Giáo viên chỉ thấy lịch dạy của mình", width_cm=16)
    r.p("Ẩn menu chỉ là lớp giao diện; quyền thật sự được kiểm tra trong CSDL. Ví dụ giáo vụ vẫn mở được Tổng quan "
        "(gọi `usp_Dashboard_Stats`) nhưng thủ tục dùng `fn_CurrentRole()` để trả **NULL** cho cột doanh thu, còn "
        "`fn_MonthlyRevenue` không được GRANT cho `rl_AcademicStaff` nên biểu đồ bị SQL Server từ chối. Ứng dụng chỉ hiển thị "
        "kết quả đó: thẻ doanh thu ghi “Không có quyền” (ca kiểm thử P11).")
    r.figure(SCR / "gvu_lan_dashboard.png", "Tổng quan của Giáo vụ: CSDL ẩn doanh thu", width_cm=14)

    r.h2("6.3. Form nhập liệu")
    r.p("Form học viên được thiết kế bằng **Qt Designer** (file `StudentFormDialog.ui`): ô điện thoại chỉ nhận chữ số, "
        "ngày sinh chọn bằng lịch, nhóm thông tin phụ huynh tự đổi thành bắt buộc khi học viên dưới 18 tuổi, lỗi hiển thị "
        "ngay trên form. Khi lưu, ứng dụng gọi `usp_Student_Add`/`usp_Student_Update`; lỗi từ CSDL (trùng SĐT, vi phạm "
        "CHECK) được chuyển thành thông báo dễ hiểu theo ngôn ngữ giao diện. Từ màn hình Học viên còn mở được hồ sơ (các "
        "lần ghi danh, kiểm tra xếp lớp), ghi danh, nhập điểm kiểm tra xếp lớp và xuất/nhập XML.")
    r.figure(SCR / "gvu_lan_student_form.png", "Form sửa học viên (thiết kế bằng Qt Designer)", width_cm=10)
    r.figure(SCR / "ql_quan_students.png", "Màn hình Học viên: tìm, lọc, sửa, xuất Excel/PDF", width_cm=16)
    r.p("Các màn hình nghiệp vụ còn lại dùng chung hai lớp nền để giống nhau về cách dùng và cách xử lý lỗi. "
        "`DataPage` gồm thanh lọc (bộ lọc riêng, lọc nhanh, Làm mới, Excel, PDF), thanh nút, bảng dữ liệu và dòng tổng; "
        "nút cần chọn dòng chỉ bật khi đã chọn một dòng. `FormDialog` là form nhập dạng nhãn - ô nhập với dòng báo lỗi và "
        "hai nút Lưu/Hủy: khi CSDL từ chối, thông báo (đã dịch) hiện ngay trên form và dữ liệu đã nhập được giữ nguyên. "
        "Mỗi thao tác gọi đúng một thủ tục của CSDL, nên quy tắc nghiệp vụ chỉ nằm ở một nơi.")
    r.table(["Màn hình", "Thao tác", "Thủ tục CSDL"], [
        ["Kiểm tra xếp lớp", "Nhập điểm 4 kỹ năng, xem khóa học được đề xuất", "usp_PlacementTest_Add, usp_PlacementTest_Search"],
        ["Lớp học", "Mở lớp, sửa, lịch tuần, sinh buổi học, bắt đầu học, hủy lớp, đánh giá kết quả, xem học viên và kết quả",
         "usp_Class_Create, usp_Class_Update, usp_ClassSchedule_Add/_Remove, usp_Class_GenerateSessions, "
         "usp_Class_UpdateStatus, usp_Class_EvaluateResults, usp_Report_ClassResults"],
        ["Ghi danh", "Ghi danh mới (có khuyến mãi), chuyển lớp, bảo lưu, học lại, nghỉ học",
         "usp_Enrollment_Create, usp_Enrollment_TransferClass, usp_Enrollment_UpdateStatus, usp_Enrollment_Search"],
        ["Lịch học - điểm danh, Lịch dạy", "Xem theo tuần, cập nhật buổi học (đã dạy, hủy, nội dung), điểm danh",
         "usp_Session_Update, usp_Attendance_BySession, usp_Attendance_Save"],
        ["Sổ điểm, Sổ điểm của tôi", "Nhập điểm dạng lưới học viên × cột điểm, lưu mọi điểm đã sửa trong một giao dịch",
         "usp_Grade_ByClass, usp_Grade_Save"],
        ["Thu học phí", "Thu tiền, hủy phiếu thu (bắt buộc lý do), in phiếu thu PDF", "usp_Receipt_Create, usp_Receipt_Cancel, usp_Receipt_Print, usp_Receipt_Search"],
        ["Lương giáo viên", "Chốt lương tháng, khấu trừ, xác nhận đã chi trả", "usp_Payroll_Finalize, usp_Payroll_Adjust, usp_Payroll_MarkPaid"],
        ["Khóa học, Giáo viên, Nhân viên, Chi nhánh - phòng học, Khuyến mãi",
         "Thêm, sửa, ngừng hoạt động; chương trình, giáo trình XML và cột điểm của khóa học",
         "Nhóm J: usp_Branch_Add ... usp_Promotion_Update, usp_Course_SetSyllabus, usp_GradeComponent_Save/_Delete"],
        ["Tài khoản, Sao lưu", "Tạo, khóa/mở khóa tài khoản, đặt lại mật khẩu; sao lưu Full/Differential/Log",
         "usp_Account_Create, usp_Account_Lock, usp_Account_ResetPassword, usp_Backup"],
    ], widths_cm=[3.4, 6.2, 6.4], caption="Các màn hình nhập liệu và thủ tục CSDL tương ứng")
    r.figure(SCR / "gvu_lan_classes.png", "Màn hình Lớp học: mỗi nút gọi một thủ tục", width_cm=16)
    r.figure(SCR / "kt_minh_tuition.png", "Màn hình Thu học phí: thu, hủy, in phiếu thu", width_cm=16)
    r.figure(SCR / "gvu_lan_grade_book.png", "Sổ điểm của lớp: điểm tổng kết theo trọng số", width_cm=16)
    r.figure(SCR / "ql_quan_courses.png", "Danh mục khóa học và trọng số điểm của khóa", width_cm=16)

    r.h2("6.4. Báo cáo")
    r.p("Bài giảng giới thiệu Crystal Report với các phần Report Header, Page Header, Details, Group, Page/Report Footer "
        "và trình xem báo cáo (Report Viewer). Crystal Report chỉ chạy trên .NET/Windows nên không dùng được cho ứng dụng "
        "Qt đa nền tảng; nhóm hiện thực bộ báo cáo tương đương: `TableExporter::report` dựng một `ReportDocument` (HTML "
        "+ khổ giấy) và cùng tài liệu đó được xem trước, in (`QPrinter`) hoặc lưu PDF (`QPdfWriter`):")
    r.table(["Thành phần Crystal Report", "Trong báo cáo PDF của QLTTTA"], [
        ["Report Header", "Tên trung tâm, tiêu đề báo cáo, ngày lập, người lập"],
        ["Page Header", "Dòng tiêu đề cột lặp lại đầu mỗi trang"],
        ["Details", "Dữ liệu đã lọc/sắp xếp trên màn hình, định dạng tiền tệ và ngày theo kiểu Việt Nam"],
        ["Group Header / Group Footer", "Nhóm theo một cột bất kỳ (chọn trong hộp xem trước): dòng tiêu đề nhóm ghi giá "
         "trị và số dòng, dòng Cộng nhóm cho các cột tiền"],
        ["Report Footer", "Dòng TỔNG CỘNG cho các cột tiền (đã đóng, còn nợ, doanh thu, lương), tổng số dòng"],
        ["Page Footer", "Số trang tự động"],
        ["Nguồn dữ liệu / tham số", "View và thủ tục báo cáo (usp_Report_Revenue, usp_Report_ClassResults...)"],
        ["Report Viewer", "Hộp Xem trước khi in (`ReportPreviewDialog`): đúng các trang sẽ in, phóng to/thu nhỏ, đổi "
         "cột nhóm, In (hộp thoại in của hệ điều hành), Lưu PDF"],
    ], widths_cm=[5.0, 11.0], caption="Đối chiếu cấu trúc báo cáo")
    r.p("Bên cạnh các danh sách, ứng dụng có những báo cáo có tham số: **doanh thu theo khoảng thời gian** (chọn từ ngày - "
        "đến ngày và chi nhánh, gom theo chi nhánh, chương trình, khóa học - `usp_Report_Revenue`), **kết quả của một lớp** "
        "(điểm tổng kết, xếp loại, số hiệu chứng chỉ - `usp_Report_ClassResults`) và **phiếu thu** khổ A5 theo mẫu "
        "chứng từ (`usp_Receipt_Print`), mở trong hộp xem trước để in ngay hoặc lưu PDF. Mọi danh sách (kể cả sổ điểm, "
        "danh sách học viên và các cửa sổ danh sách phụ) đều có nút In mở hộp xem trước.")
    r.figure(SCR / "kt_minh_report_preview.png", "Xem trước khi in: công nợ học phí nhóm theo lớp", width_cm=15)
    r.figure(SCR / "kt_minh_outstanding_tuition.png", "Màn hình Công nợ học phí: dòng tổng, xuất PDF", width_cm=16)
    r.figure(SCR / "gvu_lan_learning_results.png", "Báo cáo kết quả học tập: điểm, xếp loại", width_cm=16)

    r.h2("6.5. Đa nền tảng, CI/CD và đóng gói")
    r.p("Nhóm dùng GitHub với hai nhánh chính `develop` (nhánh mặc định) và `main`. Trước khi tạo Pull Request, "
        "`scripts/test_all` chạy toàn bộ kiểm thử trên máy. Mỗi Pull Request vào `develop` phải qua job Checks (quy ước "
        "của kho mã + unit test trên Linux). Khi merge vào `develop` và cho mỗi Pull Request vào `main`, GitHub Actions "
        "build và chạy unit test trên **macOS và Windows**, đồng thời job **Full tests** chạy trên Linux với SQL Server "
        "2025 trong Docker (kiểm thử CSDL, kiểm thử mức máy chủ, unit test, end-to-end) - nhánh `main` bật branch "
        "protection nên chỉ merge được khi cả ba job xanh; khi merge vào `main`, quy trình Release tự đóng gói:")
    r.figure(IMG / "diagrams" / "cicd.png", "Quy trình CI/CD từ nhánh tính năng tới file cài", width_cm=16)
    r.table(["Hệ điều hành", "File cài", "Cách đóng gói"], [
        ["Windows 10 (1809+)/11 x64", "QLTTTA-x.y.z-windows-x64-setup.exe, ...-portable.zip", "windeployqt (Qt + runtime MinGW + plugin ODBC), Inno Setup, cài không cần quyền admin"],
        [f"macOS {macos_min_version()}+ (Apple Silicon)", "QLTTTA-x.y.z-macos-arm64.dmg", "macdeployqt, kèm FreeTDS + unixODBC + OpenSSL (đổi đường dẫn sang @loader_path), ký ad-hoc"],
    ], widths_cm=[3.4, 5.6, 7.0], caption="File cài đặt")
    r.p("Cùng các script `scripts/package-macos.sh` và `scripts/package-windows.ps1`, thành viên có thể tự tạo file "
        "cài trên máy cá nhân giống hệt CI. Chế độ `--check-connection` giúp kiểm tra kết nối/đăng nhập không cần giao diện.")
    r.p("File cài tự kiểm tra phiên bản hệ điều hành: bộ cài Windows dừng trên Windows cũ hơn bản 1809 (`MinVersion` "
        "của Inno Setup - mức tối thiểu của Qt 6.8); trên macOS, script đóng gói lấy phiên bản `minos` cao nhất của "
        "các file nhị phân đóng kèm (thư viện Homebrew được build cho macOS của máy CI) ghi vào "
        "`LSMinimumSystemVersion`, nên macOS cũ hơn từ chối mở ứng dụng thay vì lỗi khi chạy. Trang Release ghi rõ "
        "phiên bản tối thiểu, các bước mở ứng dụng lần đầu và tự liệt kê các Pull Request đã merge từ lần phát hành "
        "trước.")
    r.p("**Không phát hành bản cài chưa chạy thử.** Ứng dụng có chế độ `QLTTTA --self-test` (không mở cửa sổ, không cần "
        "CSDL) kiểm tra những gì bộ đóng gói phải chép kèm: plugin giao diện của Qt, plugin ODBC `qsqlodbc`, một driver "
        "ODBC cho SQL Server (thử kết nối tới một cổng đóng trên chính máy để phân biệt “thiếu driver” với “driver đã "
        "nạp”), bản dịch tiếng Việt và biểu tượng SVG. Script đóng gói macOS kiểm tra không file nhị phân nào còn trỏ tới "
        "thư viện Homebrew, rồi mount file .dmg chỉ đọc và chạy self-test - ứng dụng phải dùng đúng driver FreeTDS đóng kèm. "
        "Script Windows giải nén file .zip vào thư mục mới rồi chạy self-test; quy trình Release còn cài thử setup.exe ở "
        "chế độ im lặng, chạy self-test trên bản đã cài và gỡ cài đặt. Sau khi build và kiểm tra xong, job phát hành chờ "
        "Nhóm trưởng phê duyệt (environment `release`) và gắn cho mỗi file cài một chứng thực nguồn gốc build "
        "(build attestation) - người tải kiểm tra bằng `gh attestation verify`.")

    r.h2("6.6. Kiểm thử ứng dụng")
    r.bullets([
        "**Unit test** (Qt Test): kiểm tra quy tắc Student, ánh xạ vai trò, use case thêm học viên (dùng repository giả), "
        "đăng nhập/đổi mật khẩu, ma trận phân quyền, ánh xạ lỗi SQL và chuỗi kết nối ODBC, bản dịch giao diện (mọi chuỗi, "
        "giá trị lưu trong CSDL và thông báo nghiệp vụ của CSDL đều có bản tiếng Việt), use case của mọi module (lớp học, "
        f"ghi danh, học phí, điểm danh, sổ điểm, lương, danh mục) với repository giả - {len(unit_test_suites())} bộ test, "
        "chạy tự động trên CI.",
        "**Kiểm thử end-to-end qua giao diện** (`tests/tst_e2e_gui.cpp`): chương trình gõ phím, bấm nút trên chính các "
        "màn hình với CSDL thật - đăng nhập sai bị từ chối; giáo vụ tìm kiếm, thêm học viên 10 tuổi (lần đầu thiếu phụ "
        "huynh bị báo lỗi, bổ sung thì lưu được) rồi xóa; giáo viên chỉ thấy 2 lớp của mình; kế toán không có nút thêm học "
        "viên, xem công nợ và xuất PDF/CSV; đổi mật khẩu nhập lại sai hoặc sai mật khẩu hiện tại bị chặn (thông báo tiếng "
        "Anh của CSDL được hiển thị bằng tiếng Việt); vừa đăng nhập phải mở sẵn trang đầu tiên, thẻ doanh thu của giáo vụ "
        "ghi \"Không có quyền\"; **mỗi vai trò mở lần lượt mọi chức năng được phép** và trang phải có dữ liệu (thiếu một "
        "lệnh GRANT là bị phát hiện); sửa học viên, đổi tên lớp qua form rồi đọc lại từ CSDL; bảo lưu rồi cho học lại "
        "một ghi danh (có hộp xác nhận); nhấn Enter ở ô tìm học viên của form ghi danh chỉ tìm chứ không ghi danh; "
        "giáo viên đổi điểm danh của một học viên ở buổi mình dạy (Enter ở ô ghi chú không đổi điểm danh); sổ điểm "
        "không nhận điểm 11 và báo lý do; lọc nhanh thì dòng "
        "tổng tính lại đúng; thanh menu của mỗi vai trò khớp ma trận phân quyền và mở đúng trang; nhấp chuột phải vào một "
        "lớp thì menu ngữ cảnh có các nút của màn hình; xem trước báo cáo công nợ nhóm theo lớp (mỗi lớp một dòng Cộng "
        "nhóm); chuyển giao diện sang tiếng Anh rồi về tiếng Việt. Kết quả: "
        f"{len(e2e_scenarios())}/{len(e2e_scenarios())} kịch bản đạt, dữ liệu trở về nguyên trạng. "
        "Bài kiểm thử chạy trong `scripts/test_all` và trong job Full tests của CI (Linux, SQL Server trong Docker); "
        "`test_all` dừng nếu có kịch bản bị bỏ qua. Hai job macOS và Windows của CI không có CSDL nên ghi nhận bài này "
        "là bỏ qua (Skipped).",
        "**Kiểm thử hiển thị**: công cụ `tools/qlttta_screenshots` tự đăng nhập bằng 4 tài khoản demo, mở "
        "từng chức năng và chụp màn hình (hình trong chương này được tạo bằng công cụ đó).",
        f"**Kiểm thử CSDL**: {len(database_tests())} ca trong `12_tests.sql` (Chương 4 và 5), tất cả đạt.",
        "**Chạy toàn bộ bằng một lệnh** `scripts/test_all.sh`: khởi tạo lại CSDL → kiểm thử CSDL → build → unit test → "
        "end-to-end; bước nào hỏng thì dừng và trả mã lỗi. Đây là điều kiện bắt buộc trước khi tạo Pull Request.",
    ])


def chapter7(r):
    r.h1("CHƯƠNG 7: MÔ HÌNH CSDL TIÊN TIẾN - ÁP DỤNG CHO BÀI TOÁN")

    r.h2("7.1. CSDL hướng đối tượng")
    r.p("CSDL hướng đối tượng lưu trực tiếp đối tượng (định danh OID, thuộc tính phức hợp, tập hợp, kế thừa, phương "
        "thức). Chuyển mô hình quan hệ của QLTTTA sang mô hình hướng đối tượng theo các bước: (1) mỗi quan hệ thực thể "
        "thành một lớp; (2) khóa ngoại thành **tham chiếu** tới đối tượng; (3) quan hệ n-n và thực thể yếu thành thuộc "
        "tính kiểu **set**; (4) các lớp có thuộc tính chung gom thành **lớp cha**; (5) thủ tục/hàm thành **phương thức**.")
    r.code("Định nghĩa lớp theo cú pháp ODL (rút gọn)", """class Person { attribute string fullName; attribute date dateOfBirth;
               attribute string phone; int age(in date asOf); };
class Student extends Person (extent Students key studentId) {
    attribute string studentId;
    attribute tuple(string name, string phone) guardian;  -- thuộc tính phức hợp
    relationship set<Enrollment> enrollments inverse Enrollment::student;
    money balance(); };
class Class (extent Classes key classId) {
    attribute string classId; attribute date startDate;
    -- thay bảng CLASS_SCHEDULE
    attribute set<tuple(short weekday, time start, time end)> schedule;
    relationship Course course inverse Course::classes;
    relationship Teacher teacher inverse Teacher::classes;
    relationship set<Enrollment> enrollments inverse Enrollment::class;
    void generateSessions(); void evaluateResults(); };
class Enrollment (extent Enrollments key enrollmentId) {
    attribute money tuitionDue;
    -- nhúng phiếu thu
    attribute set<tuple(date paidAt, money amount, string method)> receipts;
    relationship Student student inverse Student::enrollments;
    relationship Class class inverse Class::enrollments;
    money amountPaid(); void pay(in money amount); };""", lang="text")
    r.p("**Đánh giá**: mô hình hướng đối tượng biểu diễn tự nhiên kế thừa Person và các tập hợp (lịch học, phiếu thu), "
        "phương thức gắn với dữ liệu, truy cập theo tham chiếu nhanh khi duyệt đồ thị đối tượng. Tuy nhiên hệ quản trị "
        "OODB ít phổ biến, thiếu công cụ báo cáo, khó truy vấn tổng hợp tùy ý (doanh thu theo tháng/chi nhánh) và khó đảm "
        "bảo ràng buộc liên đối tượng. Trong thực tế, nhóm áp dụng tư tưởng hướng đối tượng ở **tầng ứng dụng** (lớp "
        "domain C++) và giữ CSDL quan hệ - đúng mô hình ORM phổ biến hiện nay.")

    r.h2("7.2. CSDL phân tán")
    r.p("Trung tâm có nhiều chi nhánh, mỗi chi nhánh chủ yếu thao tác dữ liệu của mình (học viên, lớp, thu tiền), còn ban "
        "quản lý cần số liệu toàn hệ thống. Đây là tình huống điển hình cho CSDL phân tán theo địa lý. Thiết kế đề xuất:")
    r.figure(IMG / "diagrams" / "distributed_database.png", "Phân mảnh và cấp phát dữ liệu theo chi nhánh", width_cm=15)
    r.table(["Kỹ thuật", "Áp dụng", "Lý do"], [
        ["Phân mảnh ngang chính", "STUDENT_BRi = σ BranchId = 'BRi' (STUDENT); CLASS_BRi tương tự", "Mỗi chi nhánh truy cập cục bộ học viên, lớp của mình"],
        ["Phân mảnh ngang dẫn xuất", "ENROLLMENT_BRi = ENROLLMENT ⋉ CLASS_BRi; RECEIPT, ATTENDANCE, GRADE theo ENROLLMENT", "Giữ dữ liệu phụ thuộc cùng trạm với lớp để phép kết thực hiện cục bộ"],
        ["Phân mảnh dọc", "TEACHER → TEACHER_PUBLIC (hồ sơ) và TEACHER_PAY (đơn giá)", "Thông tin lương chỉ đặt ở trạm trung tâm (bảo mật)"],
        ["Nhân bản", "PROGRAM, COURSE, GRADE_COMPONENT, PROMOTION ở mọi trạm", "Ít thay đổi, đọc nhiều"],
        ["Trong suốt phân tán", "View UNION ALL (distributed partitioned view) tại trạm trung tâm", "Ứng dụng báo cáo không cần biết dữ liệu nằm ở đâu"],
    ], widths_cm=[3.4, 7.2, 5.4], caption="Thiết kế CSDL phân tán cho QLTTTA")
    r.p("Tính đúng đắn của phân mảnh ngang STUDENT được kiểm chứng bằng script `11_distributed_demo.sql` (2 CSDL trên "
        "cùng máy chủ mô phỏng 2 trạm; triển khai thật dùng Linked Server):")
    r.table(["OriginalTable", "FragmentBR01", "FragmentBR02", "Reconstructed", "Overlap"], [["72", "47", "25", "72", "0"]],
            widths_cm=[3.2] * 5, caption="Kiểm tra tính đầy đủ, tái thiết, tách biệt",
            align=["center"] * 5)
    r.bullets([
        "**Đầy đủ (completeness)**: 47 + 25 = 72 dòng - mọi học viên thuộc một mảnh.",
        "**Tái thiết (reconstruction)**: STUDENT = STUDENT_BR01 ∪ STUDENT_BR02 (view UNION ALL trả về 72 dòng).",
        "**Tách biệt (disjointness)**: không StudentId nào thuộc cả hai mảnh (0 dòng trùng); ràng buộc CHECK (BranchId = 'BRi') ở "
        "mỗi mảnh còn giúp bộ tối ưu chỉ quét đúng mảnh khi truy vấn có điều kiện BranchId.",
    ])
    r.code("View phân tán tại trạm trung tâm (11_distributed_demo.sql)",
           sql_block(SQL, "11_distributed_demo.sql", "CREATE VIEW dbo.vw_Student_AllBranches", "GO"))
    r.p("Yêu cầu khi triển khai thật: chuyển lớp luôn ở cùng chi nhánh nên không cần giao dịch phân tán; thao tác nào "
        "ghi vào dữ liệu của hai chi nhánh cùng lúc mới cần giao thức hai pha (2PC, MSDTC); danh mục nhân bản cần cơ chế đồng bộ (replication) một chiều từ trạm trung tâm; nếu mất kết nối, chi "
        "nhánh vẫn hoạt động với dữ liệu cục bộ.")

    r.h2("7.3. CSDL phi quan hệ (NoSQL)")
    r.p("Mô hình quan hệ gặp hạn chế khi dữ liệu có cấu trúc thay đổi (hồ sơ giáo viên), khi cần đọc trọn một “tài liệu” "
        "gồm nhiều bảng (hồ sơ học tập của học viên phải kết 6 bảng) hoặc khi khối lượng ghi rất lớn (điểm danh hằng ngày "
        "của nhiều chi nhánh). Bảng sau đề xuất mô hình NoSQL phù hợp cho từng phần dữ liệu:")
    r.table(["Mô hình", "Hệ quản trị", "Dữ liệu QLTTTA phù hợp", "Thiết kế"], [
        ["Document", "MongoDB", "Hồ sơ học viên + lịch sử học tập; đề cương khóa học", "Collection students, nhúng (embed) các lượt ghi danh, phiếu thu, điểm"],
        ["Key-value", "Redis", "Phiên đăng nhập, bộ đếm chỗ trống của lớp, cache dashboard", "khóa \"class:CL0003:seatsLeft\" → 6"],
        ["Column-family", "Cassandra", "Điểm danh, nhật ký truy cập khối lượng lớn theo thời gian", "Partition key (ClassId, Month), clustering key SessionDate"],
        ["Graph", "Neo4j", "Lộ trình khóa học tiên quyết, quan hệ giới thiệu bạn bè (khuyến mãi)", "(:Course)-[:PREREQUISITE]->(:Course), (:Student)-[:REFERRED]->(:Student)"],
    ], widths_cm=[2.4, 2.4, 5.4, 5.8], caption="Áp dụng các mô hình NoSQL")
    r.code("Chuyển đổi quan hệ → document (MongoDB): một học viên kèm lịch sử học tập", """{
  "_id": "ST00001",
  "fullName": "Nguyễn Văn An", "dateOfBirth": "2004-03-12", "branch": { "id": "BR01", "name": "District 1 Branch" },
  "placementTests": [ { "date": "2026-04-10", "listening": 4.5, "speaking": 4.0, "reading": 4.5, "writing": 4.0,
                        "recommended": "IE-FND" } ],
  "enrollments": [
    { "enrollmentId": "EN000001", "class": { "id": "CL0001", "name": "IELTS Foundation #1", "course": "IE-FND" },
      "tuitionDue": 6500000,
      "receipts": [ { "id": "RC000001", "paidAt": "2026-04-24", "amount": 6500000, "method": "Bank transfer" } ],
      "grades": { "Homework": 7.5, "Midterm": 8.0, "Final exam": 7.6 },
      "result": "Passed", "certificate": "EC2026-EN000001" },
    { "enrollmentId": "EN000013", "class": { "id": "CL0003", "name": "IELTS 5.5 Intensive #1" }, "result": null }
  ]
}""", lang="text")
    r.p("Nguyên tắc chọn **nhúng hay tham chiếu**: phiếu thu, điểm luôn được đọc cùng lượt ghi danh và không tồn tại độc "
        "lập → nhúng; lớp học và khóa học được nhiều học viên dùng chung, thay đổi độc lập → lưu tham chiếu (mã) kèm vài "
        "trường hay hiển thị (tên) để tránh phải kết. Đổi lại, khi đổi tên lớp phải cập nhật nhiều tài liệu, và ràng buộc "
        "như “không thu vượt học phí” hay “sĩ số tối đa” phải tự kiểm tra ở ứng dụng.")

    r.h2("7.4. So sánh và đánh giá các mô hình cho bài toán")
    r.table(["Tiêu chí", "Quan hệ (SQL Server)", "Hướng đối tượng", "Phân tán", "NoSQL (document)"], [
        ["Ràng buộc toàn vẹn", "Mạnh nhất (PK, FK, CHECK, trigger)", "Trung bình (qua phương thức)", "Mạnh trong trạm, khó liên trạm", "Yếu, kiểm tra ở ứng dụng"],
        ["Giao dịch ACID", "Đầy đủ", "Có (tùy hệ quản trị)", "Cần 2PC, chi phí cao", "Hạn chế (một tài liệu / tùy chọn)"],
        ["Truy vấn tổng hợp, báo cáo", "Rất tốt (SQL)", "Hạn chế", "Tốt qua view phân tán", "Trung bình (aggregation pipeline)"],
        ["Cấu trúc linh hoạt", "Kém (dùng XML/JSON bổ trợ)", "Tốt (kế thừa, tập hợp)", "Như quan hệ", "Rất tốt"],
        ["Mở rộng quy mô", "Theo chiều dọc", "Theo chiều dọc", "Theo chi nhánh/địa lý", "Theo chiều ngang (sharding)"],
        ["Bảo mật, phân quyền", "Chi tiết tới cột, contained user", "Theo hệ quản trị", "Phân quyền theo trạm", "Thường ở mức collection"],
        ["Phù hợp với QLTTTA", "**Phù hợp nhất** cho nghiệp vụ lõi", "Dùng ở tầng ứng dụng", "Khi có ≥ 3-5 chi nhánh xa nhau", "Bổ trợ: cache, nhật ký, hồ sơ"],
    ], widths_cm=[3.0, 3.4, 3.0, 3.2, 3.4], caption="So sánh các mô hình CSDL cho trung tâm")
    r.p("**Kết luận**: nghiệp vụ lõi của trung tâm (ghi danh, học phí, điểm) đòi hỏi ràng buộc chặt và giao dịch ACID nên "
        "mô hình quan hệ là lựa chọn chính; dữ liệu bán cấu trúc được xử lý bằng kiểu XML ngay trong SQL Server. Khi trung "
        "tâm mở rộng nhiều chi nhánh, thiết kế phân mảnh theo chi nhánh ở mục 7.2 cho phép chuyển sang CSDL phân tán mà "
        "không đổi mô hình logic; các mô hình NoSQL phù hợp vai trò bổ trợ (cache, nhật ký khối lượng lớn, lộ trình học).")


def chapter8(r):
    r.h1("CHƯƠNG 8: TỔNG KẾT")

    r.h2("8.1. Kết quả đạt được")
    passed = len([k for k in database_tests() if k[4] == "PASSED"])
    r.table(["Hạng mục", "Kết quả"], [
        ["Phân tích, thiết kế", f"Use case, DFD mức 0-1, ERD (Chen) {object_counts()['TableCount']} thực thể, CD có kế thừa, lược đồ quan hệ đạt BCNF, từ điển dữ liệu"],
        ["Cài đặt CSDL", "{TableCount} bảng, {ConstraintCount} ràng buộc khai báo, {SequenceCount} sequence, {XmlSchemaCount} XML Schema, "
                         "{FunctionCount} hàm, {ViewCount} view, {ProcedureCount} thủ tục, {TriggerCount} trigger, {RoleCount} role".format(**object_counts())],
        ["Xử lý thông tin", "Truy vấn SQL (chia, đệ quy, cửa sổ, PIVOT), XPath/XQuery đủ 5 phương thức, cursor, giao dịch"],
        ["An ninh", "Contained user, phân quyền mức đối tượng và mức cột, view bảo mật, nhật ký XML, backup Full/Diff/Log"],
        ["Kiểm thử", f"{passed}/{len(database_tests())} ca kiểm thử CSDL đạt; {len(unit_test_suites())} bộ unit test; "
                     f"{len(e2e_scenarios())}/{len(e2e_scenarios())} kịch bản end-to-end qua giao diện"],
        ["Ứng dụng", "Qt 6 đa nền tảng, Clean Architecture, giao diện song ngữ Việt/Anh, đăng nhập theo vai trò, "
                     f"{len({e for _, entries in menu_by_role() for e in entries})} màn hình; form nhập liệu cho mọi bước "
                     "nghiệp vụ (danh mục, học viên, lớp, ghi danh, học phí, điểm danh, điểm, lương, tài khoản, sao lưu); "
                     "thanh menu và menu ngữ cảnh theo vai trò, phím tắt; báo cáo có tham số, nhóm và cộng nhóm, xem "
                     "trước khi in, in, phiếu thu, xuất PDF/Excel"],
        ["Triển khai", "CI build/test macOS + Windows và toàn bộ kiểm thử với SQL Server trên Linux; tự đóng gói "
                       "setup.exe/zip/dmg, tự kiểm tra bản cài (self-test, cài thử), phê duyệt và chứng thực trước khi "
                       "phát hành; tài liệu cài đặt"],
        ["Mô hình tiên tiến", "Chuyển đổi sang OODB, thiết kế + demo phân mảnh phân tán, thiết kế NoSQL, bảng so sánh"],
    ], widths_cm=[3.6, 12.4], caption="Tổng hợp kết quả")

    r.h2("8.2. Khó khăn và cách khắc phục")
    r.table(["Khó khăn", "Nguyên nhân", "Cách khắc phục"], [
        ["Giáo vụ bị báo “EXECUTE permission denied on fn_FinalGrade” khi đọc view kết quả học tập",
         "SQL Server 2019+ tự inline hàm vô hướng; khi hàm được inline bọc lời gọi hàm khác, ownership chaining bị đứt",
         "Tắt TSQL_SCALAR_UDF_INLINING ở mức CSDL (có kiểm tra phiên bản để vẫn chạy trên 2012-2017)"],
        ["Lỗi 468 collation conflict khi so sánh với USER_NAME()", "Contained DB dùng collation catalog khác collation tiếng Việt của cột",
         "COLLATE DATABASE_DEFAULT trong phép so sánh"],
        ["BULK INSERT lỗi font tiếng Việt trên Docker", "Linux không hỗ trợ CODEPAGE = '65001'", "File UTF-16 LE + DATAFILETYPE = 'widechar'"],
        ["Script chạy được trong SSMS nhưng lỗi khi chạy bằng sqlcmd", "sqlcmd mặc định QUOTED_IDENTIFIER OFF (cần cho filtered index, phương thức XML)",
         "SET QUOTED_IDENTIFIER ON đầu mỗi file, sqlcmd -I -f 65001"],
        ["Driver ODBC 18 trên macOS không nạp được OpenSSL; không đóng gói hợp lệ được", "Driver tìm OpenSSL theo đường dẫn Homebrew cố định; giấy phép không cho sửa driver",
         "Bản .dmg kèm driver mã nguồn mở FreeTDS (LGPL), ứng dụng tự thử nhiều driver"],
        ["Thành viên dùng hệ điều hành khác nhau, nhiều ngành", "Windows/macOS, kinh nghiệm lập trình khác nhau",
         "CMake + Qt đa nền tảng, CI kiểm tra cả hai hệ điều hành; phân công theo mảng nội dung"],
    ], widths_cm=[4.6, 5.4, 6.0], caption="Khó khăn và cách khắc phục")

    r.h2("8.3. Hạn chế và hướng phát triển")
    r.bullets([
        "Một số thao tác quản trị vẫn làm trong SSMS: khôi phục (restore) CSDL, xem nhật ký thay đổi `AUDIT_LOG`, xóa hẳn "
        "chi nhánh, khóa học, giáo viên hay nhân viên (ứng dụng chỉ chuyển sang trạng thái ngừng hoạt động để giữ lịch sử).",
        "Bản cài macOS chưa ký bằng Apple Developer ID nên lần đầu mở cần xác nhận trong System Settings.",
        "Chưa triển khai CSDL phân tán thật trên nhiều máy chủ (mới mô phỏng trên một máy chủ).",
        "Hướng phát triển: cổng thông tin cho học viên/phụ huynh (web), nhắc nợ học phí qua email/SMS, đồng bộ dữ liệu "
        "giữa các chi nhánh, báo cáo có tham số và biểu đồ nâng cao.",
    ])

    r.h2("8.4. Bài học kinh nghiệm")
    r.bullets([
        "Đặt quy tắc nghiệp vụ tại CSDL giúp dữ liệu luôn đúng bất kể truy cập từ ứng dụng hay SSMS; ứng dụng chỉ cần "
        "hiển thị thông báo của CSDL.",
        "Phân quyền qua role + view/thủ tục + ownership chaining gọn và an toàn hơn nhiều so với cấp quyền trên từng bảng.",
        "Kiểm thử bằng kịch bản tự động (ROLLBACK sau mỗi ca) giúp sửa CSDL mạnh tay mà không sợ hỏng dữ liệu mẫu.",
        "Công cụ AI hỗ trợ viết mã nhanh, nhưng mỗi thành viên vẫn phải tự chạy, đọc hiểu và giải thích được phần mình phụ trách.",
    ])


def references(r):
    r.h1_unnumbered("TÀI LIỆU THAM KHẢO")
    r.numbered([
        "Kenneth C. Laudon, Jane P. Laudon (2011). *Management Information Systems* (12th Edition). Prentice Hall.",
        "Ramez Elmasri, Shamkant B. Navathe (2010). *Fundamentals of Database Systems* (6th Edition). Addison-Wesley.",
        "Itzik Ben-Gan (2012). *Microsoft SQL Server 2012 T-SQL Fundamentals*. Microsoft Press.",
        "Nguyễn Gia Tuấn Anh và cộng sự. *Bài giảng Quản lý thông tin (IE103)*, Trường ĐH Công nghệ Thông tin - ĐHQG TP.HCM.",
        "Microsoft. *SQL Server technical documentation* - Contained databases, Ownership chains, XML data (SQL Server), "
        "Scalar UDF inlining, BACKUP/RESTORE (learn.microsoft.com/sql).",
        "The Qt Company. *Qt 6 Documentation* - Qt SQL (QODBC), Qt Widgets, deployment (doc.qt.io).",
        "Robert C. Martin (2017). *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall.",
        "M. Tamer Özsu, Patrick Valduriez (2020). *Principles of Distributed Database Systems* (4th Edition). Springer.",
    ])


def appendix(r):
    r.h1_unnumbered("PHỤ LỤC: HƯỚNG DẪN CÀI ĐẶT VÀ CHẠY THỬ")
    r.h2("A. Khởi tạo CSDL")
    r.bullets([
        "**Windows** (SQL Server Express/Developer + SSMS): mở PowerShell tại thư mục mã nguồn, chạy "
        "`.\\scripts\\db_init.ps1` (hoặc `-Server \"localhost\\SQLEXPRESS\"`); hoặc mở lần lượt `database/00` → `07` trong SSMS.",
        "**macOS/Linux** (Docker): `docker compose up -d`, sau đó `SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker imcp-mssql`.",
        f"Kiểm thử: chạy `database/12_tests.sql` - bảng kết quả cuối file phải có {len(database_tests())}/{len(database_tests())} ca PASSED.",
    ])
    r.h2("B. Cài ứng dụng")
    r.bullets([
        "Tải file cài trong mục **Releases** của kho GitHub công khai `nhutruong-uit/imcp` (không cần tài khoản GitHub).",
        "Windows: chạy `...-setup.exe` (không cần quyền admin) hoặc giải nén bản portable; nếu SmartScreen cảnh báo chọn "
        "*More info → Run anyway*.",
        "macOS: mở `.dmg`, kéo QLTTTA vào Applications; lần đầu mở chọn *System Settings → Privacy & Security → Open Anyway*.",
        "Màn hình đăng nhập → *Cấu hình máy chủ*: máy chủ `localhost` (hoặc `localhost,1433`), CSDL `QLTTTA`.",
    ])
    r.h2("C. Tài khoản demo")
    r.table(["Tên đăng nhập", "Vai trò", "Ghi chú"], [
        ["ql_quan", "Quản lý", "Xem toàn bộ, quản trị tài khoản, sao lưu"],
        ["gvu_lan / gvu_ha", "Giáo vụ", "Chi nhánh Quận 1 / Thủ Đức"],
        ["kt_minh / kt_tung", "Kế toán", "Thu học phí, công nợ, doanh thu, lương"],
        ["gv_john, gv_hoanganh, gv_hoa, gv_bao", "Giáo viên", "Chỉ dữ liệu lớp mình dạy"],
    ], widths_cm=[5.2, 2.8, 8.0], caption="Tài khoản demo (mật khẩu trong docs/SETUP.md)")
    r.h2("D. Cấu trúc mã nguồn")
    r.table(["Thư mục", "Nội dung"], [
        ["database/", "00-07 cài đặt CSDL; 08 truy vấn minh họa; 09 backup/restore; 10 import/export; 11 CSDL phân tán; 12 kiểm thử"],
        ["src/domain/", "Thực thể, quy tắc nghiệp vụ"],
        ["src/application/", "Use case, port (interface), ma trận phân quyền"],
        ["src/infrastructure/", "Kết nối ODBC, repository gọi thủ tục, ánh xạ lỗi"],
        ["src/presentation/", "Giao diện Qt Widgets (menu, form, báo cáo)"],
        ["src/app/", "Composition root: main.cpp, AppContainer"],
        ["tests/", "Unit test và kiểm thử end-to-end qua giao diện (Qt Test)"],
        ["tools/", "Công cụ chụp màn hình tự động"],
        ["scripts/, packaging/", "Khởi tạo CSDL, đóng gói; icon, Inno Setup, Info.plist"],
        [".github/workflows/", "CI (build + test) và Release (tạo file cài)"],
        ["docs/", "Tài liệu dự án và báo cáo (docs/report)"],
    ], widths_cm=[4.2, 11.8], caption="Cấu trúc kho mã nguồn")
