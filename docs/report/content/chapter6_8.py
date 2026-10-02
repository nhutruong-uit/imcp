"""Chapter 6 - Presenting information (application); Chapter 7 - Advanced databases; Chapter 8 - Conclusion;
references, appendix."""
from content.common import IMG, SQL, object_counts, database_tests
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
        ["domain", "Thực thể và quy tắc nghiệp vụ thuần, chỉ dùng Qt Core", "Student::validate() - dưới 18 tuổi phải có phụ huynh; Result<T>"],
        ["application", "Use case + port (interface) mà tầng ngoài phải hiện thực; ma trận phân quyền menu", "StudentService, AuthService, LanguageService, Permissions, IStudentRepository"],
        ["infrastructure", "Kết nối ODBC, gọi thủ tục, ánh xạ lỗi SQL thành thông báo dễ hiểu, lưu cấu hình", "DatabaseManager, SqlStudentRepository, SqlErrorMapper"],
        ["presentation", "Giao diện Qt Widgets song ngữ Việt/Anh; không chứa câu lệnh SQL", "LoginDialog, MainWindow, StudentPage, form .ui, I18n"],
        ["app", "Composition root: khởi tạo đối tượng, nối các tầng", "main.cpp, AppContainer"],
    ], widths_cm=[2.6, 6.6, 6.8], caption="Các tầng của ứng dụng", size=9.5)
    r.p("Lợi ích cụ thể: toàn bộ SQL nằm ở tầng infrastructure nên dễ đối chiếu với thủ tục trong CSDL; use case được "
        "**kiểm thử đơn vị bằng repository giả** (không cần SQL Server); nếu đổi hệ quản trị CSDL chỉ cần viết lại các lớp "
        "`Sql*Repository`. Quy tắc nghiệp vụ được kiểm tra **hai lớp**: tại ứng dụng để phản hồi nhanh, và tại CSDL "
        "(CHECK/trigger/thủ tục) là nguồn sự thật cuối cùng.")

    r.h2("6.2. Đăng nhập và menu theo vai trò")
    r.p("Màn hình đăng nhập mở kết nối ODBC bằng chính tài khoản SQL Server của người dùng; ứng dụng tự thử lần lượt "
        "ODBC Driver 18 → 17 → driver “SQL Server” có sẵn của Windows (bản macOS kèm sẵn driver FreeTDS), nên chạy được "
        "trên máy chưa cài driver mới. Sau khi đăng nhập, menu bên trái được sinh theo vai trò (Chương 4 môn học - Menu).")
    r.figure(SCR / "login.png", "Màn hình đăng nhập (cấu hình máy chủ thu gọn)", width_cm=12)
    r.figure(SCR / "ql_quan_dashboard.png", "Trang Tổng quan của Quản lý: chỉ số chính và biểu đồ doanh thu theo tháng", width_cm=16)
    r.table(["Vai trò", "Menu hiển thị"], [
        ["Quản lý", "Tổng quan, Học viên, Lớp học, Lịch học tuần này, Kết quả học tập, Công nợ, Doanh thu, Lương giáo viên, Tài khoản"],
        ["Giáo vụ", "Tổng quan, Học viên, Lớp học, Lịch học tuần này, Kết quả học tập, Công nợ"],
        ["Kế toán", "Tổng quan, Học viên (chỉ xem), Công nợ, Doanh thu, Lương giáo viên"],
        ["Giáo viên", "Lớp của tôi, Lịch dạy, Lương của tôi"],
    ], widths_cm=[3.0, 13.0], caption="Menu theo vai trò", size=10)
    r.figure(SCR / "gv_john_my_teaching_schedule.png", "Giáo viên chỉ thấy lịch dạy của chính mình (dữ liệu từ view vw_Teacher_MySchedule)", width_cm=16)
    r.p("Ẩn menu chỉ là lớp giao diện; quyền thật sự được kiểm tra trong CSDL. Ví dụ giáo vụ vẫn mở được Tổng quan "
        "(gọi `usp_Dashboard_Stats`) nhưng thủ tục dùng `fn_CurrentRole()` để trả **NULL** cho cột doanh thu, còn "
        "`fn_MonthlyRevenue` không được GRANT cho `rl_AcademicStaff` nên biểu đồ bị SQL Server từ chối. Ứng dụng chỉ hiển thị "
        "kết quả đó: thẻ doanh thu ghi “Không có quyền” (ca kiểm thử P11).")
    r.figure(SCR / "gvu_lan_dashboard.png", "Tổng quan của Giáo vụ: doanh thu bị CSDL ẩn theo vai trò", width_cm=14)

    r.h2("6.3. Form nhập liệu")
    r.p("Form học viên được thiết kế bằng **Qt Designer** (file `StudentFormDialog.ui`): ô điện thoại chỉ nhận chữ số, "
        "ngày sinh chọn bằng lịch, nhóm thông tin phụ huynh tự đổi thành bắt buộc khi học viên dưới 18 tuổi, lỗi hiển thị "
        "ngay trên form. Khi lưu, ứng dụng gọi `usp_Student_Add`/`usp_Student_Update`; lỗi từ CSDL (trùng SĐT, vi phạm "
        "CHECK) được chuyển thành thông báo dễ hiểu theo ngôn ngữ giao diện.")
    r.figure(SCR / "gvu_lan_student_form.png", "Form sửa thông tin học viên (thiết kế bằng Qt Designer)", width_cm=10)
    r.figure(SCR / "ql_quan_students.png", "Màn hình quản lý học viên: tìm kiếm, lọc, thêm/sửa/xóa, xuất Excel/PDF", width_cm=16)

    r.h2("6.4. Báo cáo")
    r.p("Bài giảng giới thiệu Crystal Report với các phần Report Header, Page Header, Details, Group, Page/Report Footer. "
        "Crystal Report chỉ chạy trên .NET/Windows nên không dùng được cho ứng dụng Qt đa nền tảng; nhóm hiện thực bộ "
        "xuất báo cáo PDF tương đương bằng `QTextDocument` + `QPdfWriter`:")
    r.table(["Thành phần Crystal Report", "Trong báo cáo PDF của QLTTTA"], [
        ["Report Header", "Tên trung tâm, tiêu đề báo cáo, ngày lập, người lập"],
        ["Page Header", "Dòng tiêu đề cột lặp lại đầu mỗi trang"],
        ["Details", "Dữ liệu đã lọc/sắp xếp trên màn hình, định dạng tiền tệ và ngày theo kiểu Việt Nam"],
        ["Report Footer", "Dòng TỔNG CỘNG cho các cột tiền (đã đóng, còn nợ, doanh thu, lương), tổng số dòng"],
        ["Page Footer", "Số trang tự động"],
        ["Nguồn dữ liệu / tham số", "View và thủ tục báo cáo (usp_Report_Revenue, usp_Report_ClassResults...)"],
    ], widths_cm=[5.0, 11.0], caption="Đối chiếu cấu trúc báo cáo", size=10)
    r.figure(SCR / "kt_minh_outstanding_tuition.png", "Màn hình công nợ học phí của Kế toán, có dòng tổng và nút xuất báo cáo PDF", width_cm=16)
    r.figure(SCR / "gvu_lan_learning_results.png", "Báo cáo kết quả học tập (điểm tổng kết, xếp loại, chuyên cần)", width_cm=16)

    r.h2("6.5. Đa nền tảng, CI/CD và đóng gói")
    r.p("Nhóm dùng GitHub với hai nhánh chính `develop` (nhánh mặc định) và `main`. Trước khi tạo Pull Request, "
        "`scripts/test_all` chạy toàn bộ kiểm thử trên máy (CI không có SQL Server). GitHub Actions tự động build và "
        "chạy unit test trên **macOS và Windows** khi merge vào `develop` và cho mỗi Pull Request vào `main` - nhánh "
        "`main` bật branch protection nên chỉ merge được khi hai job này xanh; khi merge vào `main`, quy trình Release "
        "tự đóng gói:")
    r.figure(IMG / "diagrams" / "cicd.png", "Quy trình CI/CD từ nhánh tính năng tới file cài", width_cm=16)
    r.table(["Hệ điều hành", "File cài", "Cách đóng gói"], [
        ["Windows 10/11 x64", "QLTTTA-x.y.z-windows-x64-setup.exe, ...-portable.zip", "windeployqt (Qt + runtime MinGW + plugin ODBC), Inno Setup, cài không cần quyền admin"],
        ["macOS 12+ (Apple Silicon)", "QLTTTA-x.y.z-macos-arm64.dmg", "macdeployqt, kèm FreeTDS + unixODBC + OpenSSL (đổi đường dẫn sang @loader_path), ký ad-hoc"],
    ], widths_cm=[3.4, 5.6, 7.0], caption="File cài đặt", size=9.5)
    r.p("Cùng các script `scripts/package-macos.sh` và `scripts/package-windows.ps1`, thành viên có thể tự tạo file "
        "cài trên máy cá nhân giống hệt CI. Chế độ `--check-connection` giúp kiểm tra kết nối/đăng nhập không cần giao diện.")

    r.h2("6.6. Kiểm thử ứng dụng")
    r.bullets([
        "**Unit test** (Qt Test): kiểm tra quy tắc Student, ánh xạ vai trò, use case thêm học viên (dùng repository giả), "
        "đăng nhập/đổi mật khẩu, ma trận phân quyền, ánh xạ lỗi SQL và chuỗi kết nối ODBC, bản dịch giao diện (mọi chuỗi, "
        "giá trị lưu trong CSDL và thông báo nghiệp vụ của CSDL đều có bản tiếng Việt) - 4 bộ test, chạy tự động trên CI.",
        "**Kiểm thử end-to-end qua giao diện** (`tests/tst_e2e_gui.cpp`): chương trình gõ phím, bấm nút trên chính các "
        "màn hình với CSDL thật - đăng nhập sai bị từ chối; giáo vụ tìm kiếm, thêm học viên 10 tuổi (lần đầu thiếu phụ "
        "huynh bị báo lỗi, bổ sung thì lưu được) rồi xóa; giáo viên chỉ thấy 2 lớp của mình; kế toán không có nút thêm học "
        "viên, xem công nợ và xuất PDF/CSV; đổi mật khẩu nhập lại sai hoặc sai mật khẩu hiện tại bị chặn (thông báo tiếng "
        "Anh của CSDL được hiển thị bằng tiếng Việt); vừa đăng nhập phải mở sẵn trang đầu tiên, thẻ doanh thu của giáo vụ "
        "ghi \"Không có quyền\"; **mỗi vai trò mở lần lượt mọi chức năng được phép** và trang phải có dữ liệu (thiếu một "
        "lệnh GRANT là bị phát hiện); sửa học viên qua form và đọc lại từ CSDL; lọc nhanh thì dòng tổng tính lại đúng; "
        "chuyển giao diện sang tiếng Anh rồi về tiếng Việt. Kết quả: 10/10 kịch bản đạt, dữ liệu trở về nguyên trạng. "
        "Trên CI (không có SQL Server) bài kiểm thử được ghi nhận là bỏ qua (Skipped).",
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
    r.figure(IMG / "diagrams" / "distributed_database.png", "Thiết kế phân mảnh và cấp phát dữ liệu theo chi nhánh", width_cm=15)
    r.table(["Kỹ thuật", "Áp dụng", "Lý do"], [
        ["Phân mảnh ngang chính", "STUDENT_BRi = σ BranchId = 'BRi' (STUDENT); CLASS_BRi tương tự", "Mỗi chi nhánh truy cập cục bộ học viên, lớp của mình"],
        ["Phân mảnh ngang dẫn xuất", "ENROLLMENT_BRi = ENROLLMENT ⋉ CLASS_BRi; RECEIPT, ATTENDANCE, GRADE theo ENROLLMENT", "Giữ dữ liệu phụ thuộc cùng trạm với lớp để phép kết thực hiện cục bộ"],
        ["Phân mảnh dọc", "TEACHER → TEACHER_PUBLIC (hồ sơ) và TEACHER_PAY (đơn giá)", "Thông tin lương chỉ đặt ở trạm trung tâm (bảo mật)"],
        ["Nhân bản", "PROGRAM, COURSE, GRADE_COMPONENT, PROMOTION ở mọi trạm", "Ít thay đổi, đọc nhiều"],
        ["Trong suốt phân tán", "View UNION ALL (distributed partitioned view) tại trạm trung tâm", "Ứng dụng báo cáo không cần biết dữ liệu nằm ở đâu"],
    ], widths_cm=[3.4, 7.2, 5.4], caption="Thiết kế CSDL phân tán cho QLTTTA", size=9.5)
    r.p("Tính đúng đắn của phân mảnh ngang STUDENT được kiểm chứng bằng script `11_distributed_demo.sql` (2 CSDL trên "
        "cùng máy chủ mô phỏng 2 trạm; triển khai thật dùng Linked Server):")
    r.table(["OriginalTable", "FragmentBR01", "FragmentBR02", "Reconstructed", "Overlap"], [["72", "47", "25", "72", "0"]],
            widths_cm=[3.2] * 5, caption="Kiểm tra tính đầy đủ, tái thiết và tách biệt của phân mảnh", size=10,
            align=["center"] * 5)
    r.bullets([
        "**Đầy đủ (completeness)**: 47 + 25 = 72 dòng - mọi học viên thuộc một mảnh.",
        "**Tái thiết (reconstruction)**: STUDENT = STUDENT_BR01 ∪ STUDENT_BR02 (view UNION ALL trả về 72 dòng).",
        "**Tách biệt (disjointness)**: không StudentId nào thuộc cả hai mảnh (0 dòng trùng); ràng buộc CHECK (BranchId = 'BRi') ở "
        "mỗi mảnh còn giúp bộ tối ưu chỉ quét đúng mảnh khi truy vấn có điều kiện BranchId.",
    ])
    r.code("View phân tán tại trạm trung tâm (11_distributed_demo.sql)",
           sql_block(SQL, "11_distributed_demo.sql", "CREATE VIEW dbo.vw_Student_AllBranches", "GO"))
    r.p("Yêu cầu khi triển khai thật: giao dịch ghi danh/chuyển lớp giữa hai chi nhánh cần giao thức hai pha (2PC, "
        "MSDTC); danh mục nhân bản cần cơ chế đồng bộ (replication) một chiều từ trạm trung tâm; nếu mất kết nối, chi "
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
    ], widths_cm=[2.4, 2.4, 5.4, 5.8], caption="Áp dụng các mô hình NoSQL", size=9.5)
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
    ], widths_cm=[3.0, 3.4, 3.0, 3.2, 3.4], caption="So sánh các mô hình CSDL đối với bài toán quản lý trung tâm tiếng Anh", size=9)
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
        ["Kiểm thử", f"{passed}/{len(database_tests())} ca kiểm thử CSDL đạt; 4 bộ unit test; 10/10 kịch bản end-to-end qua giao diện"],
        ["Ứng dụng", "Qt 6 đa nền tảng, Clean Architecture, giao diện song ngữ Việt/Anh, đăng nhập theo vai trò, Tổng quan, Học viên, 10 màn hình tra cứu, xuất PDF/Excel"],
        ["Triển khai", "CI build/test macOS + Windows, tự đóng gói setup.exe/zip/dmg, tài liệu cài đặt"],
        ["Mô hình tiên tiến", "Chuyển đổi sang OODB, thiết kế + demo phân mảnh phân tán, thiết kế NoSQL, bảng so sánh"],
    ], widths_cm=[3.6, 12.4], caption="Tổng hợp kết quả", size=10)

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
    ], widths_cm=[4.6, 5.4, 6.0], caption="Khó khăn và cách khắc phục", size=9)

    r.h2("8.3. Hạn chế và hướng phát triển")
    r.bullets([
        "Ứng dụng mới hoàn thiện module mẫu Học viên và các màn hình tra cứu; các form Ghi danh, Thu học phí - in biên lai, "
        "Điểm danh, Nhập điểm, Quản trị tài khoản đang được phát triển theo cùng kiến trúc (thủ tục CSDL đã sẵn sàng).",
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
        "Tải file cài trong mục **Releases** của kho GitHub `nhutruong-uit/imcp` (giảng viên được mời làm collaborator).",
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
    ], widths_cm=[5.2, 2.8, 8.0], caption="Tài khoản demo (mật khẩu chung ghi trong docs/SETUP.md)", size=10)
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
    ], widths_cm=[4.2, 11.8], caption="Cấu trúc kho mã nguồn", size=10)
