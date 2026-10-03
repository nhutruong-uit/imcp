"""Chapter 4 - Implementing and processing information in the database."""
from content.common import RESULT_LABELS_VI, SQL, object_counts, query_results, database_tests, schema
from report_lib import sql_block, sql_object


def _query_table(r, key, caption, widths=None, size=9.5, max_rows=12, money_cols=()):
    data = query_results()[key]
    rows = []
    for row in data["rows"][:max_rows]:
        cells = []
        for i, v in enumerate(row):
            if i in money_cols and v not in ("", "NULL"):
                try:
                    cells.append(f"{float(v):,.0f}".replace(",", "."))
                    continue
                except ValueError:
                    pass
            cells.append("" if v == "NULL" else v)
        rows.append(cells)
    r.table(data["columns"], rows, widths_cm=widths, caption=caption, size=size)


def chapter4(r):
    r.h1("CHƯƠNG 4: CÀI ĐẶT VÀ XỬ LÝ THÔNG TIN TRÊN CSDL")

    # ------------------------------------------------------------------ 4.1
    r.h2("4.1. Cài đặt cơ sở dữ liệu")
    r.p("CSDL được cài đặt bằng các script T-SQL đánh số, chạy tuần tự bằng SSMS hoặc tự động bằng "
        "`scripts/db_init.sh` (macOS/Linux, Docker) và `scripts/db_init.ps1` (Windows). Mọi script tương thích SQL "
        "Server 2012 trở lên (không dùng `CREATE OR ALTER`, `STRING_AGG`, `TRIM`, JSON).")
    counts = object_counts()
    r.table(["File", "Nội dung", "Số đối tượng"], [
        ["00_create_database.sql", "Bật contained database authentication, tạo CSDL CONTAINMENT = PARTIAL, collation Vietnamese_CI_AS, RECOVERY FULL", "1 CSDL"],
        ["01_tables.sql", "SEQUENCE, XML Schema Collection, bảng, khóa, CHECK, UNIQUE, DEFAULT, chỉ mục", f"{counts['TableCount']} bảng, {counts['SequenceCount']} sequence, {counts['ConstraintCount']} ràng buộc"],
        ["02_functions.sql", "Hàm scalar, inline TVF, multi-statement TVF", f"{counts['FunctionCount']} hàm"],
        ["03_views.sql", "View tổng hợp và view bảo mật cho giáo viên", f"{counts['ViewCount']} view"],
        ["04_procedures.sql", "Thủ tục nghiệp vụ, báo cáo, XML, tài khoản, sao lưu", f"{counts['ProcedureCount']} thủ tục"],
        ["05_triggers.sql", "Trigger ràng buộc và nhật ký kiểm toán", f"{counts['TriggerCount']} trigger"],
        ["06_security.sql", "Role, GRANT/DENY (mức đối tượng, mức cột)", f"{counts['RoleCount']} role"],
        ["07_seed_data.sql", "Dữ liệu mẫu nạp qua thủ tục, ngày tháng tương đối theo ngày chạy", "≈ 2.400 dòng"],
        ["08 - 12_*.sql", "Truy vấn minh họa, backup/restore, import/export, CSDL phân tán, kiểm thử", "-"],
    ], widths_cm=[3.8, 9.0, 3.2], caption="Cấu trúc các script cài đặt CSDL", size=9.5)
    r.code("Tạo CSDL độc lập (contained database) với collation tiếng Việt - 00_create_database.sql",
           sql_block(SQL, "00_create_database.sql", "EXEC sp_configure", "-- 5."))
    r.p("Mã nghiệp vụ dễ đọc (ST00001, CL0001, EN000001) được sinh bằng **SEQUENCE** đặt trong ràng buộc DEFAULT - "
        "an toàn khi nhiều người thêm dữ liệu đồng thời, khác với cách tự tính MAX()+1 dễ bị trùng:")
    r.code("Sinh mã học viên bằng SEQUENCE trong DEFAULT - 01_tables.sql",
           "CREATE SEQUENCE dbo.seq_STUDENT AS INT START WITH 1 INCREMENT BY 1;\n...\nStudentId VARCHAR(10) NOT NULL CONSTRAINT DF_STUDENT_StudentId\n"
           "    DEFAULT ('ST' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_STUDENT AS VARCHAR(10)), 5)),")
    _query_table(r, "row_counts", "Số dòng dữ liệu mẫu trong từng bảng (sau khi chạy 07_seed_data.sql)", widths=[6, 4], size=9.5,
        max_rows=21)

    # ------------------------------------------------------------------ 4.2
    r.h2("4.2. Truy vấn SQL")
    r.p("File `08_demo_queries.sql` gồm 10 truy vấn minh họa các kỹ thuật SQL của Chương 3 (môn học). Một số truy vấn tiêu biểu:")
    r.h3("4.2.1. Gom nhóm có điều kiện (GROUP BY ... HAVING)")
    r.code("Q2 - Chương trình có doanh thu trên 50 triệu", sql_block(SQL, "08_demo_queries.sql", "SELECT pg.ProgramName, COUNT(DISTINCT", "-- Q3."))
    _query_table(r, "revenue_by_program", "Kết quả Q2", widths=[6, 4, 6], money_cols=(2,))
    r.h3("4.2.2. Phép chia quan hệ bằng NOT EXISTS lồng nhau")
    r.p("Tìm học viên đã học **tất cả** khóa IELTS đang có lớp hoạt động: không tồn tại khóa IELTS nào mà học viên chưa ghi danh.")
    r.code("Q4 - Phép chia", sql_block(SQL, "08_demo_queries.sql", "SELECT st.StudentId, st.FullName\nFROM dbo.STUDENT st\nWHERE NOT EXISTS", "-- Q5."))
    r.h3("4.2.3. Hàm cửa sổ và CTE: xếp hạng trong từng lớp")
    r.code("Q5 - Top 3 học viên điểm cao nhất mỗi lớp đã kết thúc", sql_block(SQL, "08_demo_queries.sql", "WITH Ranking AS", "-- Q6."))
    _query_table(r, "top3_per_class", "Kết quả Q5", widths=[3, 2, 7, 4])
    r.h3("4.2.4. Truy vấn đệ quy (recursive CTE) trên mối kết hợp tiên quyết")
    r.code("Q8 - Lộ trình khóa học từ IELTS 6.5 về khóa gốc", sql_block(SQL, "08_demo_queries.sql", "WITH Path AS", "-- Q9."))
    _query_table(r, "prerequisite_path", "Kết quả Q8", widths=[3, 4, 9])
    r.h3("4.2.5. Xoay bảng (PIVOT)")
    r.code("Q7 - Số lượt ghi danh theo chương trình × chi nhánh", sql_block(SQL, "08_demo_queries.sql", "SELECT ProgramName, ISNULL([BR01]", "-- Q8."))
    _query_table(r, "enrollments_pivot", "Kết quả Q7", widths=[7, 4.5, 4.5])

    # ------------------------------------------------------------------ 4.3
    r.h2("4.3. Truy vấn XPath / XQuery trên dữ liệu XML")
    r.p("SQL Server cung cấp các phương thức trên kiểu XML: `.value()` lấy một giá trị vô hướng, `.query()` trả về "
        "đoạn XML, `.exist()` kiểm tra điều kiện, `.nodes()` tách phần tử lặp thành các dòng quan hệ, `.modify()` sửa XML "
        "(XML DML); biến SQL được đưa vào biểu thức XQuery bằng `sql:variable()`.")
    r.code("X3 - .exist(): giáo viên có IELTS từ 8.0", sql_block(SQL, "08_demo_queries.sql", "SELECT TeacherId, FullName,\n       ProfileXml.value", "-- X4."))
    _query_table(r, "ielts_teachers", "Kết quả X3", widths=[3, 8, 5])
    r.code("X4 - .nodes() + CROSS APPLY: tách mọi chứng chỉ thành bảng quan hệ", sql_block(SQL, "08_demo_queries.sql", "SELECT te.TeacherId, te.FullName,\n       c.value", "-- X5."))
    _query_table(r, "teacher_certificates", "Kết quả X4 (8 dòng đầu)", widths=[2.6, 5, 3.8, 2.2, 2.4])
    r.code("X5 - FLWOR: lọc, sắp xếp và dựng lại XML", sql_block(SQL, "08_demo_queries.sql", "SELECT CourseId,\n       SyllabusXml.query('", "-- X6."))
    r.code("X6 - Kiểm tra nhất quán giữa XML và quan hệ: tổng số buổi các Unit = COURSE.SessionCount",
           sql_block(SQL, "08_demo_queries.sql", "SELECT CourseId, SessionCount,\n       SyllabusXml.value('sum", "-- X7."))
    _query_table(r, "syllabus_consistency", "Kết quả X6 - đề cương khớp số buổi của khóa học", widths=[5, 5, 6])
    r.code("Thủ tục usp_Course_FindBySkill - XQuery với sql:variable", sql_object(SQL, "04_procedures.sql", "usp_Course_FindBySkill"))
    _query_table(r, "courses_by_skill", "Kết quả EXEC usp_Course_FindBySkill N'Speaking'", widths=[2.0, 4.6, 1.2, 5.8, 2.4])
    r.code("X7 - .modify(): thêm chứng chỉ vào hồ sơ giáo viên (XML DML)", sql_block(SQL, "08_demo_queries.sql", "BEGIN TRANSACTION;\nUPDATE dbo.TEACHER", "-- X8."))

    # ------------------------------------------------------------------ 4.4
    r.h2("4.4. Stored procedure")
    r.p(f"Toàn bộ thao tác ghi dữ liệu của ứng dụng đi qua **{object_counts()['ProcedureCount']} thủ tục** (tiền tố `usp_`; không dùng `sp_` vì SQL "
        "Server luôn tìm thủ tục `sp_` trong CSDL master trước). Cách làm này tập trung quy tắc nghiệp vụ tại CSDL, "
        "phân quyền bằng `GRANT EXECUTE` thay vì cấp quyền trên bảng, và giảm lưu lượng mạng.")
    r.table(["Nhóm", "Thủ tục", "Kỹ thuật nổi bật"], [
        ["Học viên", "usp_Student_Add, _Update, _Delete, _Search, _Details", "Tham số OUTPUT, OUTPUT INTO lấy mã mới, THROW lỗi nghiệp vụ"],
        ["Lớp học", "usp_Class_Create, usp_ClassSchedule_Add, usp_Class_GenerateSessions, usp_Class_UpdateStatus, usp_Session_Update", "Vòng lặp WHILE sinh buổi học, giao dịch"],
        ["Ghi danh", "usp_Enrollment_Create, _TransferClass, _UpdateStatus, _ByClass", "Giao dịch nhiều bước, kiểm tra điều kiện đầu vào và trùng lịch"],
        ["Học phí", "usp_Receipt_Create, _Cancel, _Print", "Kết hợp trigger dẫn xuất, hủy mềm (soft delete)"],
        ["Học vụ", "usp_PlacementTest_Add, usp_Attendance_Save/_BySession, usp_Grade_Save, usp_Class_EvaluateResults", "Kiểm tra quyền theo người đăng nhập, CURSOR"],
        ["Lương", "usp_Payroll_Finalize", "CURSOR trên truy vấn gom nhóm"],
        ["Báo cáo", "usp_Dashboard_Stats, usp_Report_Revenue, usp_Report_ClassResults", "Truy vấn con vô hướng, gom nhóm"],
        ["XML", "usp_Course_FindBySkill, usp_Course_Syllabus, usp_Teacher_FindByCertificate, usp_Student_ExportXml/_ImportXml", "XQuery, FOR XML PATH, .nodes()"],
        ["Bảo mật", "usp_Account_Create, _Lock, _ResetPassword, _ChangePassword, _RecordLogin, _List, usp_Backup", "Dynamic SQL an toàn, EXECUTE AS OWNER, BACKUP"],
    ], widths_cm=[2.4, 7.4, 6.2], caption="Danh mục thủ tục theo nhóm chức năng", size=9.5)
    r.h3("4.4.1. usp_Enrollment_Create - giao dịch ghi danh nhiều bước")
    r.p("Thủ tục kiểm tra lần lượt: học viên còn học, lớp tồn tại và đang nhận ghi danh, chưa ghi danh trùng, **đạt "
        "điều kiện đầu vào** (đã Đạt khóa tiên quyết HOẶC điểm kiểm tra gần nhất ≥ yêu cầu), **không trùng lịch** với "
        "lớp khác đang học, khuyến mãi còn hiệu lực; sau đó trong một giao dịch thêm ENROLLMENT và cập nhật trạng thái học "
        "viên. Sĩ số tối đa được trigger kiểm tra lại (phòng trường hợp hai người ghi danh đồng thời).")
    r.code("usp_Enrollment_Create (04_procedures.sql)", sql_object(SQL, "04_procedures.sql", "usp_Enrollment_Create"), size=8.5)
    r.h3("4.4.2. usp_Class_GenerateSessions - sinh lịch buổi học tự động")
    r.code("usp_Class_GenerateSessions (04_procedures.sql)", sql_object(SQL, "04_procedures.sql", "usp_Class_GenerateSessions"), size=8.5)
    r.p("Hàm `fn_Weekday` tính thứ theo chuẩn ISO 8601 (1 = thứ Hai ... 7 = Chủ nhật) dựa trên mốc 01/01/1900 là thứ Hai, "
        "nên kết quả **không phụ thuộc** thiết lập `SET DATEFIRST` của máy chủ - điểm thường gây lỗi khi chuyển CSDL "
        "giữa máy cài tiếng Anh và tiếng Việt.")

    # ------------------------------------------------------------------ 4.5
    r.h2("4.5. Function")
    r.table(["Hàm", "Loại", "Mục đích"], [
        ["fn_CenterUtcOffset, fn_UtcToCenterTime, fn_CenterTimeToUtc", "Scalar, SCHEMABINDING",
         "Múi giờ của trung tâm (UTC+07:00): đổi giữa giờ UTC và giờ trung tâm"],
        ["fn_Today", "Scalar", "Ngày hôm nay theo giờ trung tâm, không phụ thuộc múi giờ của máy chủ"],
        ["fn_Weekday", "Scalar, SCHEMABINDING", "Thứ trong tuần không phụ thuộc DATEFIRST"],
        ["fn_CurrentRole, fn_CurrentTeacherId, fn_CurrentEmployeeId", "Scalar", "Ánh xạ USER đang đăng nhập sang vai trò/hồ sơ"],
        ["fn_EnrolledCount", "Scalar", "Số học viên đang học của lớp"],
        ["fn_FinalGrade", "Scalar", "Σ(Score × Weight)/100, NULL nếu thiếu điểm"],
        ["fn_Classification", "Scalar, SCHEMABINDING", "Excellent / Very good / Good / Average / Failed (xuất sắc ... không đạt)"],
        ["fn_AttendanceRate", "Scalar", "% buổi có mặt trên số buổi đã dạy"],
        ["fn_RecommendCourse", "Scalar", "Khóa học phù hợp với điểm kiểm tra đầu vào"],
        ["fn_DiscountAmount", "Scalar", "Tiền giảm theo khuyến mãi tại một ngày"],
        ["fn_TeacherSchedule", "Inline table-valued", "Lịch dạy của giáo viên trong khoảng ngày"],
        ["fn_StudentBalance", "Inline table-valued", "Các khoản còn nợ của một học viên"],
        ["fn_MonthlyRevenue", "Multi-statement table-valued", "Doanh thu đủ 12 tháng (tháng không phát sinh = 0)"],
    ], widths_cm=[5.4, 4.0, 6.6], caption="Danh mục hàm", size=9.5)
    r.code("fn_FinalGrade - hàm vô hướng", sql_object(SQL, "02_functions.sql", "fn_FinalGrade"))
    r.code("fn_MonthlyRevenue - hàm trả về bảng nhiều câu lệnh", sql_object(SQL, "02_functions.sql", "fn_MonthlyRevenue"))
    _query_table(r, "monthly_revenue", "Kết quả fn_MonthlyRevenue (tháng 3 - 10 năm hiện tại)", widths=[4, 4, 8], money_cols=(2,))
    r.p("**Inline TVF** (một câu SELECT) được bộ tối ưu mở rộng như view có tham số nên hiệu năng tốt; **multi-statement "
        "TVF** cần khi phải xử lý nhiều bước (ở đây: tạo trước 12 dòng tháng rồi cập nhật số liệu) nhưng bộ tối ưu không "
        "ước lượng được số dòng, nên chỉ dùng cho tập kết quả nhỏ.")
    r.p("**Lưu thời gian theo UTC.** Các cột mốc thời gian (`PaidAtUtc`, `CreatedAtUtc`, `LoggedAtUtc`...) lưu giờ UTC "
        "bằng `GETUTCDATE()`; ứng dụng đổi sang múi giờ của máy người dùng khi hiển thị. Các ngày nghiệp vụ (kiểu `DATE`: "
        "ngày ghi danh, ngày học, kỳ lương) là ngày theo giờ trung tâm (UTC+07:00), lấy bằng `fn_Today()`. Khi lọc hay "
        "gom nhóm doanh thu, nhóm đổi khoảng ngày/tháng của trung tâm sang khoảng UTC bằng `fn_CenterTimeToUtc` (vẫn dùng "
        "được chỉ mục trên `PaidAtUtc`), nên phiếu thu lúc 17:30 UTC ngày 31/01 - tức 00:30 ngày 01/02 giờ Việt Nam - "
        "được tính vào tháng 2 (ca kiểm thử T31). Nhờ đó kết quả không phụ thuộc múi giờ đặt trên máy chủ SQL Server. "
        "Việt Nam không dùng giờ mùa hè nên độ lệch cố định là chính xác; các hàm dùng `TODATETIMEOFFSET`/`SWITCHOFFSET` "
        "(có từ SQL Server 2008) thay cho `AT TIME ZONE` (cần SQL Server 2016).")

    # ------------------------------------------------------------------ 4.6
    r.h2("4.6. Trigger")
    r.table(["Trigger", "Bảng / sự kiện", "Ràng buộc / mục đích"], [
        ["trg_CLASS_CheckRoom", "CLASS / AFTER INS, UPD", "Phòng cùng chi nhánh, sĩ số tối đa ≤ sức chứa"],
        ["trg_CLASS_SCHEDULE_CheckConflict", "CLASS_SCHEDULE / AFTER INS, UPD", "Không trùng phòng, giáo viên"],
        ["trg_ENROLLMENT_CheckCapacity", "ENROLLMENT / AFTER INS, UPD", "Sĩ số ≤ MaxStudents"],
        ["trg_RECEIPT_UpdateAmountPaid", "RECEIPT / AFTER INS, UPD", "Duy trì AmountPaid, chặn thu vượt"],
        ["trg_RECEIPT_PreventDelete", "RECEIPT / INSTEAD OF DELETE", "Chứng từ không được xóa"],
        ["trg_ATTENDANCE_CheckClass", "ATTENDANCE / AFTER INS, UPD", "Học viên thuộc lớp của buổi học"],
        ["trg_GRADE_CheckComponent", "GRADE / AFTER INS, UPD", "Cột điểm thuộc khóa học của lớp"],
        ["trg_GRADE_Audit", "GRADE / AFTER INS, UPD, DEL", "Nhật ký thay đổi điểm (XML cũ/mới)"],
        ["trg_RECEIPT_Audit", "RECEIPT / AFTER INS, UPD", "Nhật ký lập/hủy phiếu thu"],
        ["trg_AUDIT_LOG_ReadOnly", "AUDIT_LOG / INSTEAD OF UPD, DEL", "Nhật ký chỉ ghi thêm"],
        ["trg_PLACEMENT_TEST_Recommend", "PLACEMENT_TEST / AFTER INS, UPD", "Tự đề xuất khóa học"],
        ["trg_CERTIFICATE_CheckResult", "CERTIFICATE / AFTER INS, UPD", "Chỉ cấp cho học viên Đạt"],
        ["trg_CLASS_SESSION_LockTaught", "CLASS_SESSION / AFTER UPD", "Không sửa thời gian/phòng/GV của buổi đã dạy"],
    ], widths_cm=[5.0, 5.0, 6.0], caption="Danh mục trigger", size=9.5)
    r.p("Mọi trigger được viết theo **tập hợp**: bảng ảo `inserted`/`deleted` có thể chứa nhiều dòng (ví dụ nạp dữ "
        "liệu mẫu chèn hàng trăm phiếu thu trong một câu lệnh), nên không dùng biến vô hướng kiểu "
        "`SELECT @x = EnrollmentId FROM inserted` vốn chỉ xử lý được một dòng.")
    r.code("trg_RECEIPT_UpdateAmountPaid - duy trì thuộc tính dẫn xuất", sql_object(SQL, "05_triggers.sql", "trg_RECEIPT_UpdateAmountPaid"))
    r.code("trg_CLASS_SCHEDULE_CheckConflict - ràng buộc liên bộ", sql_object(SQL, "05_triggers.sql", "trg_CLASS_SCHEDULE_CheckConflict"))
    r.code("trg_GRADE_Audit - nhật ký kiểm toán dạng XML", sql_object(SQL, "05_triggers.sql", "trg_GRADE_Audit"))
    r.p("Trigger **INSTEAD OF** thay thế hoàn toàn thao tác gốc (dùng để cấm xóa phiếu thu, cấm sửa nhật ký), còn "
        "**AFTER** chạy sau khi thao tác đã thực hiện trong cùng giao dịch và có thể ROLLBACK nếu vi phạm. Bài giảng "
        "lưu ý tránh lạm dụng ROLLBACK trong trigger; nhóm chỉ dùng cho các ràng buộc không thể khai báo bằng CHECK/FK.")

    # ------------------------------------------------------------------ 4.7
    r.h2("4.7. Cursor")
    r.p("Cursor duyệt từng dòng của một tập kết quả theo trình tự DECLARE → OPEN → FETCH NEXT → "
        "`WHILE @@FETCH_STATUS = 0` → CLOSE → DEALLOCATE. Nhóm dùng cursor `LOCAL FAST_FORWARD` (chỉ đọc, tiến một "
        "chiều - loại nhẹ nhất) ở hai nghiệp vụ có xử lý khác nhau cho từng dòng:")
    r.code("usp_Class_EvaluateResults - xét kết quả cuối khóa bằng cursor", sql_object(SQL, "04_procedures.sql", "usp_Class_EvaluateResults"), size=8.5)
    _query_table(r, "class1_results", "Kết quả xét lớp CL0001 (IELTS Foundation #1) sau khi chạy thủ tục", widths=[2.2, 4.2, 2.2, 2.6, 3.0, 1.8])
    r.p("Hai học viên Không đạt minh họa đúng hai điều kiện: một học viên điểm tổng kết dưới 5, một học viên đủ điểm "
        "nhưng chuyên cần dưới 80%. Học viên Đạt được cấp chứng nhận số hiệu `EC<năm>-<EnrollmentId>` ngay trong vòng lặp.")
    r.code("usp_Payroll_Finalize - chốt lương tháng bằng cursor", sql_object(SQL, "04_procedures.sql", "usp_Payroll_Finalize"), size=8.5)
    _query_table(r, "payroll", "Bảng lương giáo viên (6 dòng đầu)", widths=[1.2, 1.4, 3.4, 2.4, 1.4, 2.2, 1.6, 2.4], size=9, money_cols=(5, 6, 7))
    r.note("**Nhận xét**: hai nghiệp vụ trên có thể viết bằng câu lệnh tập hợp (UPDATE ... FROM, INSERT ... SELECT) "
           "và sẽ nhanh hơn với dữ liệu lớn. Nhóm chọn cursor vì logic mỗi học viên gồm nhiều bước có điều kiện "
           "(cập nhật kết quả, quyết định cấp chứng nhận) và số dòng nhỏ (một lớp ≤ 50 học viên, một tháng ≤ vài chục "
           "giáo viên), đồng thời minh họa đúng nội dung Cursor của Chương 3.")

    # ------------------------------------------------------------------ 4.8
    r.h2("4.8. Giao dịch và xử lý lỗi")
    r.bullets([
        "`SET XACT_ABORT ON`: khi có lỗi thời gian chạy, SQL Server tự hủy toàn bộ giao dịch, tránh trạng thái dở dang.",
        "`BEGIN TRY ... BEGIN TRANSACTION ... COMMIT ... END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH`: "
        "khuôn mẫu chung cho mọi thủ tục nhiều bước (ghi danh, chuyển lớp, sinh buổi học, xét kết quả, chốt lương).",
        "Lỗi nghiệp vụ dùng `THROW 5xxxx, N'English message.', 1` (SQL Server 2012+). Thông báo viết bằng tiếng Anh như "
        "mọi đối tượng CSDL; ứng dụng tra danh mục `DbMessages` (khớp nguyên văn, hoặc theo mẫu có tham số như "
        "`Class %1 is full.`) để hiển thị theo ngôn ngữ giao diện. Lỗi hệ thống (vi phạm CHECK, thiếu quyền, sai mật "
        "khẩu) cũng được ứng dụng dịch sang tiếng Việt.",
        "Trong trigger dùng `RAISERROR ... + ROLLBACK TRANSACTION` theo đúng mẫu bài giảng.",
    ])

    # ------------------------------------------------------------------ 4.9
    r.h2("4.9. Kiểm thử ràng buộc, nghiệp vụ và xử lý")
    cases = [k for k in database_tests() if k[0].startswith("T")]
    passed = len([k for k in cases if k[4] == "PASSED"])
    r.p(f"Script `12_tests.sql` chạy {len(cases)} ca kiểm thử (cùng {len(database_tests()) - len(cases)} ca phân quyền ở mục 5.7), "
        "mỗi ca thực hiện trong giao dịch rồi ROLLBACK nên không làm thay đổi dữ liệu. T01-T15 kiểm tra ràng buộc và "
        "quy tắc nghiệp vụ; T16-T27 kiểm tra **kết quả xử lý** của hàm, trigger, cursor và XML bằng cách so với giá trị "
        "tính độc lập hoặc kịch bản dựng sẵn (ví dụ dựng 2 buổi có mặt + 1 đi trễ + các buổi vắng rồi so tỷ lệ chuyên cần); "
        "T31 kiểm tra cách lưu thời gian theo UTC (phiếu thu lúc 00:30 giờ Việt Nam thuộc ngày và tháng của trung tâm). "
        "T28-T30 và T32 đọc các view hệ thống (catalog) để kiểm tra quy ước lược đồ: đặt tên, ma trận quyền tối thiểu, "
        "`SET NOCOUNT ON` và quy ước thời gian.")
    r.p("Cách chấm được thiết kế để dùng làm **kiểm thử hồi quy**: bảng `#Expected` liệt kê mọi ca phải chạy và mẫu "
        "thông báo của ca “Rejected” (từ chối) - ca chỉ đạt khi bị từ chối **đúng lý do** (một thủ tục hỏng vì lỗi khác không thể "
        "“đạt” nhầm); có ca không đạt hoặc không chạy thì file kết thúc bằng `THROW 50099`, lệnh `scripts/test_all.sh` "
        "dừng lại. Nhóm đã thử cố ý làm sai ngưỡng xếp loại và xóa trigger sĩ số: T16, T21 lập tức báo FAILED. "
        "Thông báo trong cột cuối là **kết quả thực tế** do SQL Server trả về:")
    rows = [[k[0], k[1], RESULT_LABELS_VI.get(k[2], k[2]), RESULT_LABELS_VI.get(k[3], k[3]), k[5]] for k in cases]
    r.table(["Mã", "Ca kiểm thử", "Kỳ vọng", "Thực tế", "Thông báo / kết quả"], rows,
            widths_cm=[1.1, 4.4, 1.8, 1.8, 6.9], caption=f"Kết quả kiểm thử ràng buộc, nghiệp vụ và xử lý ({passed}/{len(cases)} đạt)", size=8.5)
