/* =====================================================================
   File   : 02_functions.sql - Hàm (Function)
   Gồm 3 loại hàm của SQL Server:
     - Scalar function           : trả về 1 giá trị
     - Inline table-valued (ITVF): trả về bảng từ 1 câu SELECT
     - Multi-statement TVF       : trả về biến bảng, xử lý nhiều lệnh
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. fn_ThuTrongTuan: Thứ trong tuần theo quy ước Việt Nam (2..7, CN = 8),
      không phụ thuộc thiết lập SET DATEFIRST của server.
      Ngày 01/01/1900 là thứ Hai. */
IF OBJECT_ID(N'dbo.fn_ThuTrongTuan', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_ThuTrongTuan;
GO
CREATE FUNCTION dbo.fn_ThuTrongTuan (@Ngay DATE)
RETURNS TINYINT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CAST(DATEDIFF(DAY, CAST('19000101' AS DATE), @Ngay) % 7 + 2 AS TINYINT);
END;
GO

/* 2. fn_MaGVHienTai / fn_MaNVHienTai / fn_VaiTroHienTai:
      Ánh xạ USER đang làm việc trong CSDL (USER_NAME()) sang hồ sơ trong TAIKHOAN.
      USER_NAME() cũng đổi theo khi giảng viên/nhóm demo bằng EXECUTE AS USER = N'gv_john'. */
IF OBJECT_ID(N'dbo.fn_VaiTroHienTai', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_VaiTroHienTai;
IF OBJECT_ID(N'dbo.fn_MaGVHienTai', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_MaGVHienTai;
IF OBJECT_ID(N'dbo.fn_MaNVHienTai', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_MaNVHienTai;
GO
CREATE FUNCTION dbo.fn_VaiTroHienTai ()
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @VaiTro VARCHAR(20);
    SELECT @VaiTro = VaiTro FROM dbo.TAIKHOAN WHERE TenDangNhap = USER_NAME() COLLATE DATABASE_DEFAULT;
    -- dbo / sysadmin (người cài đặt) được coi như quản lý
    IF @VaiTro IS NULL AND (IS_MEMBER('db_owner') = 1 OR IS_SRVROLEMEMBER('sysadmin') = 1)
        SET @VaiTro = 'QUANLY';
    RETURN @VaiTro;
END;
GO
CREATE FUNCTION dbo.fn_MaGVHienTai ()
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (SELECT MaGV FROM dbo.TAIKHOAN WHERE TenDangNhap = USER_NAME() COLLATE DATABASE_DEFAULT);
END;
GO
CREATE FUNCTION dbo.fn_MaNVHienTai ()
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (SELECT MaNV FROM dbo.TAIKHOAN WHERE TenDangNhap = USER_NAME() COLLATE DATABASE_DEFAULT);
END;
GO

/* 3. fn_SiSoHienTai: Số học viên đang theo học một lớp */
IF OBJECT_ID(N'dbo.fn_SiSoHienTai', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_SiSoHienTai;
GO
CREATE FUNCTION dbo.fn_SiSoHienTai (@MaLop VARCHAR(10))
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*) FROM dbo.GHIDANH
            WHERE MaLop = @MaLop AND TrangThai IN (N'Đang học', N'Hoàn thành'));
END;
GO

/* 4. fn_TinhDiemTongKet: Điểm tổng kết = SUM(Diem * TrongSo) / 100.
      Trả về NULL nếu chưa nhập đủ điểm các thành phần. */
IF OBJECT_ID(N'dbo.fn_TinhDiemTongKet', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_TinhDiemTongKet;
GO
CREATE FUNCTION dbo.fn_TinhDiemTongKet (@MaGD VARCHAR(10))
RETURNS DECIMAL(4,2)
AS
BEGIN
    DECLARE @SoThanhPhan INT, @SoDaNhap INT, @Tong DECIMAL(9,4);

    SELECT @SoThanhPhan = COUNT(*)
    FROM dbo.GHIDANH gd
    JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
    JOIN dbo.THANHPHANDIEM tp ON tp.MaKH = l.MaKH
    WHERE gd.MaGD = @MaGD;

    SELECT @SoDaNhap = COUNT(*), @Tong = SUM(d.Diem * tp.TrongSo) / 100
    FROM dbo.DIEM d
    JOIN dbo.THANHPHANDIEM tp ON tp.MaTP = d.MaTP
    WHERE d.MaGD = @MaGD;

    IF @SoThanhPhan = 0 OR @SoDaNhap < @SoThanhPhan RETURN NULL;
    RETURN CAST(ROUND(@Tong, 2) AS DECIMAL(4,2));
END;
GO

/* 5. fn_XepLoai: Xếp loại theo điểm tổng kết */
IF OBJECT_ID(N'dbo.fn_XepLoai', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_XepLoai;
GO
CREATE FUNCTION dbo.fn_XepLoai (@Diem DECIMAL(4,2))
RETURNS NVARCHAR(20)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @Diem IS NULL THEN NULL
        WHEN @Diem >= 9   THEN N'Xuất sắc'
        WHEN @Diem >= 8   THEN N'Giỏi'
        WHEN @Diem >= 6.5 THEN N'Khá'
        WHEN @Diem >= 5   THEN N'Trung bình'
        ELSE N'Không đạt'
    END;
END;
GO

/* 6. fn_TyLeChuyenCan: % buổi có mặt (kể cả đi trễ) trên số buổi đã dạy */
IF OBJECT_ID(N'dbo.fn_TyLeChuyenCan', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_TyLeChuyenCan;
GO
CREATE FUNCTION dbo.fn_TyLeChuyenCan (@MaGD VARCHAR(10))
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @SoBuoiDaDay INT, @SoBuoiCoMat INT;

    SELECT @SoBuoiDaDay = COUNT(*)
    FROM dbo.BUOIHOC b
    JOIN dbo.GHIDANH gd ON gd.MaLop = b.MaLop
    WHERE gd.MaGD = @MaGD AND b.TrangThai = N'Đã dạy';

    SELECT @SoBuoiCoMat = COUNT(*)
    FROM dbo.DIEMDANH dd
    JOIN dbo.BUOIHOC b ON b.MaBuoi = dd.MaBuoi
    WHERE dd.MaGD = @MaGD AND b.TrangThai = N'Đã dạy'
      AND dd.TrangThai IN (N'Có mặt', N'Đi trễ');

    IF @SoBuoiDaDay = 0 RETURN NULL;
    RETURN CAST(100.0 * @SoBuoiCoMat / @SoBuoiDaDay AS DECIMAL(5,2));
END;
GO

/* 7. fn_DeXuatKhoaHoc: Khóa học phù hợp nhất với điểm kiểm tra đầu vào
      (khóa có điểm đầu vào tối thiểu cao nhất mà học viên đạt được) */
IF OBJECT_ID(N'dbo.fn_DeXuatKhoaHoc', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_DeXuatKhoaHoc;
GO
CREATE FUNCTION dbo.fn_DeXuatKhoaHoc (@DiemTong DECIMAL(4,2), @MaCT VARCHAR(10) = NULL)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (
        SELECT TOP (1) MaKH
        FROM dbo.KHOAHOC
        WHERE TrangThai = N'Đang mở'
          AND ISNULL(DiemDauVaoToiThieu, 0) <= @DiemTong
          AND (@MaCT IS NULL OR MaCT = @MaCT)
        ORDER BY ISNULL(DiemDauVaoToiThieu, 0) DESC, HocPhi ASC);
END;
GO

/* 8. fn_TinhSoTienGiam: Số tiền giảm của khuyến mãi tại một ngày */
IF OBJECT_ID(N'dbo.fn_TinhSoTienGiam', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_TinhSoTienGiam;
GO
CREATE FUNCTION dbo.fn_TinhSoTienGiam (@MaKM VARCHAR(10), @HocPhi DECIMAL(12,0), @Ngay DATE)
RETURNS DECIMAL(12,0)
AS
BEGIN
    DECLARE @Giam DECIMAL(12,0) = 0;
    SELECT @Giam = CASE LoaiGiam
                       WHEN 'PHANTRAM' THEN ROUND(@HocPhi * GiaTri / 100, -3)
                       ELSE GiaTri
                   END
    FROM dbo.KHUYENMAI
    WHERE MaKM = @MaKM AND @Ngay BETWEEN NgayBatDau AND NgayKetThuc;

    IF @Giam > @HocPhi SET @Giam = @HocPhi;
    RETURN ISNULL(@Giam, 0);
END;
GO

/* 9. fn_LichDayGiaoVien (Inline TVF): lịch dạy của giáo viên trong khoảng ngày */
IF OBJECT_ID(N'dbo.fn_LichDayGiaoVien', N'IF') IS NOT NULL DROP FUNCTION dbo.fn_LichDayGiaoVien;
GO
CREATE FUNCTION dbo.fn_LichDayGiaoVien (@MaGV VARCHAR(10), @TuNgay DATE, @DenNgay DATE)
RETURNS TABLE
AS
RETURN (
    SELECT b.MaBuoi, b.NgayHoc, b.GioBatDau, b.GioKetThuc, b.STT,
           l.MaLop, l.TenLop, k.TenKH, p.TenPhong, cn.TenCN, b.TrangThai
    FROM dbo.BUOIHOC b
    JOIN dbo.LOPHOC l    ON l.MaLop = b.MaLop
    JOIN dbo.KHOAHOC k   ON k.MaKH = l.MaKH
    JOIN dbo.PHONGHOC p  ON p.MaPhong = b.MaPhong
    JOIN dbo.CHINHANH cn ON cn.MaCN = p.MaCN
    WHERE b.MaGV = @MaGV AND b.NgayHoc BETWEEN @TuNgay AND @DenNgay
);
GO

/* 10. fn_CongNoHocVien (Inline TVF): các khoản học phí còn nợ của học viên */
IF OBJECT_ID(N'dbo.fn_CongNoHocVien', N'IF') IS NOT NULL DROP FUNCTION dbo.fn_CongNoHocVien;
GO
CREATE FUNCTION dbo.fn_CongNoHocVien (@MaHV VARCHAR(10))
RETURNS TABLE
AS
RETURN (
    SELECT gd.MaGD, l.MaLop, l.TenLop, gd.HocPhiPhaiDong, gd.DaDong,
           gd.HocPhiPhaiDong - gd.DaDong AS ConNo
    FROM dbo.GHIDANH gd
    JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
    WHERE gd.MaHV = @MaHV AND gd.HocPhiPhaiDong > gd.DaDong
      AND gd.TrangThai <> N'Đã nghỉ'
);
GO

/* 11. fn_DoanhThuTheoThang (Multi-statement TVF): doanh thu 12 tháng của năm,
       tháng không phát sinh vẫn hiển thị 0 (dùng cho báo cáo/biểu đồ). */
IF OBJECT_ID(N'dbo.fn_DoanhThuTheoThang', N'TF') IS NOT NULL DROP FUNCTION dbo.fn_DoanhThuTheoThang;
GO
CREATE FUNCTION dbo.fn_DoanhThuTheoThang (@Nam INT, @MaCN VARCHAR(10) = NULL)
RETURNS @KetQua TABLE (
    Thang      TINYINT       PRIMARY KEY,
    SoPhieu    INT           NOT NULL,
    DoanhThu   DECIMAL(14,0) NOT NULL
)
AS
BEGIN
    DECLARE @Thang TINYINT = 1;
    WHILE @Thang <= 12
    BEGIN
        INSERT INTO @KetQua (Thang, SoPhieu, DoanhThu) VALUES (@Thang, 0, 0);
        SET @Thang += 1;
    END;

    UPDATE kq
    SET SoPhieu = t.SoPhieu, DoanhThu = t.DoanhThu
    FROM @KetQua kq
    JOIN (
        SELECT MONTH(pt.NgayThu) AS Thang, COUNT(*) AS SoPhieu, SUM(pt.SoTien) AS DoanhThu
        FROM dbo.PHIEUTHU pt
        JOIN dbo.GHIDANH gd ON gd.MaGD = pt.MaGD
        JOIN dbo.LOPHOC l   ON l.MaLop = gd.MaLop
        WHERE YEAR(pt.NgayThu) = @Nam AND pt.TrangThai = N'Hợp lệ'
          AND (@MaCN IS NULL OR l.MaCN = @MaCN)
        GROUP BY MONTH(pt.NgayThu)
    ) t ON t.Thang = kq.Thang;

    RETURN;
END;
GO
