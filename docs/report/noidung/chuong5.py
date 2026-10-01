"""Chương 5 - An ninh dữ liệu."""
from noidung.chung import IMG, SQL, ket_qua, kiem_thu
from report_lib import sql_block, sql_object


def chuong5(r):
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
        "bảng TAIKHOAN của ứng dụng chỉ giữ vai trò và liên kết hồ sơ, không chứa mật khẩu.")
    r.table(["Tiêu chí", "Login + User (truyền thống)", "Contained user (đồ án chọn)"], [
        ["Nơi lưu thông tin đăng nhập", "CSDL master (cấp máy chủ)", "Trong chính CSDL QLTTTA"],
        ["Backup CSDL sang máy khác", "User bị mồ côi (orphaned), phải ánh xạ lại bằng ALTER USER ... WITH LOGIN", "Restore xong đăng nhập được ngay"],
        ["Quyền cần để tạo tài khoản", "ALTER ANY LOGIN (cấp máy chủ)", "ALTER ANY USER (cấp CSDL)"],
        ["Azure SQL Database", "CREATE LOGIN chỉ chạy trong master", "Hỗ trợ đầy đủ"],
        ["Chuỗi kết nối", "Có thể không chỉ định CSDL", "Bắt buộc chỉ định Database=QLTTTA"],
    ], widths_cm=[4.0, 6.0, 6.0], caption="So sánh login + user và contained user", size=9.5)
    r.code("Tạo contained user và gán role an toàn bằng dynamic SQL - usp_TaiKhoan_Tao",
           sql_object(SQL, "04_procedures.sql", "usp_TaiKhoan_Tao"), size=8.5)
    r.p("Thủ tục kiểm tra tên đăng nhập chỉ gồm `[a-zA-Z0-9_.]`, dùng `QUOTENAME` cho định danh và nhân đôi dấu nháy "
        "trong mật khẩu để **chống SQL injection** trong dynamic SQL. `WITH EXECUTE AS OWNER` cho phép người quản lý chỉ "
        "cần quyền EXECUTE trên thủ tục mà không cần quyền ALTER ANY USER. Khóa tài khoản dùng `DENY CONNECT`, người "
        "dùng tự đổi mật khẩu bằng `ALTER USER ... WITH PASSWORD = ... OLD_PASSWORD = ...` (bắt buộc đúng mật khẩu cũ).")

    # ------------------------------------------------------------------ 5.2
    r.h2("5.2. Phân quyền")
    r.p("Quyền được cấp cho **role** (rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien), không cấp trực tiếp cho user. "
        "Nguyên tắc **đặc quyền tối thiểu**: role nghiệp vụ không có quyền trên bảng gốc, chỉ được `EXECUTE` thủ tục và "
        "`SELECT` view cần thiết. Cơ chế **ownership chaining** của SQL Server làm cho điều này khả thi: khi view/thủ tục "
        "và bảng cùng chủ sở hữu (dbo), SQL Server chỉ kiểm tra quyền trên view/thủ tục mà bỏ qua kiểm tra quyền trên bảng "
        "bên dưới - kể cả khi bảng bị `DENY`.")
    r.figure_landscape(IMG / "diagrams" / "phan_quyen.png", "Mô hình phân quyền: user → role → view/thủ tục → bảng")
    r.table(["Đối tượng", "Quản lý", "Giáo vụ", "Kế toán", "Giáo viên"], [
        ["Bảng gốc (SELECT)", "✔ (db_datareader)", "—", "PHIEUTHU, BANGLUONG", "DENY HOCVIEN, PHIEUTHU, BANGLUONG"],
        ["GIAOVIEN (mức cột)", "✔ tất cả", "Không có DonGiaGio", "MaGV, HoTen, DonGiaGio...", "—"],
        ["View học viên, lớp, công nợ", "✔", "✔", "✔", "—"],
        ["View vw_GV_* (lớp của tôi)", "—", "—", "—", "✔ (lọc theo USER_NAME())"],
        ["usp_HocVien_*, usp_GhiDanh*, usp_LopHoc_*", "✔", "✔", "Chỉ tìm kiếm; DENY usp_GhiDanh", "—"],
        ["usp_PhieuThu_*, usp_BangLuong_Chot", "✔", "DENY usp_PhieuThu_Tao", "✔", "—"],
        ["usp_DiemDanh_Luu, usp_Diem_Luu", "✔", "✔", "DENY usp_Diem_Luu", "✔ (chỉ lớp mình)"],
        ["usp_TaiKhoan_Tao/_Khoa, usp_SaoLuu", "✔", "—", "—", "—"],
        ["DELETE PHIEUTHU; UPDATE/DELETE NHATKYHETHONG", "DENY", "—", "—", "—"],
    ], widths_cm=[4.6, 2.4, 2.8, 3.0, 3.2], caption="Ma trận phân quyền theo role", size=9)
    r.code("Trích 06_security.sql - GRANT/DENY cho role giáo viên và phân quyền mức cột",
           sql_block(SQL, "06_security.sql", "/* 6. GIÁO VIÊN", "/* 7.") + "\n\n-- Phân quyền mức cột: giáo vụ không thấy đơn giá giờ dạy\n"
           "GRANT SELECT ON dbo.GIAOVIEN (MaGV, HoTen, LoaiGV, QuocTich, TrinhDo, MaCN, TrangThai) TO rl_GiaoVu;")
    r.p("`DENY` được ưu tiên hơn `GRANT` khi một user thuộc nhiều role; `REVOKE` chỉ thu hồi một GRANT/DENY đã cấp (trở "
        "về trạng thái chưa xác định). Vì vậy dữ liệu nhạy cảm như bảng lương được `DENY` tường minh cho giáo vụ, và "
        "ngay cả role Quản lý cũng bị `DENY DELETE` trên PHIEUTHU để bảo vệ chứng từ tài chính.")

    # ------------------------------------------------------------------ 5.3
    r.h2("5.3. View bảo mật")
    r.p("Bài giảng dùng view để bảo đảm an toàn dữ liệu. Đồ án áp dụng view cho cả hai chiều:")
    r.bullets([
        "**Giới hạn dòng**: `vw_GV_LopCuaToi`, `vw_GV_HocVienCuaToi`, `vw_GV_LichDayCuaToi`, `vw_GV_DiemLopCuaToi`, "
        "`vw_GV_LuongCuaToi` lọc theo giáo viên đang đăng nhập (`USER_NAME()` → TAIKHOAN → MaGV).",
        "**Giới hạn cột**: `vw_GV_HocVienCuaToi` không chứa số điện thoại, email, học phí của học viên.",
    ])
    r.code("vw_GV_HocVienCuaToi - view lọc theo người đăng nhập", sql_object(SQL, "03_views.sql", "vw_GV_HocVienCuaToi"))
    r.note("**Lưu ý kỹ thuật**: trong contained database, `USER_NAME()` trả về giá trị theo collation của catalog "
           "(Latin1_General_100_CI_AS_KS_WS_SC), khác collation `Vietnamese_CI_AS` của cột TenDangNhap, gây lỗi 468 "
           "*collation conflict*. Nhóm khắc phục bằng `TenDangNhap = USER_NAME() COLLATE DATABASE_DEFAULT`. Dùng "
           "`USER_NAME()` (thay vì `ORIGINAL_LOGIN()`) còn giúp minh họa phân quyền trong SSMS bằng "
           "`EXECUTE AS USER = N'gv_john'`.")

    # ------------------------------------------------------------------ 5.4
    r.h2("5.4. Nhật ký kiểm toán (audit)")
    r.p("Thao tác trên dữ liệu nhạy cảm (điểm số, phiếu thu) được trigger ghi vào NHATKYHETHONG: thời điểm, người thực "
        "hiện (`ORIGINAL_LOGIN()` - giữ đúng người thật kể cả khi đang giả lập quyền), bảng, hành động, khóa và **ảnh dữ "
        "liệu cũ/mới dạng XML**. Nhật ký được bảo vệ hai lớp: trigger INSTEAD OF UPDATE, DELETE và `DENY UPDATE, DELETE` "
        "cho cả role Quản lý.")
    kq = ket_qua()["nhat_ky"]
    r.table(kq["cot"], kq["dong"], widths_cm=[2.6, 2.0, 2.2, 1.8, 2.0, 5.4],
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
           sql_block(SQL, "09_backup_restore.sql", "RESTORE DATABASE QLTTTA_KhoiPhuc FROM DISK = @Full", "GO"))
    r.table(["CSDL", "MaKM", "GiaTri"], [["QLTTTA", "KM-DEMO", "300000.00"], ["QLTTTA_KhoiPhuc", "KM-DEMO", "300000.00"]],
            widths_cm=[6, 4, 4], caption="Kết quả đối chiếu: bản phục hồi chứa cả dữ liệu phát sinh sau bản Full", size=10)
    r.p("Dòng KM-DEMO được thêm sau bản Full và sửa giá trị trước bản Log; bản phục hồi có giá trị cuối cùng 300.000 "
        "chứng tỏ cả bản Differential và Log đã được áp dụng. Các contained user đi theo CSDL nên đăng nhập được ngay vào "
        "bản phục hồi. Trong ứng dụng, người quản lý sao lưu nhanh bằng thủ tục `usp_SaoLuu` (FULL/DIFF/LOG).")

    # ------------------------------------------------------------------ 5.6
    r.h2("5.6. Nhập / xuất dữ liệu")
    r.table(["Cách", "Chiều", "Hiện thực"], [
        ["FOR XML PATH", "Xuất", "usp_HocVien_XuatXML: danh sách học viên thành tài liệu XML có gốc DanhSachHocVien"],
        ["XML + .nodes()", "Nhập", "usp_HocVien_NhapXML: tách XML thành dòng, bỏ qua dòng trùng SĐT/email, chạy trong giao dịch"],
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
    r.p("Các ca kiểm thử phân quyền trong `12_kiem_thu.sql` giả lập từng người dùng bằng `EXECUTE AS USER ... REVERT`. "
        "Thông báo là kết quả thực tế của SQL Server:")
    ca = [k for k in kiem_thu() if k[0].startswith("P")]
    dat = len([k for k in ca if k[2] == k[3]])
    rows = [[k[0], k[1], k[2], k[3], k[5]] for k in ca]
    r.table(["Mã", "Ca kiểm thử", "Kỳ vọng", "Thực tế", "Thông báo / kết quả"], rows,
            widths_cm=[1.1, 4.4, 1.8, 1.8, 6.9], caption=f"Kết quả kiểm thử phân quyền ({dat}/{len(ca)} đạt)", size=8.5)
