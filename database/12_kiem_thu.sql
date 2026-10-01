/* =====================================================================
   File   : 12_kiem_thu.sql - Kịch bản kiểm thử ràng buộc, nghiệp vụ và phân quyền
   - Mỗi ca kiểm thử chạy trong giao dịch rồi ROLLBACK => không làm thay đổi dữ liệu.
   - Phân quyền được kiểm thử bằng EXECUTE AS USER (giả lập người dùng) ... REVERT.
   - Chạy bằng sa / db_owner sau khi đã nạp 07_seed_data.sql. Kết quả: bảng tổng hợp cuối file.
   - Ca "Từ chối" chỉ ĐẠT khi bị từ chối ĐÚNG LÝ DO (thông báo khớp mẫu trong #MongDoi), tránh trường hợp
     thủ tục hỏng vì lỗi khác mà ca kiểm thử vẫn "đạt". Ca có trong #MongDoi mà không chạy cũng là KHÔNG ĐẠT.
   - Có ca KHÔNG ĐẠT => file kết thúc bằng THROW 50099 (sqlcmd -b trả mã lỗi 1), dùng được trong
     scripts/test_all.sh để chặn thay đổi làm hỏng nghiệp vụ.
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

-- Đặc tả: danh sách ca phải chạy và mẫu thông báo (LIKE) mà ca "Từ chối" phải trả về.
-- Lỗi hệ thống chỉ so tên đối tượng/ràng buộc (không phụ thuộc ngôn ngữ thông báo của SQL Server).
IF OBJECT_ID('tempdb..#MongDoi') IS NOT NULL DROP TABLE #MongDoi;
CREATE TABLE #MongDoi (MaTest VARCHAR(5) PRIMARY KEY, MauThongBao NVARCHAR(200) NULL);
INSERT #MongDoi VALUES
    ('T01', N'%CK_HOCVIEN_PhuHuynh%'),      ('T02', N'%CK_HOCVIEN_SoDienThoai%'),
    ('T03', N'%đã ghi danh lớp này%'),      ('T04', N'%chưa đạt điều kiện đầu vào%'),
    ('T05', N'%bị trùng%'),                 ('T06', N'%vượt quá học phí%'),
    ('T07', N'%Không được xóa phiếu thu%'), ('T08', N'%Trùng lịch%'),
    ('T09', N'%cùng chi nhánh%'),           ('T10', N'%CK_DIEM_Diem%'),
    ('T11', N'%chỉ được ghi thêm%'),        ('T12', N'%kết quả Đạt%'),
    ('T13', N'%buổi đã dạy%'),              ('T14', N'%cùng khóa học%'),
    ('T15', NULL), ('T16', NULL), ('T17', NULL), ('T18', NULL), ('T19', NULL), ('T20', NULL),
    ('T21', N'%đủ sĩ số%'),                 ('T22', NULL), ('T23', NULL), ('T24', NULL),
    ('T25', N'%tương lai%'),                ('T26', NULL), ('T27', N'%XML%'),
    ('P01', N'%HOCVIEN%'),                  ('P02', NULL),
    ('P03', N'%chỉ được nhập điểm%'),       ('P04', N'%usp_GhiDanh%'),
    ('P05', NULL),                          ('P06', N'%DonGiaGio%'),
    ('P07', N'%BANGLUONG%'),                ('P08', N'%PHIEUTHU%'),
    ('P09', N'%usp_TaiKhoan_Tao%'),         ('P10', NULL), ('P11', NULL),
    ('P12', N'%Mật khẩu hiện tại không đúng%');
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

/* ---------------- C. HÀM, TRIGGER, CURSOR, XML: KIỂM TRA KẾT QUẢ XỬ LÝ ----------------
   Không chỉ kiểm tra "chạy được": kết quả được so với giá trị tính độc lập hoặc kịch bản dựng sẵn. */

-- T16: fn_XepLoai tại các mốc điểm (biên trên/dưới của từng loại)
BEGIN TRY
    DECLARE @Sai16 INT;
    SELECT @Sai16 = COUNT(*)
    FROM (VALUES (CAST(10 AS DECIMAL(4,2)), N'Xuất sắc'), (9, N'Xuất sắc'), (8.99, N'Giỏi'), (8, N'Giỏi'),
                 (7.99, N'Khá'), (6.5, N'Khá'), (6.49, N'Trung bình'), (5, N'Trung bình'),
                 (4.99, N'Không đạt'), (0, N'Không đạt')) AS m(Diem, KyVong)
    WHERE ISNULL(dbo.fn_XepLoai(m.Diem), N'') <> m.KyVong;
    IF dbo.fn_XepLoai(NULL) IS NOT NULL SET @Sai16 += 1;
    INSERT #KetQua VALUES ('T16', N'fn_XepLoai: xếp loại tại các mốc 9 / 8 / 6.5 / 5 điểm', N'Thành công',
                           CASE WHEN @Sai16 = 0 THEN N'Thành công' ELSE N'Sai kết quả' END,
                           CAST(11 - @Sai16 AS NVARCHAR(5)) + N'/11 mốc điểm (kể cả NULL) cho kết quả đúng');
END TRY
BEGIN CATCH
    INSERT #KetQua VALUES ('T16', N'fn_XepLoai: xếp loại tại các mốc 9 / 8 / 6.5 / 5 điểm', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T17: fn_TinhDiemTongKet = SUM(Điểm x Trọng số) / 100; thiếu một cột điểm thì trả NULL
BEGIN TRY
    DECLARE @SoHV17 INT, @Lech17 INT, @MaGD17 VARCHAR(10), @SauXoa17 DECIMAL(4,2);
    SELECT @SoHV17 = COUNT(*), @Lech17 = ISNULL(SUM(CASE WHEN x.TheoHam = x.TinhDocLap THEN 0 ELSE 1 END), 0)
    FROM (SELECT d.MaGD, dbo.fn_TinhDiemTongKet(d.MaGD) AS TheoHam,
                 CAST(ROUND(CAST(SUM(d.Diem * tp.TrongSo) / 100 AS DECIMAL(9,4)), 2) AS DECIMAL(4,2)) AS TinhDocLap
          FROM dbo.DIEM d JOIN dbo.THANHPHANDIEM tp ON tp.MaTP = d.MaTP
          GROUP BY d.MaGD) x
    WHERE x.TheoHam IS NOT NULL;
    SELECT TOP (1) @MaGD17 = MaGD FROM dbo.GHIDANH WHERE dbo.fn_TinhDiemTongKet(MaGD) IS NOT NULL ORDER BY MaGD;

    BEGIN TRAN;
    DELETE TOP (1) FROM dbo.DIEM WHERE MaGD = @MaGD17;
    SET @SauXoa17 = dbo.fn_TinhDiemTongKet(@MaGD17);
    ROLLBACK;

    INSERT #KetQua VALUES ('T17', N'fn_TinhDiemTongKet: điểm theo trọng số, thiếu cột điểm thì NULL', N'Thành công',
        CASE WHEN @SoHV17 > 0 AND @Lech17 = 0 AND @SauXoa17 IS NULL THEN N'Thành công' ELSE N'Sai kết quả' END,
        N'Khớp ' + CAST(@SoHV17 - @Lech17 AS NVARCHAR(10)) + N'/' + CAST(@SoHV17 AS NVARCHAR(10))
        + N' lượt ghi danh; bỏ 1 cột điểm của ' + ISNULL(@MaGD17, N'?') + N' => '
        + ISNULL(CAST(@SauXoa17 AS NVARCHAR(10)), N'NULL'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T17', N'fn_TinhDiemTongKet: điểm theo trọng số, thiếu cột điểm thì NULL', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T18: fn_TyLeChuyenCan: "Có mặt" và "Đi trễ" tính là có mặt; vắng (kể cả có phép) không tính
BEGIN TRY
    DECLARE @GD18 VARCHAR(10), @Lop18 VARCHAR(10), @N18 INT, @TyLe18 DECIMAL(5,2), @KyVong18 DECIMAL(5,2);
    SELECT TOP (1) @GD18 = gd.MaGD, @Lop18 = gd.MaLop
    FROM dbo.GHIDANH gd
    WHERE (SELECT COUNT(*) FROM dbo.BUOIHOC b WHERE b.MaLop = gd.MaLop AND b.TrangThai = N'Đã dạy') >= 5
    ORDER BY gd.MaGD;
    SELECT @N18 = COUNT(*) FROM dbo.BUOIHOC WHERE MaLop = @Lop18 AND TrangThai = N'Đã dạy';

    BEGIN TRAN;
    DELETE FROM dbo.DIEMDANH WHERE MaGD = @GD18;
    -- Dựng kịch bản: 2 buổi có mặt, 1 buổi đi trễ, 1 buổi vắng có phép, còn lại vắng không phép
    INSERT INTO dbo.DIEMDANH (MaBuoi, MaGD, TrangThai)
    SELECT b.MaBuoi, @GD18, CASE WHEN b.ThuTu <= 2 THEN N'Có mặt' WHEN b.ThuTu = 3 THEN N'Đi trễ'
                                 WHEN b.ThuTu = 4 THEN N'Vắng có phép' ELSE N'Vắng không phép' END
    FROM (SELECT MaBuoi, ROW_NUMBER() OVER (ORDER BY NgayHoc, MaBuoi) AS ThuTu
          FROM dbo.BUOIHOC WHERE MaLop = @Lop18 AND TrangThai = N'Đã dạy') b;
    SET @TyLe18 = dbo.fn_TyLeChuyenCan(@GD18);
    ROLLBACK;

    SET @KyVong18 = CAST(100.0 * 3 / @N18 AS DECIMAL(5,2));
    INSERT #KetQua VALUES ('T18', N'fn_TyLeChuyenCan: đi trễ tính có mặt, vắng có phép không tính', N'Thành công',
        CASE WHEN @TyLe18 = @KyVong18 THEN N'Thành công' ELSE N'Sai kết quả' END,
        N'Có mặt 2 + đi trễ 1 trên ' + CAST(@N18 AS NVARCHAR(10)) + N' buổi đã dạy => '
        + ISNULL(CAST(@TyLe18 AS NVARCHAR(10)), N'NULL') + N'% (kỳ vọng ' + CAST(@KyVong18 AS NVARCHAR(10)) + N'%)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T18', N'fn_TyLeChuyenCan: đi trễ tính có mặt, vắng có phép không tính', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T19: fn_TinhSoTienGiam: giảm % làm tròn nghìn đồng, không vượt học phí, hết hạn thì không giảm
BEGIN TRY
    DECLARE @G1 DECIMAL(12,0), @G2 DECIMAL(12,0), @G3 DECIMAL(12,0);
    BEGIN TRAN;
    INSERT INTO dbo.KHUYENMAI (MaKM, TenKM, LoaiGiam, GiaTri, NgayBatDau, NgayKetThuc) VALUES
        ('KMTEST1', N'Kiểm thử giảm 15%', 'PHANTRAM', 15, '20260101', '20261231'),
        ('KMTEST2', N'Kiểm thử giảm 5 triệu', 'SOTIEN', 5000000, '20260101', '20261231');
    SET @G1 = dbo.fn_TinhSoTienGiam('KMTEST1', 4250000, '20260615');   -- 637.500 => làm tròn 638.000
    SET @G2 = dbo.fn_TinhSoTienGiam('KMTEST2', 3000000, '20260615');   -- giảm tối đa bằng học phí
    SET @G3 = dbo.fn_TinhSoTienGiam('KMTEST1', 4250000, '20270101');   -- ngoài thời hạn khuyến mãi
    ROLLBACK;
    INSERT #KetQua VALUES ('T19', N'fn_TinhSoTienGiam: làm tròn nghìn, không vượt học phí, hết hạn = 0', N'Thành công',
        CASE WHEN @G1 = 638000 AND @G2 = 3000000 AND @G3 = 0 THEN N'Thành công' ELSE N'Sai kết quả' END,
        N'15% x 4.250.000 = ' + CAST(@G1 AS NVARCHAR(20)) + N'; giảm 5 triệu trên học phí 3 triệu = '
        + CAST(@G2 AS NVARCHAR(20)) + N'; hết hạn = ' + CAST(@G3 AS NVARCHAR(20)));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T19', N'fn_TinhSoTienGiam: làm tròn nghìn, không vượt học phí, hết hạn = 0', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T20: Thu học phí: trigger cập nhật DaDong (thuộc tính dẫn xuất) và ghi nhật ký XML; hủy phiếu thì DaDong giảm lại
BEGIN TRY
    DECLARE @GD20 VARCHAR(10), @Truoc20 DECIMAL(12,0), @SauThu20 DECIMAL(12,0), @SauHuy20 DECIMAL(12,0),
            @PT20 VARCHAR(10), @NhatKy20 INT;
    SELECT TOP (1) @GD20 = MaGD, @Truoc20 = DaDong FROM dbo.GHIDANH
    WHERE TrangThai <> N'Đã nghỉ' AND HocPhiPhaiDong - DaDong >= 100000 ORDER BY MaGD;

    BEGIN TRAN;
    EXEC dbo.usp_PhieuThu_Tao @MaGD = @GD20, @SoTien = 100000, @MaNVThu = 'NV0003', @MaPT = @PT20 OUTPUT;
    SELECT @SauThu20 = DaDong FROM dbo.GHIDANH WHERE MaGD = @GD20;
    SELECT @NhatKy20 = COUNT(*) FROM dbo.NHATKYHETHONG
    WHERE BangDuLieu = N'PHIEUTHU' AND HanhDong = 'INSERT' AND KhoaChinh = @PT20
      AND DuLieuMoi.exist('/PhieuThu[SoTien = 100000]') = 1;
    EXEC dbo.usp_PhieuThu_Huy @MaPT = @PT20, @LyDo = N'Kiểm thử hủy phiếu';
    SELECT @SauHuy20 = DaDong FROM dbo.GHIDANH WHERE MaGD = @GD20;
    ROLLBACK;

    INSERT #KetQua VALUES ('T20', N'Thu tiền rồi hủy phiếu: DaDong tự cập nhật, có nhật ký XML', N'Thành công',
        CASE WHEN @SauThu20 = @Truoc20 + 100000 AND @NhatKy20 = 1 AND @SauHuy20 = @Truoc20
             THEN N'Thành công' ELSE N'Sai kết quả' END,
        @GD20 + N': đã đóng ' + CAST(@Truoc20 AS NVARCHAR(20)) + N' -> ' + CAST(@SauThu20 AS NVARCHAR(20))
        + N' (thu 100.000) -> ' + CAST(@SauHuy20 AS NVARCHAR(20)) + N' (hủy); nhật ký: '
        + CAST(@NhatKy20 AS NVARCHAR(5)) + N' dòng');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T20', N'Thu tiền rồi hủy phiếu: DaDong tự cập nhật, có nhật ký XML', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T21: lớp đã đủ sĩ số tối đa thì không ghi danh thêm, kể cả INSERT trực tiếp không qua thủ tục (trigger)
BEGIN TRY
    DECLARE @Lop21 VARCHAR(10), @HV21 VARCHAR(10);
    SELECT TOP (1) @Lop21 = MaLop FROM dbo.LOPHOC
    WHERE TrangThai = N'Đang tuyển sinh' AND dbo.fn_SiSoHienTai(MaLop) >= 1 ORDER BY MaLop;
    SELECT TOP (1) @HV21 = hv.MaHV FROM dbo.HOCVIEN hv
    WHERE NOT EXISTS (SELECT 1 FROM dbo.GHIDANH gd WHERE gd.MaHV = hv.MaHV AND gd.MaLop = @Lop21)
    ORDER BY hv.MaHV;

    BEGIN TRAN;
    UPDATE dbo.LOPHOC SET SiSoToiDa = dbo.fn_SiSoHienTai(@Lop21) WHERE MaLop = @Lop21;   -- lớp vừa đủ chỗ
    INSERT INTO dbo.GHIDANH (MaHV, MaLop, HocPhiGoc) VALUES (@HV21, @Lop21, 1000000);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T21', N'Ghi danh vào lớp đã đủ sĩ số tối đa', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T21', N'Ghi danh vào lớp đã đủ sĩ số tối đa', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T22: usp_LopHoc_TaoBuoiHoc: sinh đúng số buổi của khóa, đúng thứ/giờ trong lịch tuần, ngày kết thúc = buổi cuối
BEGIN TRY
    DECLARE @Lop22 VARCHAR(10), @SoBuoiKH22 INT, @SoBuoi22 INT, @SaiLich22 INT, @SaiSTT22 INT,
            @KetThucDung22 BIT, @BaoCao22 INT;
    SELECT TOP (1) @Lop22 = l.MaLop, @SoBuoiKH22 = k.SoBuoi
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
    WHERE EXISTS (SELECT 1 FROM dbo.LICHHOC lh WHERE lh.MaLop = l.MaLop)
      AND NOT EXISTS (SELECT 1 FROM dbo.BUOIHOC b WHERE b.MaLop = l.MaLop AND b.TrangThai <> N'Chưa dạy')
    ORDER BY l.MaLop;

    IF OBJECT_ID('tempdb..#KQ22') IS NOT NULL DROP TABLE #KQ22;
    CREATE TABLE #KQ22 (SoBuoiDaTao INT, NgayKetThuc DATE);
    BEGIN TRAN;
    INSERT #KQ22 EXEC dbo.usp_LopHoc_TaoBuoiHoc @MaLop = @Lop22;
    SELECT @BaoCao22 = SoBuoiDaTao FROM #KQ22;
    SELECT @SoBuoi22 = COUNT(*) FROM dbo.BUOIHOC WHERE MaLop = @Lop22;
    SELECT @SaiLich22 = COUNT(*) FROM dbo.BUOIHOC b
    WHERE b.MaLop = @Lop22
      AND NOT EXISTS (SELECT 1 FROM dbo.LICHHOC lh
                      WHERE lh.MaLop = b.MaLop AND lh.Thu = dbo.fn_ThuTrongTuan(b.NgayHoc)
                        AND lh.GioBatDau = b.GioBatDau AND lh.GioKetThuc = b.GioKetThuc);
    SELECT @SaiSTT22 = COUNT(*)
    FROM (SELECT STT, ROW_NUMBER() OVER (ORDER BY NgayHoc) AS ThuTu FROM dbo.BUOIHOC WHERE MaLop = @Lop22) x
    WHERE x.STT <> x.ThuTu;
    SELECT @KetThucDung22 = CASE WHEN l.NgayKetThuc = (SELECT MAX(NgayHoc) FROM dbo.BUOIHOC WHERE MaLop = @Lop22)
                                  AND (SELECT MIN(NgayHoc) FROM dbo.BUOIHOC WHERE MaLop = @Lop22) >= l.NgayKhaiGiang
                                 THEN 1 ELSE 0 END
    FROM dbo.LOPHOC l WHERE l.MaLop = @Lop22;
    ROLLBACK;

    INSERT #KetQua VALUES ('T22', N'usp_LopHoc_TaoBuoiHoc: sinh buổi học theo lịch tuần', N'Thành công',
        CASE WHEN @SoBuoi22 = @SoBuoiKH22 AND @BaoCao22 = @SoBuoiKH22 AND @SaiLich22 = 0 AND @SaiSTT22 = 0
                  AND @KetThucDung22 = 1 THEN N'Thành công' ELSE N'Sai kết quả' END,
        @Lop22 + N': sinh ' + CAST(@SoBuoi22 AS NVARCHAR(10)) + N'/' + CAST(@SoBuoiKH22 AS NVARCHAR(10))
        + N' buổi, ' + CAST(@SaiLich22 AS NVARCHAR(10)) + N' buổi sai thứ/giờ, ngày kết thúc '
        + CASE WHEN @KetThucDung22 = 1 THEN N'đúng' ELSE N'sai' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T22', N'usp_LopHoc_TaoBuoiHoc: sinh buổi học theo lịch tuần', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T23: usp_LopHoc_XetKetQua (cursor): Đạt khi điểm >= 5 VÀ chuyên cần >= 80%; chỉ người Đạt được cấp chứng nhận
BEGIN TRY
    DECLARE @Lop23 VARCHAR(10), @SoHV23 INT, @Sai23 INT, @SaiCC23 INT, @ThieuCC23 INT, @Dat23 INT, @KhongDat23 INT;
    SELECT TOP (1) @Lop23 = l.MaLop FROM dbo.LOPHOC l
    WHERE l.TrangThai IN (N'Đang học', N'Đã kết thúc')
      AND EXISTS (SELECT 1 FROM dbo.GHIDANH gd WHERE gd.MaLop = l.MaLop)
      AND NOT EXISTS (SELECT 1 FROM dbo.GHIDANH gd
                      WHERE gd.MaLop = l.MaLop AND gd.TrangThai IN (N'Đang học', N'Hoàn thành')
                        AND dbo.fn_TinhDiemTongKet(gd.MaGD) IS NULL)
    ORDER BY l.MaLop;

    IF OBJECT_ID('tempdb..#KQ23') IS NOT NULL DROP TABLE #KQ23;
    CREATE TABLE #KQ23 (SoDat INT, SoKhongDat INT);
    BEGIN TRAN;
    -- Xóa kết quả cũ để xét lại từ đầu
    DELETE cc FROM dbo.CHUNGCHI cc JOIN dbo.GHIDANH gd ON gd.MaGD = cc.MaGD WHERE gd.MaLop = @Lop23;
    UPDATE dbo.GHIDANH SET KetQua = NULL, DiemTongKet = NULL WHERE MaLop = @Lop23;
    INSERT #KQ23 EXEC dbo.usp_LopHoc_XetKetQua @MaLop = @Lop23;
    SELECT @Dat23 = SoDat, @KhongDat23 = SoKhongDat FROM #KQ23;

    SELECT @SoHV23 = COUNT(*),
           @Sai23 = SUM(CASE WHEN gd.KetQua = CASE WHEN dbo.fn_TinhDiemTongKet(gd.MaGD) >= 5
                                                        AND ISNULL(dbo.fn_TyLeChuyenCan(gd.MaGD), 100) >= 80
                                                   THEN N'Đạt' ELSE N'Không đạt' END
                             THEN 0 ELSE 1 END),
           -- học viên đủ điểm nhưng chuyên cần dưới 80% phải bị Không đạt
           @ThieuCC23 = SUM(CASE WHEN gd.DiemTongKet >= 5 AND dbo.fn_TyLeChuyenCan(gd.MaGD) < 80
                                      AND gd.KetQua = N'Không đạt' THEN 1 ELSE 0 END)
    FROM dbo.GHIDANH gd WHERE gd.MaLop = @Lop23 AND gd.TrangThai = N'Hoàn thành';
    SELECT @SaiCC23 = COUNT(*)
    FROM dbo.GHIDANH gd LEFT JOIN dbo.CHUNGCHI cc ON cc.MaGD = gd.MaGD
    WHERE gd.MaLop = @Lop23 AND gd.TrangThai = N'Hoàn thành'
      AND ((gd.KetQua = N'Đạt' AND (cc.MaCC IS NULL OR cc.XepLoai <> dbo.fn_XepLoai(gd.DiemTongKet)))
        OR (gd.KetQua = N'Không đạt' AND cc.MaCC IS NOT NULL));
    ROLLBACK;

    INSERT #KetQua VALUES ('T23', N'usp_LopHoc_XetKetQua: xét Đạt theo điểm và chuyên cần, cấp chứng nhận', N'Thành công',
        CASE WHEN @SoHV23 > 0 AND @Sai23 = 0 AND @SaiCC23 = 0 AND @Dat23 + @KhongDat23 = @SoHV23
             THEN N'Thành công' ELSE N'Sai kết quả' END,
        @Lop23 + N': ' + CAST(@Dat23 AS NVARCHAR(10)) + N' Đạt, ' + CAST(@KhongDat23 AS NVARCHAR(10))
        + N' Không đạt (trong đó ' + CAST(@ThieuCC23 AS NVARCHAR(10)) + N' HV đủ điểm nhưng chuyên cần < 80%); '
        + CAST(@SaiCC23 AS NVARCHAR(10)) + N' sai lệch chứng nhận');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T23', N'usp_LopHoc_XetKetQua: xét Đạt theo điểm và chuyên cần, cấp chứng nhận', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T24: usp_BangLuong_Chot (cursor): lương tháng trước khớp với các buổi đã dạy; thưởng 500.000 khi >= 20 buổi
BEGIN TRY
    DECLARE @Ngay24 DATE = DATEADD(MONTH, -1, GETDATE());
    DECLARE @Thang24 TINYINT = MONTH(@Ngay24), @Nam24 SMALLINT = YEAR(@Ngay24), @SoGV24 INT, @Sai24 INT;

    IF OBJECT_ID('tempdb..#KQ24') IS NOT NULL DROP TABLE #KQ24;
    CREATE TABLE #KQ24 (MaGV VARCHAR(10), HoTen NVARCHAR(100), SoBuoi INT, SoGio DECIMAL(6,2), DonGiaGio DECIMAL(12,0),
                        Thuong DECIMAL(12,0), KhauTru DECIMAL(12,0), TongLuong DECIMAL(14,0), TrangThai NVARCHAR(20));
    BEGIN TRAN;
    DELETE FROM dbo.BANGLUONG WHERE Thang = @Thang24 AND Nam = @Nam24;
    INSERT #KQ24 EXEC dbo.usp_BangLuong_Chot @Thang = @Thang24, @Nam = @Nam24;
    SELECT @SoGV24 = COUNT(*) FROM #KQ24;
    SELECT @Sai24 = COUNT(*)
    FROM (SELECT b.MaGV, COUNT(*) AS SoBuoi,
                 CAST(SUM(DATEDIFF(MINUTE, b.GioBatDau, b.GioKetThuc)) / 60.0 AS DECIMAL(6,2)) AS SoGio
          FROM dbo.BUOIHOC b
          WHERE b.TrangThai = N'Đã dạy' AND MONTH(b.NgayHoc) = @Thang24 AND YEAR(b.NgayHoc) = @Nam24
          GROUP BY b.MaGV) t
    JOIN dbo.GIAOVIEN gv ON gv.MaGV = t.MaGV
    FULL OUTER JOIN (SELECT * FROM dbo.BANGLUONG WHERE Thang = @Thang24 AND Nam = @Nam24) bl ON bl.MaGV = t.MaGV
    WHERE bl.MaBL IS NULL OR t.MaGV IS NULL OR bl.SoBuoi <> t.SoBuoi OR bl.SoGio <> t.SoGio
       OR bl.Thuong <> CASE WHEN t.SoBuoi >= 20 THEN 500000 ELSE 0 END
       OR bl.TongLuong <> CAST(t.SoGio * gv.DonGiaGio AS DECIMAL(14,0)) + bl.Thuong - bl.KhauTru;
    ROLLBACK;

    INSERT #KetQua VALUES ('T24', N'usp_BangLuong_Chot: số buổi, số giờ, thưởng, tổng lương', N'Thành công',
        CASE WHEN @SoGV24 > 0 AND @Sai24 = 0 THEN N'Thành công' ELSE N'Sai kết quả' END,
        N'Tháng ' + CAST(@Thang24 AS NVARCHAR(2)) + N'/' + CAST(@Nam24 AS NVARCHAR(4)) + N': '
        + CAST(@SoGV24 AS NVARCHAR(10)) + N' giáo viên, ' + CAST(@Sai24 AS NVARCHAR(10)) + N' dòng lệch so với BUOIHOC');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T24', N'usp_BangLuong_Chot: số buổi, số giờ, thưởng, tổng lương', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T25: chốt lương cho tháng trong tương lai
BEGIN TRY
    DECLARE @Ngay25 DATE = DATEADD(MONTH, 1, GETDATE());
    DECLARE @Thang25 TINYINT = MONTH(@Ngay25), @Nam25 SMALLINT = YEAR(@Ngay25);
    EXEC dbo.usp_BangLuong_Chot @Thang = @Thang25, @Nam = @Nam25;
    INSERT #KetQua VALUES ('T25', N'Chốt lương cho tháng trong tương lai', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T25', N'Chốt lương cho tháng trong tương lai', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

-- T26: XML: xuất học viên (FOR XML PATH) rồi nhập lại (nodes/value); bản ghi trùng số điện thoại bị bỏ qua
BEGIN TRY
    DECLARE @Xml26 XML, @SoNut26 INT, @SoHV26 INT, @DaNhap26 INT, @BoQua26 INT, @CoMoi26 INT, @SdtCu26 VARCHAR(15);
    IF OBJECT_ID('tempdb..#X26') IS NOT NULL DROP TABLE #X26;
    IF OBJECT_ID('tempdb..#N26') IS NOT NULL DROP TABLE #N26;
    CREATE TABLE #X26 (DuLieu XML);
    CREATE TABLE #N26 (SoDongDaNhap INT, SoDongBoQua INT);

    INSERT #X26 EXEC dbo.usp_HocVien_XuatXML;
    SELECT @Xml26 = DuLieu FROM #X26;
    SET @SoNut26 = @Xml26.value('count(/DanhSachHocVien/HocVien)', 'INT');
    SELECT @SoHV26 = COUNT(*) FROM dbo.HOCVIEN;
    SELECT TOP (1) @SdtCu26 = SoDienThoai FROM dbo.HOCVIEN WHERE SoDienThoai IS NOT NULL ORDER BY MaHV;

    SET @Xml26 = N'<DanhSachHocVien>'
        + N'<HocVien><HoTen>Nhập XML Mới</HoTen><NgaySinh>2000-01-01</NgaySinh><GioiTinh>Nam</GioiTinh>'
        + N'<SoDienThoai>0988777666</SoDienThoai></HocVien>'
        + N'<HocVien><HoTen>Nhập XML Trùng</HoTen><NgaySinh>2000-01-01</NgaySinh><GioiTinh>Nữ</GioiTinh>'
        + N'<SoDienThoai>' + @SdtCu26 + N'</SoDienThoai></HocVien></DanhSachHocVien>';
    BEGIN TRAN;
    INSERT #N26 EXEC dbo.usp_HocVien_NhapXML @DuLieu = @Xml26, @MaCN = 'CN01';
    SELECT @DaNhap26 = SoDongDaNhap, @BoQua26 = SoDongBoQua FROM #N26;
    SELECT @CoMoi26 = COUNT(*) FROM dbo.HOCVIEN WHERE SoDienThoai = '0988777666' AND HoTen = N'Nhập XML Mới';
    ROLLBACK;

    INSERT #KetQua VALUES ('T26', N'Xuất/nhập học viên bằng XML, bỏ qua bản ghi trùng', N'Thành công',
        CASE WHEN @SoNut26 = @SoHV26 AND @DaNhap26 = 1 AND @BoQua26 = 1 AND @CoMoi26 = 1
             THEN N'Thành công' ELSE N'Sai kết quả' END,
        N'Xuất ' + CAST(@SoNut26 AS NVARCHAR(10)) + N'/' + CAST(@SoHV26 AS NVARCHAR(10)) + N' học viên; nhập '
        + CAST(@DaNhap26 AS NVARCHAR(10)) + N' dòng, bỏ qua ' + CAST(@BoQua26 AS NVARCHAR(10)) + N' dòng trùng SĐT');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T26', N'Xuất/nhập học viên bằng XML, bỏ qua bản ghi trùng', N'Thành công', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- T27: đề cương khóa học sai cấu trúc XML Schema (typed XML xsc_DeCuongKhoaHoc)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.KHOAHOC SET NoiDungXML = N'<DeCuong><PhanTuKhongCoTrongSchema/></DeCuong>'
    WHERE MaKH = (SELECT MIN(MaKH) FROM dbo.KHOAHOC);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T27', N'Đề cương khóa học sai cấu trúc XML Schema', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T27', N'Đề cương khóa học sai cấu trúc XML Schema', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
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

-- P11: giáo vụ được xem Dashboard nhưng không được xem doanh thu (thủ tục trả NULL)
BEGIN TRY
    IF OBJECT_ID('tempdb..#TongQuan') IS NOT NULL DROP TABLE #TongQuan;
    CREATE TABLE #TongQuan (HocVien INT, LopDangHoc INT, LopTuyenSinh INT, DoanhThu BIGINT, CongNo BIGINT, BuoiHoc INT);
    EXECUTE AS USER = N'gvu_lan';
    INSERT #TongQuan EXEC dbo.usp_ThongKe_TongQuan;
    REVERT;
    INSERT #KetQua SELECT 'P11', N'Giáo vụ xem doanh thu tháng trên Dashboard', N'Từ chối',
                          CASE WHEN DoanhThu IS NULL THEN N'Từ chối' ELSE N'Thành công' END,
                          N'usp_ThongKe_TongQuan trả DoanhThuThangNay = NULL cho vai trò GIAOVU'
                   FROM #TongQuan;
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P11', N'Giáo vụ xem doanh thu tháng trên Dashboard', N'Từ chối', N'Lỗi', ERROR_MESSAGE());
END CATCH;
GO

-- P12: tự đổi mật khẩu nhưng nhập sai mật khẩu hiện tại (ALTER USER ... OLD_PASSWORD)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_TaiKhoan_DoiMatKhau N'sai-mat-khau', N'MatKhauMoi@1';
    REVERT;
    INSERT #KetQua VALUES ('P12', N'Đổi mật khẩu với mật khẩu hiện tại sai', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #KetQua VALUES ('P12', N'Đổi mật khẩu với mật khẩu hiện tại sai', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- TỔNG HỢP ---------------- */
IF OBJECT_ID('tempdb..#TongHop') IS NOT NULL DROP TABLE #TongHop;
SELECT COALESCE(k.MaTest, m.MaTest) AS MaTest,
       ISNULL(k.NoiDung, N'(ca kiểm thử không chạy)') AS NoiDung, k.KyVong, k.ThucTe,
       CASE WHEN k.MaTest IS NOT NULL AND m.MaTest IS NOT NULL AND k.KyVong = k.ThucTe
                 AND (m.MauThongBao IS NULL OR k.ThongBao LIKE m.MauThongBao)
            THEN N'ĐẠT' ELSE N'KHÔNG ĐẠT' END AS DanhGia,
       k.ThongBao
INTO #TongHop
FROM #KetQua k
FULL OUTER JOIN #MongDoi m ON m.MaTest = k.MaTest;

SELECT MaTest, NoiDung, KyVong, ThucTe, DanhGia, ThongBao FROM #TongHop ORDER BY MaTest;
SELECT COUNT(*) AS TongSoCa, SUM(CASE WHEN DanhGia = N'ĐẠT' THEN 1 ELSE 0 END) AS SoCaDat FROM #TongHop;

IF EXISTS (SELECT 1 FROM #TongHop WHERE DanhGia <> N'ĐẠT')
    THROW 50099, N'Có ca kiểm thử CSDL KHÔNG ĐẠT (xem bảng tổng hợp ở trên).', 1;
GO
