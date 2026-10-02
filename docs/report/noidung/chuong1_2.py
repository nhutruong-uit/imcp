"""Chương 1 - Tổng quan; Chương 2 - Phân tích yêu cầu."""
from noidung.chung import IMG, THANH_VIEN, doi_tuong


def chuong1(r):
    r.h1("CHƯƠNG 1: TỔNG QUAN ĐỀ TÀI")

    r.h2("1.1. Lý do chọn đề tài")
    r.p("Nhu cầu học tiếng Anh tại TP. Hồ Chí Minh rất lớn: học sinh cần chứng chỉ để xét tuyển, sinh viên cần "
        "chuẩn đầu ra TOEIC/IELTS, người đi làm cần giao tiếp trong công việc. Các trung tâm tiếng Anh vừa và nhỏ "
        "thường có nhiều chi nhánh, hàng chục lớp chạy song song, mỗi lớp có lịch học, giáo viên, phòng học và "
        "học phí riêng, nhưng vẫn quản lý bằng bảng tính Excel rời rạc theo từng bộ phận.")
    r.p("Cách làm này gây ra các vấn đề quen thuộc của bài toán **quản lý thông tin**: dữ liệu học viên bị nhập "
        "trùng ở bộ phận tư vấn, giáo vụ và kế toán; không kiểm soát được trùng lịch phòng/giáo viên; công nợ học "
        "phí tính tay dễ sai; giáo viên có thể xem được thông tin cá nhân và học phí của học viên lớp khác; khi máy "
        "tính hỏng thì mất dữ liệu vì không có chiến lược sao lưu. Đề tài **Hệ thống quản lý trung tâm tiếng Anh "
        "(QLTTTA)** được chọn vì bao phủ đầy đủ quy trình quản lý thông tin của môn học: thu thập, tổ chức, xử lý, "
        "trình bày và bảo mật thông tin, đồng thời gần gũi với thực tế nên dễ kiểm chứng.")

    r.h2("1.2. Khảo sát hiện trạng")
    r.p("Nhóm khảo sát mô hình hoạt động phổ biến của một chuỗi trung tâm tiếng Anh quy mô 2 chi nhánh "
        "(Quận 1 và TP. Thủ Đức) với khoảng 70-150 học viên mỗi khóa. Bộ máy và công việc chính như sau:")
    r.table(["Bộ phận", "Công việc chính", "Thông tin sử dụng", "Khó khăn hiện tại"], [
        ["Tư vấn / Giáo vụ", "Tiếp nhận học viên, kiểm tra xếp lớp, mở lớp, xếp lịch, ghi danh, chuyển lớp, bảo lưu",
         "Hồ sơ học viên, điểm kiểm tra, khóa học, lớp, lịch, phòng", "Trùng lịch phòng/giáo viên; khó biết lớp còn chỗ"],
        ["Kế toán", "Thu học phí nhiều đợt, khuyến mãi, theo dõi công nợ, doanh thu, chốt lương giáo viên",
         "Ghi danh, phiếu thu, khuyến mãi, buổi dạy", "Đối chiếu công nợ thủ công, sửa/xóa phiếu thu không dấu vết"],
        ["Giáo viên", "Điểm danh, nhập điểm, theo dõi lịch dạy, xem lương",
         "Danh sách lớp mình dạy, buổi học, điểm", "Nhận danh sách qua tin nhắn, không chuẩn hóa"],
        ["Ban quản lý", "Mở khóa học, chính sách học phí, theo dõi doanh thu, sĩ số, chất lượng",
         "Thống kê tổng hợp toàn hệ thống", "Phải chờ các bộ phận tổng hợp Excel"],
    ], widths_cm=[2.6, 5.0, 4.2, 4.2], caption="Các bộ phận và nhu cầu thông tin của trung tâm", size=10)

    r.h2("1.3. Mục tiêu đề tài")
    r.bullets([
        "Phân tích bài toán quản lý và thiết kế **mô hình dữ liệu** ở mức quan niệm (ERD, CD) và mức logic "
        "(mô hình quan hệ đạt 3NF), có đầy đủ ràng buộc toàn vẹn.",
        "Cài đặt CSDL trên **Microsoft SQL Server** với stored procedure, function, trigger, cursor, view; khai "
        "thác dữ liệu bằng SQL và XPath/XQuery trên dữ liệu XML.",
        "Bảo đảm **an ninh dữ liệu**: xác thực người dùng bằng DBMS, phân quyền theo vai trò, nhật ký kiểm toán, "
        "sao lưu/phục hồi, nhập/xuất dữ liệu.",
        "Xây dựng ứng dụng **trình bày thông tin** (menu, form, report) chạy được trên cả Windows và macOS, có file "
        "cài đặt để giảng viên kiểm tra nhanh.",
        "Phân tích, so sánh khả năng áp dụng các **mô hình CSDL tiên tiến** (hướng đối tượng, phân tán, NoSQL) cho bài toán.",
    ])

    r.h2("1.4. Phạm vi và đối tượng sử dụng")
    r.p("Hệ thống phục vụ 4 nhóm người dùng nội bộ của trung tâm: **Quản lý, Giáo vụ, Kế toán, Giáo viên**. Học "
        "viên và phụ huynh là đối tượng được quản lý thông tin (không đăng nhập hệ thống trong phạm vi đồ án). "
        "Phạm vi nghiệp vụ gồm: chi nhánh - phòng học, nhân sự, chương trình - khóa học, kiểm tra đầu vào, lớp học - "
        "lịch học - buổi học, ghi danh, khuyến mãi, học phí - công nợ, điểm danh, điểm số, xét kết quả - cấp chứng "
        "nhận, lương giáo viên, tài khoản và nhật ký hệ thống. Ngoài phạm vi: kế toán tổng hợp, marketing, học trực tuyến.")

    r.h2("1.5. Công nghệ sử dụng và lý do lựa chọn")
    r.p("Yêu cầu của môn học (stored procedure, trigger, function, cursor, phân quyền và xác thực CSDL, "
        "backup/restore, XPath/XQuery; công cụ thực hành SSMS) là tiêu chí quan trọng nhất khi chọn hệ quản trị CSDL. "
        "Nhóm đã so sánh ba phương án:")
    r.table(["Tiêu chí", "SQLite", "PostgreSQL", "SQL Server (chọn)"], [
        ["Stored procedure / Function", "Không có", "Có (PL/pgSQL)", "Có (T-SQL, giống bài thực hành)"],
        ["Trigger / Cursor", "Trigger hạn chế, không cursor", "Có", "Có, đủ AFTER/INSTEAD OF"],
        ["Xác thực, user, role, GRANT/DENY", "Không có", "Có", "Có, thêm contained database user"],
        ["Backup Full/Differential/Log", "Sao chép file", "pg_dump, WAL", "BACKUP/RESTORE bằng T-SQL"],
        ["XML, XPath/XQuery", "Không", "Chỉ XPath 1.0", "Kiểu XML, XSD, XQuery đầy đủ"],
        ["Công cụ trên lớp", "-", "-", "SSMS, VS Code (mssql)"],
        ["Phân phối ứng dụng", "Rất dễ (1 file)", "Cần máy chủ", "Cần SQL Server (Express miễn phí/Docker)"],
    ], widths_cm=[4.2, 3.4, 3.6, 4.8], caption="So sánh lựa chọn hệ quản trị CSDL", size=10)
    r.p("SQLite thuận tiện để phát hành nhưng **không đáp ứng** phần lập trình CSDL và an ninh CSDL của đề cương; "
        "PostgreSQL đáp ứng phần lớn nhưng khác cú pháp với bài thực hành và không có XQuery. Vì vậy nhóm chọn "
        "**SQL Server**, viết script tương thích từ bản 2012 trở lên để chạy được cả trên máy phòng thực hành.")
    r.table(["Thành phần", "Công nghệ", "Vai trò"], [
        ["Hệ quản trị CSDL", "Microsoft SQL Server 2022 (tương thích 2012+)", "Lưu trữ, ràng buộc, xử lý nghiệp vụ, phân quyền"],
        ["Ngôn ngữ ứng dụng", "C++17 (đã học trên trường)", "Thống nhất ngôn ngữ cho cả nhóm"],
        ["Giao diện", "Qt 6 Widgets, Qt Designer (.ui)", "Menu, form, báo cáo; chạy Windows và macOS"],
        ["Kết nối CSDL", "Qt SQL + ODBC (Driver 18/17, FreeTDS)", "Gọi thủ tục, đọc view"],
        ["Kiến trúc", "Clean Architecture 4 tầng", "Tách nghiệp vụ khỏi giao diện và CSDL, dễ kiểm thử"],
        ["Build, kiểm thử", "CMake, Ninja, Qt Test", "Biên dịch đa nền tảng, unit test"],
        ["Quản lý mã nguồn, CI/CD", "Git, GitHub, GitHub Actions", "Làm việc nhóm, tự động build và tạo file cài"],
        ["Mô hình hóa", "Graphviz, Mermaid", "Vẽ ERD, CD, DFD, use case, kiến trúc"],
    ], widths_cm=[3.4, 6.0, 6.6], caption="Công nghệ sử dụng trong đồ án", size=10)

    r.h2("1.6. Tổ chức nhóm và phân công")
    r.p("Nhóm gồm 5 thành viên thuộc nhiều ngành khác nhau. Để mọi thành viên đều làm chủ được một phần kiến thức "
        "của môn học và trả lời được câu hỏi khi báo cáo, nhóm phân công theo **mảng nội dung** thay vì theo màn hình:")
    r.table(["Thành viên", "MSSV", "Phụ trách chính"],
            [[tv["ten"] + (" (NT)" if i == 0 else ""), tv["mssv"], tv["mang"]] for i, tv in enumerate(THANH_VIEN)],
            widths_cm=[3.8, 2.2, 10.0], caption="Phân công thành viên", size=10)
    r.p("Nhóm trưởng cùng công cụ AI Claude Code (được giảng viên cho phép) đảm nhận phần lập trình ứng dụng; các "
        "thành viên rà soát script CSDL, kiểm thử trên SSMS, góp ý qua Issue/Pull Request trên GitHub và hoàn thiện "
        "phần báo cáo của mình. Quy trình và lịch làm việc chi tiết nằm trong `docs/PLAN.md` của kho mã nguồn.")


def chuong2(r):
    r.h1("CHƯƠNG 2: PHÂN TÍCH YÊU CẦU")

    r.h2("2.1. Quy trình quản lý thông tin của trung tâm")
    r.p("Theo Chương 1 của môn học, quản lý thông tin gồm 5 bước: **Thu thập → Tổ chức → Xử lý/Chuyển đổi → "
        "Trình bày → Bảo mật**. Bảng sau ánh xạ từng bước vào hệ thống QLTTTA:")
    r.table(["Bước", "Trong hệ thống QLTTTA", "Công cụ/đối tượng hiện thực"], [
        ["Thu thập", "Phiếu đăng ký học viên, bài kiểm tra đầu vào, phiếu thu, điểm danh, điểm số",
         "Form nhập liệu, thủ tục usp_*_Them, nhập XML/CSV"],
        ["Tổ chức", f"Mô hình hóa thành {doi_tuong()['SoBang']} bảng quan hệ, dữ liệu bán cấu trúc lưu dạng XML",
         "ERD, CD, mô hình quan hệ 3NF, XML Schema"],
        ["Xử lý / Chuyển đổi", "Tính học phí sau khuyến mãi, công nợ, điểm tổng kết, chuyên cần, lương; "
         "chuyển quan hệ ↔ XML", "Function, trigger, cursor, FOR XML, XQuery"],
        ["Trình bày", "Danh sách, thống kê, biểu đồ doanh thu, báo cáo PDF/Excel theo vai trò",
         "View, ứng dụng Qt (menu, form, report)"],
        ["Bảo mật", "Xác thực, phân quyền theo vai trò, nhật ký, sao lưu/phục hồi",
         "Contained user, role, GRANT/DENY, audit trigger, BACKUP/RESTORE"],
    ], widths_cm=[2.8, 7.0, 6.2], caption="Quy trình quản lý thông tin áp dụng cho đề tài", size=10)

    r.h2("2.2. Quy trình nghiệp vụ chính")
    r.numbered([
        "**Tuyển sinh và kiểm tra đầu vào**: giáo vụ ghi nhận hồ sơ học viên (dưới 18 tuổi phải có thông tin phụ "
        "huynh). Học viên làm bài kiểm tra 4 kỹ năng; hệ thống tính điểm tổng và **tự đề xuất khóa học** phù hợp.",
        "**Mở lớp và xếp lịch**: giáo vụ mở lớp cho một khóa học tại chi nhánh, chọn giáo viên, phòng học, ngày khai "
        "giảng và lịch học trong tuần. Hệ thống kiểm tra trùng phòng/trùng giáo viên và **tự sinh đủ số buổi học**.",
        "**Ghi danh**: học viên ghi danh vào lớp đang tuyển sinh/đang học. Điều kiện: lớp còn chỗ, học viên đã đạt khóa "
        "tiên quyết hoặc đủ điểm đầu vào, không trùng lịch với lớp đang học; áp dụng khuyến mãi còn hiệu lực.",
        "**Thu học phí**: kế toán lập phiếu thu (đóng một hoặc nhiều đợt). Số tiền đã đóng và công nợ được cập nhật "
        "tự động; không được thu vượt học phí; phiếu thu chỉ được **hủy có lý do**, không được xóa.",
        "**Giảng dạy**: giáo viên xác nhận buổi đã dạy, điểm danh học viên và nhập điểm các cột điểm của khóa học "
        "(chỉ với lớp mình phụ trách).",
        "**Xét kết quả và cấp chứng nhận**: cuối khóa, hệ thống tính điểm tổng kết theo trọng số, tỷ lệ chuyên cần; "
        "học viên đạt (điểm ≥ 5 và chuyên cần ≥ 80%) được cấp chứng nhận có số hiệu.",
        "**Chốt lương giáo viên**: cuối tháng, kế toán chốt lương theo số giờ đã dạy × đơn giá giờ, thưởng nếu dạy từ "
        "20 buổi.",
        "**Báo cáo và giám sát**: quản lý xem tổng quan, doanh thu, công nợ, kết quả học tập; quản trị tài khoản, "
        "sao lưu dữ liệu; mọi thay đổi điểm và phiếu thu được ghi nhật ký.",
    ])

    r.h2("2.3. Tác nhân và vai trò")
    r.table(["Tác nhân", "Mô tả", "Quyền chính trên hệ thống"], [
        ["Quản lý", "Ban giám đốc / quản lý chi nhánh", "Xem toàn bộ dữ liệu, danh mục, tài khoản, sao lưu; không được xóa phiếu thu và sửa nhật ký"],
        ["Giáo vụ", "Tư vấn và học vụ", "Học viên, kiểm tra đầu vào, lớp, lịch, ghi danh, xét kết quả; không xem lương, không thu tiền"],
        ["Kế toán", "Tài chính", "Thu học phí, hủy phiếu thu, công nợ, doanh thu, chốt lương; không sửa điểm, không ghi danh"],
        ["Giáo viên", "Giáo viên Việt Nam và bản ngữ", "Chỉ lớp mình dạy: lịch dạy, điểm danh, nhập điểm, xem lương của mình"],
    ], widths_cm=[2.6, 4.4, 9.0], caption="Tác nhân của hệ thống", size=10)

    r.h2("2.4. Sơ đồ use case")
    r.figure(IMG / "diagrams" / "usecase.png", "Sơ đồ use case tổng quát của hệ thống QLTTTA", width_cm=14.5)

    r.h2("2.5. Sơ đồ luồng dữ liệu (DFD)")
    r.p("DFD mức 0 (sơ đồ ngữ cảnh) thể hiện hệ thống như một xử lý duy nhất trao đổi thông tin với các tác nhân "
        "bên ngoài; DFD mức 1 phân rã thành 6 xử lý chính và các kho dữ liệu tương ứng với nhóm bảng trong CSDL.")
    r.figure(IMG / "diagrams" / "dfd_muc0.png", "DFD mức 0 - sơ đồ ngữ cảnh", width_cm=15.5)
    r.figure_landscape(IMG / "diagrams" / "dfd_muc1.png", "DFD mức 1 - các xử lý chính và kho dữ liệu")

    r.h2("2.6. Yêu cầu chức năng")
    r.table(["Nhóm", "Chức năng", "Hiện thực ở CSDL"], [
        ["Học viên", "Thêm, sửa, xóa (khi chưa ghi danh), tìm kiếm theo mã/tên/SĐT, xuất/nhập XML",
         "usp_Student_Add/Update/Delete/Search, usp_Student_ExportXml/ImportXml"],
        ["Kiểm tra đầu vào", "Nhập điểm 4 kỹ năng, đề xuất khóa học", "usp_PlacementTest_Add, trg_PLACEMENT_TEST_Recommend, fn_RecommendCourse"],
        ["Lớp học", "Mở lớp, thêm lịch tuần, sinh buổi học, đổi trạng thái", "usp_Class_Create, usp_ClassSchedule_Add, usp_Class_GenerateSessions"],
        ["Ghi danh", "Ghi danh, chuyển lớp, bảo lưu, nghỉ học", "usp_Enrollment_Create, usp_Enrollment_TransferClass, usp_Enrollment_UpdateStatus"],
        ["Học phí", "Lập/hủy phiếu thu, in biên lai, công nợ", "usp_Receipt_Create/Cancel/Print, vw_OutstandingTuition, trg_RECEIPT_*"],
        ["Học vụ", "Xác nhận buổi dạy, điểm danh, nhập điểm, xét kết quả", "usp_Session_Update, usp_Attendance_Save, usp_Grade_Save, usp_Class_EvaluateResults"],
        ["Lương", "Chốt lương tháng", "usp_Payroll_Finalize (cursor)"],
        ["Báo cáo", "Tổng quan, doanh thu, kết quả lớp, lịch dạy", "usp_Dashboard_Stats, usp_Report_*, fn_MonthlyRevenue, vw_*"],
        ["Hệ thống", "Đăng nhập, đổi mật khẩu, tạo/khóa tài khoản, sao lưu", "Contained user, usp_Account_*, usp_Backup"],
    ], widths_cm=[2.6, 6.4, 7.0], caption="Yêu cầu chức năng và đối tượng CSDL tương ứng", size=10)

    r.h2("2.7. Yêu cầu phi chức năng")
    r.bullets([
        "**Toàn vẹn dữ liệu**: mọi quy tắc nghiệp vụ quan trọng được kiểm tra tại CSDL (CHECK, FK, trigger, thủ tục), "
        "không phụ thuộc ứng dụng; dữ liệu sửa trực tiếp bằng SSMS vẫn bị kiểm soát.",
        "**Bảo mật**: mật khẩu do SQL Server băm và quản lý; nguyên tắc đặc quyền tối thiểu; giáo viên chỉ thấy dữ "
        "liệu lớp mình; thao tác tài chính và điểm số được ghi nhật ký không sửa được.",
        "**Sẵn sàng và phục hồi**: sao lưu Full/Differential/Log, mất dữ liệu tối đa 30 phút.",
        "**Đa nền tảng, dễ triển khai**: ứng dụng chạy trên Windows 10/11 và macOS (Apple Silicon); có file cài "
        "không cần quyền quản trị; CSDL chạy trên SQL Server 2012 trở lên (kể cả Express miễn phí, Docker).",
        "**Tiếng Việt**: lưu NVARCHAR, collation `Vietnamese_CI_AS` để sắp xếp đúng thứ tự chữ có dấu.",
        "**Dễ bảo trì**: Clean Architecture, unit test, CI tự động build và kiểm thử trên cả hai hệ điều hành.",
    ])
