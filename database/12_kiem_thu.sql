/* =====================================================================
   File   : 12_kiem_thu.sql - Kịch bản kiểm thử ràng buộc, nghiệp vụ và phân quyền
   - Mỗi ca kiểm thử chạy trong giao dịch rồi ROLLBACK => không làm thay đổi dữ liệu.
   - Phân quyền được kiểm thử bằng EXECUTE AS USER (giả lập người dùng) ... REVERT.
   - Chạy bằng sa / db_owner sau khi đã nạp 07_seed_data.sql. Kết quả: bảng tổng hợp cuối file.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID('tempdb..#KetQua') IS NOT NULL DROP TABLE #KetQua;
CREATE TABLE #KetQua (
    MaTest   VARCHAR(5)     NOT NULL,
    NoiDung  NVARCHAR(200)  NOT NULL,
    KyVong   NVARCHAR(20)   NOT NULL,   -- 'Từ chối' hoặc 'Thành công'
    ThucTe   NVARCHAR(20)   NULL,
    ThongBao NVARCHAR(400)  NULL
);
GO

/* ---------------- A. RÀNG BUỘC TOÀN VẸN & NGHIỆP VỤ ---------------- */

-- T01: học viên 12 tuổi không có thông tin phụ huynh
BEGIN TRY
    BEGIN TRAN;
    DECLARE @Ma VARCHAR(10);
    EXEC dbo.usp_HocVien_Them @HoTen = N'Nguyễn Nhỏ', @NgaySinh = '20140101', @GioiTinh = N'Nam',
         @SoDienThoai = '0909999001', @MaCN = 'CN01', @MaHV = @Ma OUTPUT;
    ROLLBACK;
    INSERT #KetQua VALUES ('T01', N'Học viên dưới 18 tuổi thiếu thông tin phụ huynh', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T01', N'Học viên dưới 18 tuổi thiếu thông tin phụ huynh', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T02: số điện thoại chứa chữ cái
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO dbo.HOCVIEN (HoTen, NgaySinh, GioiTinh, SoDienThoai, MaCN)
    VALUES (N'Trần Thử', '20000101', N'Nam', '09abc12345', 'CN01');
    ROLLBACK;
    INSERT #KetQua VALUES ('T02', N'Số điện thoại sai định dạng (CHECK miền giá trị)', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T02', N'Số điện thoại sai định dạng (CHECK miền giá trị)', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T03: ghi danh trùng (học viên đã ghi danh lớp này)
BEGIN TRY
    DECLARE @MaGD VARCHAR(10);
    EXEC dbo.usp_GhiDanh @MaHV = 'HV00001', @MaLop = 'LH0003', @MaNV = 'NV0002', @MaGD = @MaGD OUTPUT;
    INSERT #KetQua VALUES ('T03', N'Ghi danh lặp lại cùng một lớp', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T03', N'Ghi danh lặp lại cùng một lớp', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T04: ghi danh khi chưa đạt điều kiện đầu vào (điểm KT 2,63 vào IELTS 6.5)
BEGIN TRY
    DECLARE @MaGD VARCHAR(10);
    EXEC dbo.usp_GhiDanh @MaHV = 'HV00070', @MaLop = 'LH0008', @MaNV = 'NV0002', @MaGD = @MaGD OUTPUT;
    INSERT #KetQua VALUES ('T04', N'Chưa đạt khóa tiên quyết / điểm đầu vào', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T04', N'Chưa đạt khóa tiên quyết / điểm đầu vào', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T05: ghi danh vào lớp trùng giờ với lớp học viên đang học (HV00023 học LH0003 T2-T4-T6 18h)
BEGIN TRY
    DECLARE @MaGD VARCHAR(10);
    EXEC dbo.usp_GhiDanh @MaHV = 'HV00023', @MaLop = 'LH0007', @MaNV = 'NV0004', @MaGD = @MaGD OUTPUT;
    INSERT #KetQua VALUES ('T05', N'Học viên học 2 lớp trùng lịch', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T05', N'Học viên học 2 lớp trùng lịch', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T06: thu tiền vượt học phí (GD000001 đã đóng đủ) - trigger thuộc tính dẫn xuất
BEGIN TRY
    BEGIN TRAN;
    DECLARE @MaPT VARCHAR(10);
    EXEC dbo.usp_PhieuThu_Tao @MaGD = 'GD000001', @SoTien = 1000000, @MaNVThu = 'NV0003', @MaPT = @MaPT OUTPUT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T06', N'Thu tiền vượt học phí còn nợ', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T06', N'Thu tiền vượt học phí còn nợ', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T07: xóa phiếu thu (INSTEAD OF DELETE)
BEGIN TRY
    BEGIN TRAN;
    DELETE FROM dbo.PHIEUTHU WHERE MaPT = 'PT000001';
    DECLARE @ConLai INT = (SELECT COUNT(*) FROM dbo.PHIEUTHU WHERE MaPT = 'PT000001');
    ROLLBACK;
    INSERT #KetQua VALUES ('T07', N'Xóa vật lý phiếu thu', N'Từ chối',
                           CASE WHEN @ConLai = 1 THEN N'Từ chối' ELSE N'Thành công' END, NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T07', N'Xóa vật lý phiếu thu', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T08: thêm lịch trùng phòng (LH0010 dùng Q1-102 giống LH0004, cùng thứ 3, 19:00-20:30)
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_LichHoc_Them @MaLop = 'LH0010', @Thu = 3, @GioBatDau = '19:00', @GioKetThuc = '20:30';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T08', N'Hai lớp dùng chung phòng cùng giờ', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T08', N'Hai lớp dùng chung phòng cùng giờ', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T09: đổi phòng của lớp sang phòng thuộc chi nhánh khác (liên quan hệ LOPHOC - PHONGHOC)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.LOPHOC SET MaPhong = 'TD-301' WHERE MaLop = 'LH0010';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T09', N'Phòng học khác chi nhánh với lớp', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T09', N'Phòng học khác chi nhánh với lớp', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T10: nhập điểm 11 (ngoài miền 0-10)
BEGIN TRY
    BEGIN TRAN;
    DECLARE @MaGD VARCHAR(10) = (SELECT TOP 1 MaGD FROM dbo.GHIDANH WHERE MaLop = 'LH0006');
    DECLARE @MaTP INT = (SELECT TOP 1 MaTP FROM dbo.THANHPHANDIEM WHERE MaKH = 'GT-B1');
    EXEC dbo.usp_Diem_Luu @MaGD = @MaGD, @MaTP = @MaTP, @Diem = 11;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T10', N'Điểm ngoài miền giá trị 0-10', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T10', N'Điểm ngoài miền giá trị 0-10', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T11: sửa nhật ký hệ thống (INSTEAD OF UPDATE)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.NHATKYHETHONG SET NguoiThucHien = N'ai_do' WHERE MaNK = 1;
    DECLARE @DaSua INT = (SELECT COUNT(*) FROM dbo.NHATKYHETHONG WHERE MaNK = 1 AND NguoiThucHien = N'ai_do');
    ROLLBACK;
    INSERT #KetQua VALUES ('T11', N'Sửa nội dung nhật ký kiểm toán', N'Từ chối',
                           CASE WHEN @DaSua = 0 THEN N'Từ chối' ELSE N'Thành công' END, NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T11', N'Sửa nội dung nhật ký kiểm toán', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T12: cấp chứng nhận cho học viên Không đạt
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO dbo.CHUNGCHI (MaGD, SoHieu, DiemTongKet, XepLoai)
    SELECT TOP 1 MaGD, 'TEST-0001', 5, N'Trung bình' FROM dbo.GHIDANH WHERE KetQua = N'Không đạt';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T12', N'Cấp chứng nhận cho học viên Không đạt', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T12', N'Cấp chứng nhận cho học viên Không đạt', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T13: đổi ngày của buổi học đã dạy
BEGIN TRY
    BEGIN TRAN;
    UPDATE TOP (1) dbo.BUOIHOC SET NgayHoc = DATEADD(DAY, 1, NgayHoc) WHERE TrangThai = N'Đã dạy';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T13', N'Sửa thời gian buổi học đã dạy', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T13', N'Sửa thời gian buổi học đã dạy', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T14: chuyển học viên sang lớp khác khóa học
BEGIN TRY
    BEGIN TRAN;
    DECLARE @MaGD VARCHAR(10) = (SELECT TOP 1 MaGD FROM dbo.GHIDANH WHERE MaLop = 'LH0004');
    EXEC dbo.usp_GhiDanh_ChuyenLop @MaGD = @MaGD, @MaLopMoi = 'LH0010';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T14', N'Chuyển lớp sang khóa học khác', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T14', N'Chuyển lớp sang khóa học khác', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T15: ghi danh hợp lệ (lớp không yêu cầu đầu vào, có khuyến mãi) rồi hoàn tác
BEGIN TRY
    BEGIN TRAN;
    DECLARE @MaGD VARCHAR(10);
    EXEC dbo.usp_GhiDanh @MaHV = 'HV00071', @MaLop = 'LH0010', @MaKM = 'KM-BAN', @MaNV = 'NV0002', @MaGD = @MaGD OUTPUT;
    DECLARE @Info NVARCHAR(200) = (SELECT N'Mã ' + MaGD + N', phải đóng ' + FORMAT(HocPhiPhaiDong, 'N0') + N' đ'
                                   FROM dbo.GHIDANH WHERE MaGD = @MaGD);
    ROLLBACK;
    INSERT #KetQua VALUES ('T15', N'Ghi danh hợp lệ có khuyến mãi', N'Thành công', N'Thành công', @Info);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T15', N'Ghi danh hợp lệ có khuyến mãi', N'Thành công', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- B. PHÂN QUYỀN (EXECUTE AS USER) ---------------- */

-- P01: giáo viên đọc bảng HOCVIEN
BEGIN TRY
    EXECUTE AS USER = N'gv_john';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.HOCVIEN);
    REVERT;
    INSERT #KetQua VALUES ('P01', N'Giáo viên SELECT bảng HOCVIEN', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P01', N'Giáo viên SELECT bảng HOCVIEN', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P02: giáo viên đọc view lớp của mình (ownership chaining + lọc theo USER_NAME())
BEGIN TRY
    EXECUTE AS USER = N'gv_john';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.vw_GV_LopCuaToi);
    DECLARE @hv INT = (SELECT COUNT(*) FROM dbo.vw_GV_HocVienCuaToi);
    REVERT;
    INSERT #KetQua VALUES ('P02', N'Giáo viên SELECT view lớp/học viên của mình', N'Thành công', N'Thành công',
                           CAST(@n AS NVARCHAR(10)) + N' lớp, ' + CAST(@hv AS NVARCHAR(10)) + N' học viên (chỉ lớp của GV0001)');
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P02', N'Giáo viên SELECT view lớp/học viên của mình', N'Thành công', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P03: giáo viên nhập điểm cho lớp không phụ trách
BEGIN TRY
    DECLARE @MaGD VARCHAR(10) = (SELECT TOP 1 MaGD FROM dbo.GHIDANH WHERE MaLop = 'LH0004');
    DECLARE @MaTP INT = (SELECT TOP 1 MaTP FROM dbo.THANHPHANDIEM WHERE MaKH = 'TO-450');
    EXECUTE AS USER = N'gv_john';
    EXEC dbo.usp_Diem_Luu @MaGD = @MaGD, @MaTP = @MaTP, @Diem = 9;
    REVERT;
    INSERT #KetQua VALUES ('P03', N'Giáo viên nhập điểm lớp của giáo viên khác', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P03', N'Giáo viên nhập điểm lớp của giáo viên khác', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P04: kế toán ghi danh học viên (DENY EXECUTE)
BEGIN TRY
    DECLARE @MaGD VARCHAR(10);
    EXECUTE AS USER = N'kt_minh';
    EXEC dbo.usp_GhiDanh @MaHV = 'HV00071', @MaLop = 'LH0010', @MaGD = @MaGD OUTPUT;
    REVERT;
    INSERT #KetQua VALUES ('P04', N'Kế toán thực hiện ghi danh', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P04', N'Kế toán thực hiện ghi danh', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P05: kế toán xem đơn giá giờ của giáo viên (GRANT mức cột)
BEGIN TRY
    EXECUTE AS USER = N'kt_minh';
    DECLARE @dg DECIMAL(12,0) = (SELECT TOP 1 DonGiaGio FROM dbo.GIAOVIEN ORDER BY MaGV);
    REVERT;
    INSERT #KetQua VALUES ('P05', N'Kế toán SELECT cột GIAOVIEN.DonGiaGio', N'Thành công', N'Thành công',
                           N'Đọc được đơn giá ' + FORMAT(@dg, 'N0'));
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P05', N'Kế toán SELECT cột GIAOVIEN.DonGiaGio', N'Thành công', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P06: giáo vụ xem đơn giá giờ của giáo viên (không được GRANT cột này)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    DECLARE @dg DECIMAL(12,0) = (SELECT TOP 1 DonGiaGio FROM dbo.GIAOVIEN ORDER BY MaGV);
    REVERT;
    INSERT #KetQua VALUES ('P06', N'Giáo vụ SELECT cột GIAOVIEN.DonGiaGio', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P06', N'Giáo vụ SELECT cột GIAOVIEN.DonGiaGio', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P07: giáo vụ xem bảng lương (DENY SELECT)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.BANGLUONG);
    REVERT;
    INSERT #KetQua VALUES ('P07', N'Giáo vụ SELECT bảng BANGLUONG', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P07', N'Giáo vụ SELECT bảng BANGLUONG', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P08: quản lý xóa phiếu thu (DENY DELETE - kể cả quản lý)
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    DELETE FROM dbo.PHIEUTHU WHERE MaPT = 'PT000001';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('P08', N'Quản lý DELETE bảng PHIEUTHU', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('P08', N'Quản lý DELETE bảng PHIEUTHU', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P09: giáo vụ tạo tài khoản (không được GRANT EXECUTE)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_TaiKhoan_Tao N'test_user', N'Test@12345', 'GIAOVU', 'NV0006', NULL;
    REVERT;
    INSERT #KetQua VALUES ('P09', N'Giáo vụ tạo tài khoản đăng nhập', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P09', N'Giáo vụ tạo tài khoản đăng nhập', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- P10: quản lý tạo tài khoản mới (EXECUTE AS OWNER) rồi hoàn tác
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_TaiKhoan_Tao N'tuvan_mai', N'TuVan@2026', 'GIAOVU', 'NV0006', NULL;
    REVERT;
    DECLARE @CoUser INT = CASE WHEN DATABASE_PRINCIPAL_ID(N'tuvan_mai') IS NOT NULL THEN 1 ELSE 0 END;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('P10', N'Quản lý tạo tài khoản (user + role)', N'Thành công',
                           CASE WHEN @CoUser = 1 THEN N'Thành công' ELSE N'Từ chối' END,
                           N'Đã tạo contained user tuvan_mai thuộc rl_GiaoVu (đã hoàn tác)');
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('P10', N'Quản lý tạo tài khoản (user + role)', N'Thành công', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- TỔNG HỢP ---------------- */
SELECT MaTest, NoiDung, KyVong, ThucTe,
       CASE WHEN KyVong = ThucTe THEN N'ĐẠT' ELSE N'KHÔNG ĐẠT' END AS DanhGia,
       ThongBao
FROM #KetQua
ORDER BY MaTest;

SELECT COUNT(*) AS TongSoCa, SUM(CASE WHEN KyVong = ThucTe THEN 1 ELSE 0 END) AS SoCaDat FROM #KetQua;
GO
