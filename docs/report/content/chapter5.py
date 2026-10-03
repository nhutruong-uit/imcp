"""Chapter 5 - Data security."""
from content.common import IMG, RESULT_LABELS_VI, SQL, query_results, database_tests
from report_lib import sql_block, sql_object


def chapter5(r):
    r.h1("CHƯƠNG 5: AN NINH DỮ LIỆU")

    # ------------------------------------------------------------------ 5.1
    r.h2("5.1. Xác thực người dùng")
    r.p("SQL Server hỗ trợ hai cơ chế xác thực: **Windows Authentication** (dựa vào tài khoản hệ điều hành/domain) và "
        "**SQL Server Authentication** (tên đăng nhập + mật khẩu do SQL Server quản lý); chế độ **Mixed** cho phép cả "
        "hai. Theo bài giảng, mô hình truyền thống gồm hai cấp: **login** ở cấp máy chủ (`CREATE LOGIN`) và **user** ở "
        "cấp CSDL (`CREATE USER ... FOR LOGIN`).")
    r.p("Đồ án dùng **contained database user** (SQL Server 2012+): user có mật khẩu nằm ngay trong CSDL "
        "(`CREATE USER x WITH PASSWORD = ...`), CSDL được tạo với `CONTAINMENT = PARTIAL`. Ứng dụng đăng nhập bằng "
        "chính tài khoản này, nghĩa là **SQL Server trực tiếp xác thực** người dùng; mật khẩu được DBMS băm và lưu, "
        "bảng ACCOUNT của ứng dụng chỉ giữ vai trò và liên kết hồ sơ, không chứa mật khẩu.")
    r.table(["Tiêu chí", "Login + User (truyền thống)", "Contained user (đồ án chọn)"], [
        ["Nơi lưu thông tin đăng nhập", "CSDL master (cấp máy chủ)", "Trong chính CSDL QLTTTA"],
        ["Backup CSDL sang máy khác", "User bị mồ côi (orphaned), phải ánh xạ lại bằng ALTER USER ... WITH LOGIN", "Restore xong đăng nhập được ngay"],
        ["Quyền cần để tạo tài khoản", "ALTER ANY LOGIN (cấp máy chủ)", "ALTER ANY USER (cấp CSDL)"],
        ["Azure SQL Database", "CREATE LOGIN chỉ chạy trong master", "Hỗ trợ đầy đủ"],
        ["Chuỗi kết nối", "Có thể không chỉ định CSDL", "Bắt buộc chỉ định Database=QLTTTA"],
    ], widths_cm=[4.0, 6.0, 6.0], caption="So sánh login + user và contained user", size=9.5)
    r.code("Tạo contained user và gán role an toàn bằng dynamic SQL - usp_Account_Create",
           sql_object(SQL, "04_procedures.sql", "usp_Account_Create"), size=8.5)
    r.p("Thủ tục kiểm tra tên đăng nhập chỉ gồm `[a-zA-Z0-9_.]`, dùng `QUOTENAME` cho định danh và nhân đôi dấu nháy "
        "trong mật khẩu để **chống SQL injection** trong dynamic SQL. `WITH EXECUTE AS OWNER` cho phép người quản lý chỉ "
        "cần quyền EXECUTE trên thủ tục mà không cần quyền ALTER ANY USER. Khóa tài khoản dùng `DENY CONNECT`, người "
        "dùng tự đổi mật khẩu bằng `ALTER USER ... WITH PASSWORD = ... OLD_PASSWORD = ...` (bắt buộc đúng mật khẩu cũ).")

    # ------------------------------------------------------------------ 5.2
    r.h2("5.2. Phân quyền")
    r.p("Quyền được cấp cho **role** (rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher), không cấp trực tiếp cho user. "
        "Nguyên tắc **đặc quyền tối thiểu**: role nghiệp vụ không có quyền trên bảng gốc, chỉ được `EXECUTE` thủ tục và "
        "`SELECT` view cần thiết. Cơ chế **ownership chaining** của SQL Server làm cho điều này khả thi: khi view/thủ tục "
        "và bảng cùng chủ sở hữu (dbo), SQL Server chỉ kiểm tra quyền trên view/thủ tục mà bỏ qua kiểm tra quyền trên bảng "
        "bên dưới - kể cả khi bảng bị `DENY`.")
    r.figure_landscape(IMG / "diagrams" / "permissions.png", "Mô hình phân quyền: user → role → view/thủ tục → bảng")
    r.table(["Đối tượng", "Quản lý", "Giáo vụ", "Kế toán", "Giáo viên"], [
        ["Bảng gốc (SELECT)", "✔ (db_datareader)", "—", "RECEIPT, PAYROLL", "DENY STUDENT, RECEIPT, PAYROLL"],
        ["TEACHER (mức cột)", "✔ tất cả", "Không có HourlyRate", "TeacherId, FullName, HourlyRate...", "—"],
        ["View học viên, lớp, công nợ", "✔", "✔", "✔", "—"],
        ["View vw_Teacher_My* (lớp của tôi)", "—", "—", "—", "✔ (lọc theo USER_NAME())"],
        ["usp_Student_*, usp_Enrollment_*, usp_Class_*", "✔", "✔", "Chỉ tìm kiếm; DENY usp_Enrollment_Create", "—"],
        ["usp_Receipt_*, usp_Payroll_Finalize", "✔", "DENY usp_Receipt_Create", "✔", "—"],
        ["usp_Attendance_Save, usp_Grade_Save", "✔", "✔", "DENY usp_Grade_Save", "✔ (chỉ lớp mình)"],
        ["usp_Account_Create/_Lock, usp_Backup", "✔", "—", "—", "—"],
        ["INSERT/UPDATE bảng danh mục (thêm DELETE GRADE_COMPONENT)", "✔ (trigger bảo vệ)", "—", "—", "—"],
        ["DELETE RECEIPT; UPDATE/DELETE AUDIT_LOG", "DENY", "—", "—", "—"],
    ], widths_cm=[4.6, 2.4, 2.8, 3.0, 3.2], caption="Ma trận phân quyền theo role", size=9)
    r.code("Trích 06_security.sql - GRANT/DENY cho role giáo viên và phân quyền mức cột",
           sql_block(SQL, "06_security.sql", "/* 6. TEACHER", "/* 7.") + "\n\n-- Column-level permission: academic staff cannot see the hourly rate\n"
           "GRANT SELECT ON dbo.TEACHER (TeacherId, FullName, TeacherType, Nationality, Degree, BranchId, Status)\n"
           "    TO rl_AcademicStaff;")
    r.p("`DENY` được ưu tiên hơn `GRANT` khi một user thuộc nhiều role; `REVOKE` chỉ thu hồi một GRANT/DENY đã cấp (trở "
        "về trạng thái chưa xác định). Vì vậy dữ liệu nhạy cảm như bảng lương được `DENY` tường minh cho giáo vụ, và "
        "ngay cả role Quản lý cũng bị `DENY DELETE` trên RECEIPT để bảo vệ chứng từ tài chính. Quyền ghi trực tiếp lên bảng "
        "duy nhất của role nghiệp vụ là quyền của Quản lý trên các bảng danh mục (chi nhánh, phòng, khóa học, cột điểm...), "
        "dùng để quản lý danh mục trong SSMS vì ứng dụng chưa có màn hình này; những quy tắc mà thao tác đó có thể phá vỡ "
        "được trigger bảo vệ: `trg_ROOM_CheckClasses` (phòng vẫn phù hợp với lớp đang dùng) và `trg_GRADE_COMPONENT_Lock` "
        "(không đổi cột điểm của khóa học đã có lớp được đánh giá).")

    # ------------------------------------------------------------------ 5.3
    r.h2("5.3. View bảo mật")
    r.p("Bài giảng dùng view để bảo đảm an toàn dữ liệu. Đồ án áp dụng view cho cả hai chiều:")
    r.bullets([
        "**Giới hạn dòng**: `vw_Teacher_MyClasses`, `vw_Teacher_MyStudents`, `vw_Teacher_MySchedule`, `vw_Teacher_MyGrades`, "
        "`vw_Teacher_MyPay` lọc theo giáo viên đang đăng nhập (`USER_NAME()` → ACCOUNT → TeacherId).",
        "**Giới hạn cột**: `vw_Teacher_MyStudents` không chứa số điện thoại, email, học phí của học viên.",
    ])
    r.code("vw_Teacher_MyStudents - view lọc theo người đăng nhập", sql_object(SQL, "03_views.sql", "vw_Teacher_MyStudents"))
    r.note("**Lưu ý kỹ thuật**: trong contained database, `USER_NAME()` trả về giá trị theo collation của catalog "
           "(Latin1_General_100_CI_AS_KS_WS_SC), khác collation `Vietnamese_CI_AS` của cột Username, gây lỗi 468 "
           "*collation conflict*. Nhóm khắc phục bằng `Username = USER_NAME() COLLATE DATABASE_DEFAULT`. Dùng "
           "`USER_NAME()` (thay vì `ORIGINAL_LOGIN()`) còn giúp minh họa phân quyền trong SSMS bằng "
           "`EXECUTE AS USER = N'gv_john'`.")

    # ------------------------------------------------------------------ 5.4
    r.h2("5.4. Nhật ký kiểm toán (audit)")
    r.p("Thao tác trên dữ liệu nhạy cảm (điểm số, phiếu thu) được trigger ghi vào AUDIT_LOG: thời điểm, người thực "
        "hiện (`ORIGINAL_LOGIN()` - giữ đúng người thật kể cả khi đang giả lập quyền), bảng, hành động, khóa và **ảnh dữ "
        "liệu cũ/mới dạng XML**. Nhật ký được bảo vệ hai lớp: trigger INSTEAD OF UPDATE, DELETE và `DENY UPDATE, DELETE` "
        "cho cả role Quản lý.")
    log = query_results()["audit_log"]
    r.table(log["columns"], log["rows"], widths_cm=[2.6, 2.4, 2.2, 1.6, 2.0, 5.2],
            caption="Một số dòng nhật ký lập phiếu thu", size=8.5)

    # ------------------------------------------------------------------ 5.5
    r.h2("5.5. Sao lưu và phục hồi")
    r.p("CSDL đặt chế độ phục hồi **FULL** để sao lưu được nhật ký giao dịch. Chiến lược đề xuất cho trung tâm:")
    r.table(["Loại", "Tần suất", "Nội dung", "Lệnh"], [
        ["Full", "Chủ nhật 23:00", "Toàn bộ CSDL", "BACKUP DATABASE ... WITH CHECKSUM"],
        ["Differential", "Mỗi đêm 23:00", "Các extent thay đổi kể từ bản Full gần nhất", "BACKUP DATABASE ... WITH DIFFERENTIAL"],
        ["Log", "30 phút/lần (giờ làm việc)", "Nhật ký giao dịch kể từ bản Log trước", "BACKUP LOG ..."],
    ], widths_cm=[2.4, 3.4, 5.2, 5.0], caption="Chiến lược sao lưu", size=9.5)
    r.p("Với chiến lược này, lượng dữ liệu mất tối đa (RPO) là 30 phút; phục hồi theo chuỗi **Full gần nhất → "
        "Differential gần nhất → các bản Log sau đó**, các bước trung gian dùng `NORECOVERY`, bước cuối dùng `RECOVERY`.")
    r.code("Phục hồi chuỗi Full → Differential → Log sang CSDL mới (09_backup_restore.sql)",
           sql_block(SQL, "09_backup_restore.sql", "RESTORE DATABASE QLTTTA_Restored FROM DISK = @Full", "GO"))
    r.table(["DatabaseName", "PromotionId", "DiscountValue"], [["QLTTTA", "PR-DEMO", "300000.00"], ["QLTTTA_Restored", "PR-DEMO", "300000.00"]],
            widths_cm=[6, 4, 4], caption="Kết quả đối chiếu: bản phục hồi chứa cả dữ liệu phát sinh sau bản Full", size=10)
    r.p("Dòng PR-DEMO được thêm sau bản Full và sửa giá trị trước bản Log; bản phục hồi có giá trị cuối cùng 300.000 "
        "chứng tỏ cả bản Differential và Log đã được áp dụng. Các contained user đi theo CSDL nên đăng nhập được ngay vào "
        "bản phục hồi. Trong ứng dụng, người quản lý sao lưu nhanh bằng thủ tục `usp_Backup` (FULL/DIFF/LOG).")

    # ------------------------------------------------------------------ 5.6
    r.h2("5.6. Nhập / xuất dữ liệu")
    r.table(["Cách", "Chiều", "Hiện thực"], [
        ["FOR XML PATH", "Xuất", "usp_Student_ExportXml: danh sách học viên thành tài liệu XML có gốc Students"],
        ["XML + .nodes()", "Nhập", "usp_Student_ImportXml: tách XML thành dòng, bỏ qua dòng trùng SĐT/email, chạy trong giao dịch"],
        ["BULK INSERT", "Nhập", "File CSV Unicode (UTF-16 LE, DATAFILETYPE = 'widechar') vào bảng tạm rồi kiểm tra"],
        ["bcp / sqlcmd", "Nhập, xuất", "Dòng lệnh: bcp out/in định dạng Unicode, sqlcmd -s\",\" xuất CSV"],
        ["SSMS Import/Export Wizard", "Nhập, xuất", "Excel, CSV, Access ↔ SQL Server (theo bài thực hành)"],
        ["Ứng dụng Qt", "Xuất", "Mọi danh sách xuất được Excel (CSV UTF-8 có BOM) và báo cáo PDF"],
    ], widths_cm=[3.6, 2.0, 10.4], caption="Các phương thức nhập/xuất dữ liệu", size=9.5)
    r.note("**Khó khăn**: SQL Server trên Linux/Docker không hỗ trợ tùy chọn `CODEPAGE = '65001'` của BULK INSERT nên "
           "file CSV UTF-8 bị lỗi font tiếng Việt. Nhóm chuyển sang file **UTF-16 LE** với `DATAFILETYPE = 'widechar'` - "
           "chạy đúng trên cả Windows và Linux, mọi phiên bản SQL Server.")

    # ------------------------------------------------------------------ 5.7
    r.h2("5.7. Kiểm thử phân quyền")
    r.p("Các ca kiểm thử phân quyền trong `12_tests.sql` giả lập từng người dùng bằng `EXECUTE AS USER ... REVERT`. "
        "Thông báo là kết quả thực tế của SQL Server:")
    cases = [k for k in database_tests() if k[0].startswith("P")]
    passed = len([k for k in cases if k[4] == "PASSED"])
    rows = [[k[0], k[1], RESULT_LABELS_VI.get(k[2], k[2]), RESULT_LABELS_VI.get(k[3], k[3]), k[5]] for k in cases]
    r.table(["Mã", "Ca kiểm thử", "Kỳ vọng", "Thực tế", "Thông báo / kết quả"], rows,
            widths_cm=[1.1, 4.4, 1.8, 1.8, 6.9], caption=f"Kết quả kiểm thử phân quyền ({passed}/{len(cases)} đạt)", size=8.5)
