/* =====================================================================
   File   : 04_procedures.sql - Thủ tục lưu trữ (Stored Procedure)
   Quy ước:
     - Tiền tố usp_ (user stored procedure). Không dùng sp_ vì SQL Server
       luôn tìm sp_ trong master trước => chậm và dễ trùng thủ tục hệ thống.
     - Ứng dụng KHÔNG ghi trực tiếp vào bảng; mọi nghiệp vụ đi qua thủ tục
       => kiểm tra nghiệp vụ tập trung tại CSDL, phân quyền bằng GRANT EXECUTE.
     - Lỗi nghiệp vụ: THROW 5xxxx (SQL Server 2012+), ứng dụng hiển thị
       nguyên văn thông báo tiếng Việt cho người dùng.
     - Giao dịch: SET XACT_ABORT ON + TRY/CATCH + ROLLBACK.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =====================================================================
   A. HỌC VIÊN
   ===================================================================== */

/* A1. usp_HocVien_Them: thêm học viên, trả mã mới qua tham số OUTPUT */
IF OBJECT_ID(N'dbo.usp_HocVien_Them', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_Them;
GO
CREATE PROCEDURE dbo.usp_HocVien_Them
    @HoTen        NVARCHAR(100),
    @NgaySinh     DATE,
    @GioiTinh     NVARCHAR(5),
    @SoDienThoai  VARCHAR(15)   = NULL,
    @Email        VARCHAR(100)  = NULL,
    @DiaChi       NVARCHAR(200) = NULL,
    @NgheNghiep   NVARCHAR(50)  = NULL,
    @TenPhuHuynh  NVARCHAR(100) = NULL,
    @SDTPhuHuynh  VARCHAR(15)   = NULL,
    @MaCN         VARCHAR(10),
    @GhiChu       NVARCHAR(500) = NULL,
    @NgayDangKy   DATE          = NULL,
    @MaHV         VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(ISNULL(@HoTen, N''))) = N''
        THROW 50001, N'Họ tên học viên không được để trống.', 1;
    IF @SoDienThoai IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE SoDienThoai = @SoDienThoai)
        THROW 50002, N'Số điện thoại đã được dùng cho một học viên khác.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE Email = @Email)
        THROW 50003, N'Email đã được dùng cho một học viên khác.', 1;

    DECLARE @Moi TABLE (MaHV VARCHAR(10));
    INSERT INTO dbo.HOCVIEN (HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, DiaChi, NgheNghiep,
                             TenPhuHuynh, SDTPhuHuynh, MaCN, GhiChu, NgayDangKy)
    OUTPUT inserted.MaHV INTO @Moi
    VALUES (LTRIM(RTRIM(@HoTen)), @NgaySinh, @GioiTinh, NULLIF(@SoDienThoai, ''), NULLIF(@Email, ''), @DiaChi,
            @NgheNghiep, @TenPhuHuynh, NULLIF(@SDTPhuHuynh, ''), @MaCN, @GhiChu,
            ISNULL(@NgayDangKy, CAST(GETDATE() AS DATE)));

    SELECT @MaHV = MaHV FROM @Moi;
END;
GO

/* A2. usp_HocVien_CapNhat */
IF OBJECT_ID(N'dbo.usp_HocVien_CapNhat', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_CapNhat;
GO
CREATE PROCEDURE dbo.usp_HocVien_CapNhat
    @MaHV         VARCHAR(10),
    @HoTen        NVARCHAR(100),
    @NgaySinh     DATE,
    @GioiTinh     NVARCHAR(5),
    @SoDienThoai  VARCHAR(15)   = NULL,
    @Email        VARCHAR(100)  = NULL,
    @DiaChi       NVARCHAR(200) = NULL,
    @NgheNghiep   NVARCHAR(50)  = NULL,
    @TenPhuHuynh  NVARCHAR(100) = NULL,
    @SDTPhuHuynh  VARCHAR(15)   = NULL,
    @MaCN         VARCHAR(10),
    @TrangThai    NVARCHAR(20),
    @GhiChu       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaHV = @MaHV)
        THROW 50004, N'Không tìm thấy học viên.', 1;
    IF @SoDienThoai IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE SoDienThoai = @SoDienThoai AND MaHV <> @MaHV)
        THROW 50002, N'Số điện thoại đã được dùng cho một học viên khác.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE Email = @Email AND MaHV <> @MaHV)
        THROW 50003, N'Email đã được dùng cho một học viên khác.', 1;

    UPDATE dbo.HOCVIEN
    SET HoTen = LTRIM(RTRIM(@HoTen)), NgaySinh = @NgaySinh, GioiTinh = @GioiTinh,
        SoDienThoai = NULLIF(@SoDienThoai, ''), Email = NULLIF(@Email, ''), DiaChi = @DiaChi,
        NgheNghiep = @NgheNghiep, TenPhuHuynh = @TenPhuHuynh, SDTPhuHuynh = NULLIF(@SDTPhuHuynh, ''),
        MaCN = @MaCN, TrangThai = @TrangThai, GhiChu = @GhiChu
    WHERE MaHV = @MaHV;
END;
GO

/* A3. usp_HocVien_Xoa: chỉ xóa được học viên chưa từng ghi danh */
IF OBJECT_ID(N'dbo.usp_HocVien_Xoa', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_Xoa;
GO
CREATE PROCEDURE dbo.usp_HocVien_Xoa
    @MaHV VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.GHIDANH WHERE MaHV = @MaHV)
        THROW 50005, N'Học viên đã có lịch sử ghi danh, không thể xóa. Hãy chuyển trạng thái sang "Ngừng học".', 1;

    DELETE FROM dbo.KIEMTRADAUVAO WHERE MaHV = @MaHV;
    DELETE FROM dbo.HOCVIEN WHERE MaHV = @MaHV;
    IF @@ROWCOUNT = 0
        THROW 50004, N'Không tìm thấy học viên.', 1;
END;
GO

/* A4. usp_HocVien_TimKiem: tìm theo mã, tên, SĐT; lọc theo chi nhánh/trạng thái */
IF OBJECT_ID(N'dbo.usp_HocVien_TimKiem', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_TimKiem;
GO
CREATE PROCEDURE dbo.usp_HocVien_TimKiem
    @TuKhoa     NVARCHAR(100) = NULL,
    @MaCN       VARCHAR(10)   = NULL,
    @TrangThai  NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Mau NVARCHAR(102) = N'%' + LTRIM(RTRIM(ISNULL(@TuKhoa, N''))) + N'%';

    SELECT MaHV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, TenPhuHuynh, SDTPhuHuynh,
           MaCN, TenCN, NgayDangKy, TrangThai, SoLopDangHoc, TongConNo
    FROM dbo.vw_HocVien_TongQuan
    WHERE (MaHV LIKE @Mau OR HoTen LIKE @Mau OR SoDienThoai LIKE @Mau OR SDTPhuHuynh LIKE @Mau)
      AND (@MaCN IS NULL OR MaCN = @MaCN)
      AND (@TrangThai IS NULL OR TrangThai = @TrangThai)
    ORDER BY MaHV DESC;
END;
GO

/* A5. usp_HocVien_ChiTiet: một học viên kèm hồ sơ đầy đủ */
IF OBJECT_ID(N'dbo.usp_HocVien_ChiTiet', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_ChiTiet;
GO
CREATE PROCEDURE dbo.usp_HocVien_ChiTiet
    @MaHV VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaHV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, DiaChi, NgheNghiep,
           TenPhuHuynh, SDTPhuHuynh, MaCN, NgayDangKy, TrangThai, GhiChu
    FROM dbo.HOCVIEN
    WHERE MaHV = @MaHV;
END;
GO

/* =====================================================================
   B. LỚP HỌC - LỊCH HỌC - BUỔI HỌC
   ===================================================================== */

/* B1. usp_LopHoc_Tao: mở lớp mới; học phí mặc định lấy từ khóa học */
IF OBJECT_ID(N'dbo.usp_LopHoc_Tao', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_LopHoc_Tao;
GO
CREATE PROCEDURE dbo.usp_LopHoc_Tao
    @TenLop         NVARCHAR(100),
    @MaKH           VARCHAR(10),
    @MaCN           VARCHAR(10),
    @MaGV           VARCHAR(10),
    @MaPhong        VARCHAR(10),
    @NgayKhaiGiang  DATE,
    @SiSoToiDa      INT           = 20,
    @HocPhi         DECIMAL(12,0) = NULL,
    @MaLop          VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaKH = @MaKH AND TrangThai = N'Đang mở')
        THROW 50010, N'Khóa học không tồn tại hoặc đã ngừng mở.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.GIAOVIEN WHERE MaGV = @MaGV AND TrangThai = N'Đang dạy')
        THROW 50011, N'Giáo viên không tồn tại hoặc không còn giảng dạy.', 1;

    IF @HocPhi IS NULL
        SELECT @HocPhi = HocPhi FROM dbo.KHOAHOC WHERE MaKH = @MaKH;

    DECLARE @Moi TABLE (MaLop VARCHAR(10));
    INSERT INTO dbo.LOPHOC (TenLop, MaKH, MaCN, MaGV, MaPhong, NgayKhaiGiang, SiSoToiDa, HocPhi)
    OUTPUT inserted.MaLop INTO @Moi
    VALUES (@TenLop, @MaKH, @MaCN, @MaGV, @MaPhong, @NgayKhaiGiang, @SiSoToiDa, @HocPhi);

    SELECT @MaLop = MaLop FROM @Moi;
END;
GO

/* B2. usp_LichHoc_Them: thêm một khung giờ học trong tuần cho lớp
       (trigger trg_LICHHOC_KiemTraTrungLich kiểm tra trùng phòng/giáo viên) */
IF OBJECT_ID(N'dbo.usp_LichHoc_Them', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_LichHoc_Them;
GO
CREATE PROCEDURE dbo.usp_LichHoc_Them
    @MaLop       VARCHAR(10),
    @Thu         TINYINT,
    @GioBatDau   TIME(0),
    @GioKetThuc  TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu)
        UPDATE dbo.LICHHOC SET GioBatDau = @GioBatDau, GioKetThuc = @GioKetThuc
        WHERE MaLop = @MaLop AND Thu = @Thu;
    ELSE
        INSERT INTO dbo.LICHHOC (MaLop, Thu, GioBatDau, GioKetThuc)
        VALUES (@MaLop, @Thu, @GioBatDau, @GioKetThuc);
END;
GO

/* B3. usp_LopHoc_TaoBuoiHoc: sinh đủ SoBuoi buổi học từ ngày khai giảng
       theo lịch tuần (vòng lặp WHILE trên từng ngày), cập nhật ngày kết thúc. */
IF OBJECT_ID(N'dbo.usp_LopHoc_TaoBuoiHoc', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_LopHoc_TaoBuoiHoc;
GO
CREATE PROCEDURE dbo.usp_LopHoc_TaoBuoiHoc
    @MaLop VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SoBuoi INT, @Ngay DATE, @MaGV VARCHAR(10), @MaPhong VARCHAR(10),
            @STT INT = 0, @GioBD TIME(0), @GioKT TIME(0), @NgayCuoi DATE;

    SELECT @SoBuoi = k.SoBuoi, @Ngay = l.NgayKhaiGiang, @MaGV = l.MaGV, @MaPhong = l.MaPhong
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
    WHERE l.MaLop = @MaLop;

    IF @SoBuoi IS NULL
        THROW 50012, N'Không tìm thấy lớp học.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop)
        THROW 50013, N'Lớp chưa có lịch học trong tuần.', 1;
    IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop AND TrangThai <> N'Chưa dạy')
        THROW 50014, N'Lớp đã có buổi đã dạy/đã hủy, không thể sinh lại lịch.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.BUOIHOC WHERE MaLop = @MaLop;

        WHILE @STT < @SoBuoi
        BEGIN
            SELECT @GioBD = GioBatDau, @GioKT = GioKetThuc
            FROM dbo.LICHHOC
            WHERE MaLop = @MaLop AND Thu = dbo.fn_ThuTrongTuan(@Ngay);

            IF @@ROWCOUNT = 1
            BEGIN
                SET @STT += 1;
                INSERT INTO dbo.BUOIHOC (MaLop, STT, NgayHoc, GioBatDau, GioKetThuc, MaPhong, MaGV)
                VALUES (@MaLop, @STT, @Ngay, @GioBD, @GioKT, @MaPhong, @MaGV);
                SET @NgayCuoi = @Ngay;
            END;
            SET @Ngay = DATEADD(DAY, 1, @Ngay);
        END;

        UPDATE dbo.LOPHOC SET NgayKetThuc = @NgayCuoi WHERE MaLop = @MaLop;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @STT AS SoBuoiDaTao, @NgayCuoi AS NgayKetThuc;
END;
GO

/* B4. usp_LopHoc_CapNhatTrangThai */
IF OBJECT_ID(N'dbo.usp_LopHoc_CapNhatTrangThai', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_LopHoc_CapNhatTrangThai;
GO
CREATE PROCEDURE dbo.usp_LopHoc_CapNhatTrangThai
    @MaLop      VARCHAR(10),
    @TrangThai  NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @TrangThai = N'Đã hủy' AND EXISTS (SELECT 1 FROM dbo.PHIEUTHU pt JOIN dbo.GHIDANH gd ON gd.MaGD = pt.MaGD
                                          WHERE gd.MaLop = @MaLop AND pt.TrangThai = N'Hợp lệ')
        THROW 50015, N'Lớp đã có học viên đóng học phí, cần hoàn tiền/chuyển lớp trước khi hủy.', 1;

    UPDATE dbo.LOPHOC SET TrangThai = @TrangThai WHERE MaLop = @MaLop;
    IF @@ROWCOUNT = 0
        THROW 50012, N'Không tìm thấy lớp học.', 1;
END;
GO

/* B5. usp_BuoiHoc_CapNhat: giáo viên xác nhận đã dạy / ghi nội dung buổi học */
IF OBJECT_ID(N'dbo.usp_BuoiHoc_CapNhat', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_BuoiHoc_CapNhat;
GO
CREATE PROCEDURE dbo.usp_BuoiHoc_CapNhat
    @MaBuoi     INT,
    @TrangThai  NVARCHAR(20),
    @NoiDung    NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaGVBuoi VARCHAR(10);
    SELECT @MaGVBuoi = MaGV FROM dbo.BUOIHOC WHERE MaBuoi = @MaBuoi;

    IF @MaGVBuoi IS NULL
        THROW 50016, N'Không tìm thấy buổi học.', 1;
    IF dbo.fn_VaiTroHienTai() = 'GIAOVIEN' AND @MaGVBuoi <> dbo.fn_MaGVHienTai()
        THROW 50017, N'Bạn chỉ được cập nhật buổi học do mình phụ trách.', 1;

    UPDATE dbo.BUOIHOC
    SET TrangThai = @TrangThai, NoiDung = ISNULL(@NoiDung, NoiDung)
    WHERE MaBuoi = @MaBuoi;
END;
GO

/* =====================================================================
   C. GHI DANH
   ===================================================================== */

/* C1. usp_GhiDanh: ghi danh học viên vào lớp (giao dịch nhiều bước)
       - Lớp phải đang tuyển sinh/đang học, còn chỗ (trigger kiểm tra lại)
       - Điều kiện đầu vào: đạt khóa tiên quyết HOẶC đủ điểm kiểm tra đầu vào
       - Không trùng lịch với lớp khác học viên đang học
       - Tính tiền giảm theo khuyến mãi */
IF OBJECT_ID(N'dbo.usp_GhiDanh', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GhiDanh;
GO
CREATE PROCEDURE dbo.usp_GhiDanh
    @MaHV         VARCHAR(10),
    @MaLop        VARCHAR(10),
    @MaKM         VARCHAR(10) = NULL,
    @NgayGhiDanh  DATE        = NULL,
    @MaNV         VARCHAR(10) = NULL,
    @MaGD         VARCHAR(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaKH VARCHAR(10), @HocPhi DECIMAL(12,0), @TrangThaiLop NVARCHAR(20),
            @TienQuyet VARCHAR(10), @DiemToiThieu DECIMAL(4,2), @Giam DECIMAL(12,0),
            @BatDau DATE, @KetThuc DATE, @Msg NVARCHAR(2048);

    SET @NgayGhiDanh = ISNULL(@NgayGhiDanh, CAST(GETDATE() AS DATE));
    SET @MaNV = COALESCE(@MaNV, dbo.fn_MaNVHienTai());

    IF NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaHV = @MaHV AND TrangThai <> N'Ngừng học')
        THROW 50020, N'Học viên không tồn tại hoặc đã ngừng học.', 1;

    SELECT @MaKH = l.MaKH, @HocPhi = l.HocPhi, @TrangThaiLop = l.TrangThai,
           @TienQuyet = k.MaKHTienQuyet, @DiemToiThieu = k.DiemDauVaoToiThieu,
           @BatDau = l.NgayKhaiGiang, @KetThuc = ISNULL(l.NgayKetThuc, DATEADD(MONTH, 6, l.NgayKhaiGiang))
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
    WHERE l.MaLop = @MaLop;

    IF @MaKH IS NULL
        THROW 50012, N'Không tìm thấy lớp học.', 1;
    IF @TrangThaiLop NOT IN (N'Đang tuyển sinh', N'Đang học')
        THROW 50021, N'Lớp không còn nhận ghi danh.', 1;
    IF EXISTS (SELECT 1 FROM dbo.GHIDANH WHERE MaHV = @MaHV AND MaLop = @MaLop)
        THROW 50022, N'Học viên đã ghi danh lớp này.', 1;

    -- Điều kiện đầu vào
    IF (@TienQuyet IS NOT NULL OR @DiemToiThieu IS NOT NULL)
       AND NOT EXISTS (   -- đã đạt khóa tiên quyết
            SELECT 1 FROM dbo.GHIDANH gd JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
            WHERE gd.MaHV = @MaHV AND gd.KetQua = N'Đạt' AND l.MaKH = @TienQuyet)
       AND NOT EXISTS (   -- hoặc điểm kiểm tra đầu vào gần nhất đủ chuẩn
            SELECT 1 FROM (SELECT TOP (1) DiemTong FROM dbo.KIEMTRADAUVAO
                           WHERE MaHV = @MaHV ORDER BY NgayKiemTra DESC, MaKT DESC) kt
            WHERE kt.DiemTong >= ISNULL(@DiemToiThieu, 0))
    BEGIN
        SET @Msg = N'Học viên chưa đạt điều kiện đầu vào của khóa ' + @MaKH
                 + N' (cần hoàn thành khóa tiên quyết hoặc điểm kiểm tra đầu vào >= '
                 + ISNULL(CAST(@DiemToiThieu AS NVARCHAR(10)), N'0') + N').';
        THROW 50023, @Msg, 1;
    END;

    -- Không trùng lịch với lớp khác mà học viên đang học
    IF EXISTS (
        SELECT 1
        FROM dbo.GHIDANH gd
        JOIN dbo.LOPHOC l2   ON l2.MaLop = gd.MaLop
        JOIN dbo.LICHHOC lh2 ON lh2.MaLop = l2.MaLop
        JOIN dbo.LICHHOC lh  ON lh.MaLop = @MaLop AND lh.Thu = lh2.Thu
        WHERE gd.MaHV = @MaHV AND gd.TrangThai = N'Đang học'
          AND l2.TrangThai IN (N'Đang tuyển sinh', N'Đang học')
          AND lh.GioBatDau < lh2.GioKetThuc AND lh2.GioBatDau < lh.GioKetThuc
          AND l2.NgayKhaiGiang <= @KetThuc
          AND ISNULL(l2.NgayKetThuc, DATEADD(MONTH, 6, l2.NgayKhaiGiang)) >= @BatDau)
        THROW 50024, N'Lịch học của lớp bị trùng với một lớp khác học viên đang theo học.', 1;

    SET @Giam = CASE WHEN @MaKM IS NULL THEN 0 ELSE dbo.fn_TinhSoTienGiam(@MaKM, @HocPhi, @NgayGhiDanh) END;
    IF @MaKM IS NOT NULL AND @Giam = 0
        THROW 50025, N'Mã khuyến mãi không tồn tại hoặc đã hết hạn.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Moi TABLE (MaGD VARCHAR(10));
        INSERT INTO dbo.GHIDANH (MaHV, MaLop, NgayGhiDanh, HocPhiGoc, MaKM, SoTienGiam, MaNVGhiDanh)
        OUTPUT inserted.MaGD INTO @Moi
        VALUES (@MaHV, @MaLop, @NgayGhiDanh, @HocPhi, @MaKM, @Giam, @MaNV);

        UPDATE dbo.HOCVIEN SET TrangThai = N'Đang học'
        WHERE MaHV = @MaHV AND TrangThai IN (N'Tiềm năng', N'Bảo lưu');

        COMMIT TRANSACTION;
        SELECT @MaGD = MaGD FROM @Moi;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C2. usp_GhiDanh_ChuyenLop: chuyển học viên sang lớp khác CÙNG khóa học,
       giữ nguyên lịch sử đóng tiền (cập nhật MaLop trong cùng giao dịch). */
IF OBJECT_ID(N'dbo.usp_GhiDanh_ChuyenLop', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GhiDanh_ChuyenLop;
GO
CREATE PROCEDURE dbo.usp_GhiDanh_ChuyenLop
    @MaGD      VARCHAR(10),
    @MaLopMoi  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @MaLopCu VARCHAR(10), @MaHV VARCHAR(10);

    SELECT @MaLopCu = MaLop, @MaHV = MaHV FROM dbo.GHIDANH WHERE MaGD = @MaGD AND TrangThai IN (N'Đang học', N'Bảo lưu');
    IF @MaLopCu IS NULL
        THROW 50026, N'Không tìm thấy lượt ghi danh đang hiệu lực.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.LOPHOC a JOIN dbo.LOPHOC b ON a.MaKH = b.MaKH
                   WHERE a.MaLop = @MaLopCu AND b.MaLop = @MaLopMoi
                     AND b.TrangThai IN (N'Đang tuyển sinh', N'Đang học'))
        THROW 50027, N'Chỉ được chuyển sang lớp đang mở của cùng khóa học.', 1;
    IF EXISTS (SELECT 1 FROM dbo.GHIDANH WHERE MaHV = @MaHV AND MaLop = @MaLopMoi)
        THROW 50022, N'Học viên đã ghi danh lớp này.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- Điểm danh ở lớp cũ không còn ý nghĩa với lớp mới
        DELETE dd FROM dbo.DIEMDANH dd JOIN dbo.BUOIHOC b ON b.MaBuoi = dd.MaBuoi
        WHERE dd.MaGD = @MaGD AND b.MaLop = @MaLopCu;

        UPDATE dbo.GHIDANH SET MaLop = @MaLopMoi, TrangThai = N'Đang học' WHERE MaGD = @MaGD;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C3. usp_GhiDanh_CapNhatTrangThai: bảo lưu / nghỉ học / học lại */
IF OBJECT_ID(N'dbo.usp_GhiDanh_CapNhatTrangThai', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GhiDanh_CapNhatTrangThai;
GO
CREATE PROCEDURE dbo.usp_GhiDanh_CapNhatTrangThai
    @MaGD       VARCHAR(10),
    @TrangThai  NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.GHIDANH SET TrangThai = @TrangThai WHERE MaGD = @MaGD;
    IF @@ROWCOUNT = 0
        THROW 50026, N'Không tìm thấy lượt ghi danh.', 1;

    -- Học viên không còn lớp nào đang học => chuyển trạng thái học viên
    UPDATE hv SET TrangThai = CASE @TrangThai WHEN N'Bảo lưu' THEN N'Bảo lưu' ELSE N'Ngừng học' END
    FROM dbo.HOCVIEN hv JOIN dbo.GHIDANH gd ON gd.MaHV = hv.MaHV
    WHERE gd.MaGD = @MaGD AND @TrangThai IN (N'Bảo lưu', N'Đã nghỉ')
      AND NOT EXISTS (SELECT 1 FROM dbo.GHIDANH x WHERE x.MaHV = hv.MaHV AND x.TrangThai = N'Đang học');
END;
GO

/* C4. usp_GhiDanh_TheoLop: danh sách học viên của một lớp */
IF OBJECT_ID(N'dbo.usp_GhiDanh_TheoLop', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GhiDanh_TheoLop;
GO
CREATE PROCEDURE dbo.usp_GhiDanh_TheoLop
    @MaLop VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT gd.MaGD, hv.MaHV, hv.HoTen, hv.GioiTinh, COALESCE(hv.SoDienThoai, hv.SDTPhuHuynh) AS SoLienLac,
           gd.NgayGhiDanh, gd.HocPhiPhaiDong, gd.DaDong, gd.HocPhiPhaiDong - gd.DaDong AS ConNo,
           gd.TrangThai, gd.DiemTongKet, gd.KetQua
    FROM dbo.GHIDANH gd JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
    WHERE gd.MaLop = @MaLop
    ORDER BY hv.HoTen;
END;
GO

/* =====================================================================
   D. HỌC PHÍ
   ===================================================================== */

/* D1. usp_PhieuThu_Tao: lập phiếu thu; trigger cập nhật GHIDANH.DaDong
       và chặn thu vượt học phí. */
IF OBJECT_ID(N'dbo.usp_PhieuThu_Tao', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_PhieuThu_Tao;
GO
CREATE PROCEDURE dbo.usp_PhieuThu_Tao
    @MaGD      VARCHAR(10),
    @SoTien    DECIMAL(12,0),
    @HinhThuc  NVARCHAR(20)  = N'Tiền mặt',
    @NoiDung   NVARCHAR(200) = NULL,
    @NgayThu   DATETIME      = NULL,
    @MaNVThu   VARCHAR(10)   = NULL,
    @MaPT      VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @MaNVThu = COALESCE(@MaNVThu, dbo.fn_MaNVHienTai());

    IF @MaNVThu IS NULL
        THROW 50030, N'Tài khoản hiện tại không gắn với nhân viên thu tiền.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.GHIDANH WHERE MaGD = @MaGD AND TrangThai <> N'Đã nghỉ')
        THROW 50031, N'Không tìm thấy lượt ghi danh hợp lệ.', 1;

    DECLARE @Moi TABLE (MaPT VARCHAR(10));
    INSERT INTO dbo.PHIEUTHU (MaGD, NgayThu, SoTien, HinhThuc, MaNVThu, NoiDung)
    OUTPUT inserted.MaPT INTO @Moi
    VALUES (@MaGD, ISNULL(@NgayThu, GETDATE()), @SoTien, @HinhThuc, @MaNVThu,
            ISNULL(@NoiDung, N'Thu học phí'));

    SELECT @MaPT = MaPT FROM @Moi;
END;
GO

/* D2. usp_PhieuThu_Huy: hủy phiếu thu (không xóa vật lý - giữ dấu vết kiểm toán) */
IF OBJECT_ID(N'dbo.usp_PhieuThu_Huy', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_PhieuThu_Huy;
GO
CREATE PROCEDURE dbo.usp_PhieuThu_Huy
    @MaPT  VARCHAR(10),
    @LyDo  NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF LTRIM(RTRIM(ISNULL(@LyDo, N''))) = N''
        THROW 50032, N'Phải nhập lý do hủy phiếu thu.', 1;

    UPDATE dbo.PHIEUTHU SET TrangThai = N'Đã hủy', LyDoHuy = @LyDo
    WHERE MaPT = @MaPT AND TrangThai = N'Hợp lệ';
    IF @@ROWCOUNT = 0
        THROW 50033, N'Không tìm thấy phiếu thu hợp lệ để hủy.', 1;
END;
GO

/* D3. usp_PhieuThu_InBienLai: dữ liệu in biên lai */
IF OBJECT_ID(N'dbo.usp_PhieuThu_InBienLai', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_PhieuThu_InBienLai;
GO
CREATE PROCEDURE dbo.usp_PhieuThu_InBienLai
    @MaPT VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pt.MaPT, pt.NgayThu, pt.SoTien, pt.HinhThuc, pt.NoiDung, pt.TrangThai,
           hv.MaHV, hv.HoTen AS TenHocVien, l.MaLop, l.TenLop, k.TenKH,
           gd.HocPhiPhaiDong, gd.DaDong, gd.HocPhiPhaiDong - gd.DaDong AS ConNo,
           nv.HoTen AS NguoiThu, cn.TenCN, cn.DiaChi AS DiaChiCN, cn.SoDienThoai AS SDTCN
    FROM dbo.PHIEUTHU pt
    JOIN dbo.GHIDANH gd  ON gd.MaGD = pt.MaGD
    JOIN dbo.HOCVIEN hv  ON hv.MaHV = gd.MaHV
    JOIN dbo.LOPHOC l    ON l.MaLop = gd.MaLop
    JOIN dbo.KHOAHOC k   ON k.MaKH = l.MaKH
    JOIN dbo.NHANVIEN nv ON nv.MaNV = pt.MaNVThu
    JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
    WHERE pt.MaPT = @MaPT;
END;
GO

/* =====================================================================
   E. HỌC VỤ: KIỂM TRA ĐẦU VÀO - ĐIỂM DANH - ĐIỂM - XÉT KẾT QUẢ
   ===================================================================== */

/* E1. usp_KiemTraDauVao_Them (trigger tự đề xuất khóa học phù hợp) */
IF OBJECT_ID(N'dbo.usp_KiemTraDauVao_Them', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_KiemTraDauVao_Them;
GO
CREATE PROCEDURE dbo.usp_KiemTraDauVao_Them
    @MaHV         VARCHAR(10),
    @DiemNghe     DECIMAL(4,2),
    @DiemNoi      DECIMAL(4,2),
    @DiemDoc      DECIMAL(4,2),
    @DiemViet     DECIMAL(4,2),
    @MaGVCham     VARCHAR(10)   = NULL,
    @GhiChu       NVARCHAR(200) = NULL,
    @NgayKiemTra  DATE          = NULL,
    @MaKT         VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Moi TABLE (MaKT VARCHAR(10));
    INSERT INTO dbo.KIEMTRADAUVAO (MaHV, NgayKiemTra, DiemNghe, DiemNoi, DiemDoc, DiemViet, MaGVCham, GhiChu)
    OUTPUT inserted.MaKT INTO @Moi
    VALUES (@MaHV, ISNULL(@NgayKiemTra, CAST(GETDATE() AS DATE)), @DiemNghe, @DiemNoi, @DiemDoc, @DiemViet, @MaGVCham, @GhiChu);

    SELECT @MaKT = MaKT FROM @Moi;
    SELECT kt.MaKT, kt.DiemTong, kt.MaKHDeXuat, k.TenKH AS KhoaHocDeXuat
    FROM dbo.KIEMTRADAUVAO kt LEFT JOIN dbo.KHOAHOC k ON k.MaKH = kt.MaKHDeXuat
    WHERE kt.MaKT = @MaKT;
END;
GO

/* E2. usp_DiemDanh_Luu: lưu điểm danh một học viên trong một buổi
       (giáo viên chỉ điểm danh buổi mình dạy) */
IF OBJECT_ID(N'dbo.usp_DiemDanh_Luu', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_DiemDanh_Luu;
GO
CREATE PROCEDURE dbo.usp_DiemDanh_Luu
    @MaBuoi     INT,
    @MaGD       VARCHAR(10),
    @TrangThai  NVARCHAR(20),
    @GhiChu     NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_VaiTroHienTai() = 'GIAOVIEN'
       AND NOT EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaBuoi = @MaBuoi AND MaGV = dbo.fn_MaGVHienTai())
        THROW 50040, N'Bạn chỉ được điểm danh buổi học do mình phụ trách.', 1;

    IF EXISTS (SELECT 1 FROM dbo.DIEMDANH WHERE MaBuoi = @MaBuoi AND MaGD = @MaGD)
        UPDATE dbo.DIEMDANH SET TrangThai = @TrangThai, GhiChu = @GhiChu
        WHERE MaBuoi = @MaBuoi AND MaGD = @MaGD;
    ELSE
        INSERT INTO dbo.DIEMDANH (MaBuoi, MaGD, TrangThai, GhiChu)
        VALUES (@MaBuoi, @MaGD, @TrangThai, @GhiChu);
END;
GO

/* E3. usp_DiemDanh_TheoBuoi: danh sách điểm danh của một buổi (kể cả chưa điểm danh) */
IF OBJECT_ID(N'dbo.usp_DiemDanh_TheoBuoi', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_DiemDanh_TheoBuoi;
GO
CREATE PROCEDURE dbo.usp_DiemDanh_TheoBuoi
    @MaBuoi INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_VaiTroHienTai() = 'GIAOVIEN'
       AND NOT EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaBuoi = @MaBuoi AND MaGV = dbo.fn_MaGVHienTai())
        THROW 50040, N'Bạn chỉ được xem điểm danh buổi học do mình phụ trách.', 1;

    SELECT gd.MaGD, hv.MaHV, hv.HoTen, ISNULL(dd.TrangThai, N'Có mặt') AS TrangThai, dd.GhiChu,
           CASE WHEN dd.MaGD IS NULL THEN 0 ELSE 1 END AS DaLuu
    FROM dbo.BUOIHOC b
    JOIN dbo.GHIDANH gd     ON gd.MaLop = b.MaLop AND gd.TrangThai IN (N'Đang học', N'Hoàn thành')
    JOIN dbo.HOCVIEN hv     ON hv.MaHV = gd.MaHV
    LEFT JOIN dbo.DIEMDANH dd ON dd.MaBuoi = b.MaBuoi AND dd.MaGD = gd.MaGD
    WHERE b.MaBuoi = @MaBuoi
    ORDER BY hv.HoTen;
END;
GO

/* E4. usp_Diem_Luu: nhập/sửa điểm một thành phần
       (giáo viên chỉ nhập điểm lớp mình dạy; không sửa sau khi lớp kết thúc) */
IF OBJECT_ID(N'dbo.usp_Diem_Luu', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Diem_Luu;
GO
CREATE PROCEDURE dbo.usp_Diem_Luu
    @MaGD  VARCHAR(10),
    @MaTP  INT,
    @Diem  DECIMAL(4,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaGVLop VARCHAR(10), @TrangThaiLop NVARCHAR(20);

    SELECT @MaGVLop = l.MaGV, @TrangThaiLop = l.TrangThai
    FROM dbo.GHIDANH gd JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
    WHERE gd.MaGD = @MaGD;

    IF @MaGVLop IS NULL
        THROW 50026, N'Không tìm thấy lượt ghi danh.', 1;
    IF dbo.fn_VaiTroHienTai() = 'GIAOVIEN' AND @MaGVLop <> dbo.fn_MaGVHienTai()
        THROW 50041, N'Bạn chỉ được nhập điểm lớp do mình phụ trách.', 1;
    IF @TrangThaiLop = N'Đã kết thúc'
        THROW 50042, N'Lớp đã kết thúc và xét kết quả, không thể sửa điểm.', 1;

    IF EXISTS (SELECT 1 FROM dbo.DIEM WHERE MaGD = @MaGD AND MaTP = @MaTP)
        UPDATE dbo.DIEM SET Diem = @Diem, NgayNhap = GETDATE(), NguoiNhap = ORIGINAL_LOGIN()
        WHERE MaGD = @MaGD AND MaTP = @MaTP;
    ELSE
        INSERT INTO dbo.DIEM (MaGD, MaTP, Diem) VALUES (@MaGD, @MaTP, @Diem);
END;
GO

/* E5. usp_LopHoc_XetKetQua: xét kết quả cuối khóa cho cả lớp bằng CURSOR.
       Với từng học viên: tính điểm tổng kết + tỷ lệ chuyên cần,
       Đạt khi điểm >= 5 và chuyên cần >= 80%, cấp chứng nhận nếu Đạt. */
IF OBJECT_ID(N'dbo.usp_LopHoc_XetKetQua', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_LopHoc_XetKetQua;
GO
CREATE PROCEDURE dbo.usp_LopHoc_XetKetQua
    @MaLop VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaKH VARCHAR(10), @MaGD VARCHAR(10), @Diem DECIMAL(4,2), @ChuyenCan DECIMAL(5,2),
            @KetQua NVARCHAR(20), @SoDat INT = 0, @SoKhongDat INT = 0, @SoThieuDiem INT = 0,
            @NgayCap DATE, @Msg NVARCHAR(2048);

    SELECT @MaKH = MaKH, @NgayCap = ISNULL(NgayKetThuc, CAST(GETDATE() AS DATE))
    FROM dbo.LOPHOC WHERE MaLop = @MaLop AND TrangThai IN (N'Đang học', N'Đã kết thúc');
    IF @MaKH IS NULL
        THROW 50043, N'Lớp không tồn tại hoặc chưa bắt đầu học.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_KhoaHoc_TrongSoChuaHopLe WHERE MaKH = @MaKH)
        THROW 50044, N'Tổng trọng số các cột điểm của khóa học chưa bằng 100%.', 1;

    -- Kiểm tra trước: mọi học viên phải đủ điểm
    SELECT @SoThieuDiem = COUNT(*) FROM dbo.GHIDANH
    WHERE MaLop = @MaLop AND TrangThai IN (N'Đang học', N'Hoàn thành')
      AND dbo.fn_TinhDiemTongKet(MaGD) IS NULL;
    IF @SoThieuDiem > 0
    BEGIN
        SET @Msg = N'Còn ' + CAST(@SoThieuDiem AS NVARCHAR(10)) + N' học viên chưa nhập đủ điểm.';
        THROW 50045, @Msg, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE cur_HocVien CURSOR LOCAL FAST_FORWARD FOR
            SELECT MaGD FROM dbo.GHIDANH
            WHERE MaLop = @MaLop AND TrangThai IN (N'Đang học', N'Hoàn thành')
            ORDER BY MaGD;

        OPEN cur_HocVien;
        FETCH NEXT FROM cur_HocVien INTO @MaGD;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Diem = dbo.fn_TinhDiemTongKet(@MaGD);
            SET @ChuyenCan = ISNULL(dbo.fn_TyLeChuyenCan(@MaGD), 100);
            SET @KetQua = CASE WHEN @Diem >= 5 AND @ChuyenCan >= 80 THEN N'Đạt' ELSE N'Không đạt' END;

            UPDATE dbo.GHIDANH
            SET DiemTongKet = @Diem, KetQua = @KetQua, TrangThai = N'Hoàn thành'
            WHERE MaGD = @MaGD;

            IF @KetQua = N'Đạt'
            BEGIN
                SET @SoDat += 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.CHUNGCHI WHERE MaGD = @MaGD)
                    INSERT INTO dbo.CHUNGCHI (MaGD, SoHieu, NgayCap, DiemTongKet, XepLoai)
                    VALUES (@MaGD, 'EC' + CONVERT(VARCHAR(4), YEAR(@NgayCap)) + '-' + @MaGD,
                            @NgayCap, @Diem, dbo.fn_XepLoai(@Diem));
            END
            ELSE
                SET @SoKhongDat += 1;

            FETCH NEXT FROM cur_HocVien INTO @MaGD;
        END;

        CLOSE cur_HocVien;
        DEALLOCATE cur_HocVien;

        UPDATE dbo.LOPHOC SET TrangThai = N'Đã kết thúc' WHERE MaLop = @MaLop;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @SoDat AS SoDat, @SoKhongDat AS SoKhongDat;
END;
GO

/* =====================================================================
   F. LƯƠNG GIÁO VIÊN
   ===================================================================== */

/* F1. usp_BangLuong_Chot: chốt lương tháng cho từng giáo viên bằng CURSOR.
       Lương = số giờ đã dạy x đơn giá giờ; thưởng 500.000đ nếu dạy >= 20 buổi. */
IF OBJECT_ID(N'dbo.usp_BangLuong_Chot', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_BangLuong_Chot;
GO
CREATE PROCEDURE dbo.usp_BangLuong_Chot
    @Thang TINYINT,
    @Nam   SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaGV VARCHAR(10), @DonGia DECIMAL(12,0), @SoBuoi INT, @SoGio DECIMAL(6,2),
            @Thuong DECIMAL(12,0), @SoGV INT = 0;

    IF DATEFROMPARTS(@Nam, @Thang, 1) > CAST(GETDATE() AS DATE)
        THROW 50050, N'Không thể chốt lương cho tháng trong tương lai.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE cur_GiaoVien CURSOR LOCAL FAST_FORWARD FOR
            SELECT gv.MaGV, gv.DonGiaGio, COUNT(b.MaBuoi),
                   CAST(SUM(DATEDIFF(MINUTE, b.GioBatDau, b.GioKetThuc)) / 60.0 AS DECIMAL(6,2))
            FROM dbo.GIAOVIEN gv
            JOIN dbo.BUOIHOC b ON b.MaGV = gv.MaGV
            WHERE b.TrangThai = N'Đã dạy' AND MONTH(b.NgayHoc) = @Thang AND YEAR(b.NgayHoc) = @Nam
            GROUP BY gv.MaGV, gv.DonGiaGio;

        OPEN cur_GiaoVien;
        FETCH NEXT FROM cur_GiaoVien INTO @MaGV, @DonGia, @SoBuoi, @SoGio;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Thuong = CASE WHEN @SoBuoi >= 20 THEN 500000 ELSE 0 END;

            IF EXISTS (SELECT 1 FROM dbo.BANGLUONG WHERE MaGV = @MaGV AND Thang = @Thang AND Nam = @Nam)
                UPDATE dbo.BANGLUONG
                SET SoBuoi = @SoBuoi, SoGio = @SoGio, DonGiaGio = @DonGia, Thuong = @Thuong, NgayChot = GETDATE()
                WHERE MaGV = @MaGV AND Thang = @Thang AND Nam = @Nam AND TrangThai = N'Đã chốt';
            ELSE
                INSERT INTO dbo.BANGLUONG (MaGV, Thang, Nam, SoBuoi, SoGio, DonGiaGio, Thuong)
                VALUES (@MaGV, @Thang, @Nam, @SoBuoi, @SoGio, @DonGia, @Thuong);

            SET @SoGV += 1;
            FETCH NEXT FROM cur_GiaoVien INTO @MaGV, @DonGia, @SoBuoi, @SoGio;
        END;

        CLOSE cur_GiaoVien;
        DEALLOCATE cur_GiaoVien;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT bl.MaGV, gv.HoTen, bl.SoBuoi, bl.SoGio, bl.DonGiaGio, bl.Thuong, bl.KhauTru, bl.TongLuong, bl.TrangThai
    FROM dbo.BANGLUONG bl JOIN dbo.GIAOVIEN gv ON gv.MaGV = bl.MaGV
    WHERE bl.Thang = @Thang AND bl.Nam = @Nam
    ORDER BY gv.HoTen;
END;
GO

/* =====================================================================
   G. BÁO CÁO - THỐNG KÊ
   ===================================================================== */

/* G1. usp_ThongKe_TongQuan: số liệu cho màn hình Dashboard.
       Giáo vụ cũng gọi được thủ tục này nhưng KHÔNG được xem doanh thu:
       cột DoanhThuThangNay trả NULL nếu người gọi không phải quản lý/kế toán. */
IF OBJECT_ID(N'dbo.usp_ThongKe_TongQuan', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_ThongKe_TongQuan;
GO
CREATE PROCEDURE dbo.usp_ThongKe_TongQuan
    @MaCN VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @HomNay DATE = CAST(GETDATE() AS DATE);
    DECLARE @XemDoanhThu BIT = CASE WHEN dbo.fn_VaiTroHienTai() IN ('QUANLY', 'KETOAN') THEN 1 ELSE 0 END;

    SELECT
        (SELECT COUNT(*) FROM dbo.HOCVIEN WHERE TrangThai = N'Đang học' AND (@MaCN IS NULL OR MaCN = @MaCN)) AS HocVienDangHoc,
        (SELECT COUNT(*) FROM dbo.LOPHOC WHERE TrangThai = N'Đang học' AND (@MaCN IS NULL OR MaCN = @MaCN)) AS LopDangHoc,
        (SELECT COUNT(*) FROM dbo.LOPHOC WHERE TrangThai = N'Đang tuyển sinh' AND (@MaCN IS NULL OR MaCN = @MaCN)) AS LopTuyenSinh,
        CASE WHEN @XemDoanhThu = 0 THEN NULL ELSE
        (SELECT ISNULL(SUM(pt.SoTien), 0) FROM dbo.PHIEUTHU pt
            JOIN dbo.GHIDANH gd ON gd.MaGD = pt.MaGD JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
            WHERE pt.TrangThai = N'Hợp lệ' AND YEAR(pt.NgayThu) = YEAR(@HomNay) AND MONTH(pt.NgayThu) = MONTH(@HomNay)
              AND (@MaCN IS NULL OR l.MaCN = @MaCN)) END AS DoanhThuThangNay,
        (SELECT ISNULL(SUM(ConNo), 0) FROM dbo.vw_CongNo WHERE (@MaCN IS NULL OR MaCN = @MaCN)) AS TongCongNo,
        (SELECT COUNT(*) FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
            WHERE b.NgayHoc = @HomNay AND b.TrangThai <> N'Hủy' AND (@MaCN IS NULL OR l.MaCN = @MaCN)) AS BuoiHocHomNay;
END;
GO

/* G2. usp_BaoCao_DoanhThu: doanh thu chi tiết theo khóa học trong khoảng ngày */
IF OBJECT_ID(N'dbo.usp_BaoCao_DoanhThu', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_BaoCao_DoanhThu;
GO
CREATE PROCEDURE dbo.usp_BaoCao_DoanhThu
    @TuNgay   DATE,
    @DenNgay  DATE,
    @MaCN     VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cn.TenCN, ct.TenCT, k.TenKH, COUNT(*) AS SoPhieu, SUM(pt.SoTien) AS DoanhThu
    FROM dbo.PHIEUTHU pt
    JOIN dbo.GHIDANH gd     ON gd.MaGD = pt.MaGD
    JOIN dbo.LOPHOC l       ON l.MaLop = gd.MaLop
    JOIN dbo.KHOAHOC k      ON k.MaKH = l.MaKH
    JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT
    JOIN dbo.CHINHANH cn    ON cn.MaCN = l.MaCN
    WHERE pt.TrangThai = N'Hợp lệ'
      AND pt.NgayThu >= @TuNgay AND pt.NgayThu < DATEADD(DAY, 1, @DenNgay)
      AND (@MaCN IS NULL OR l.MaCN = @MaCN)
    GROUP BY cn.TenCN, ct.TenCT, k.TenKH
    ORDER BY cn.TenCN, ct.TenCT, DoanhThu DESC;
END;
GO

/* G3. usp_BaoCao_KetQuaLop: bảng điểm tổng kết của lớp */
IF OBJECT_ID(N'dbo.usp_BaoCao_KetQuaLop', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_BaoCao_KetQuaLop;
GO
CREATE PROCEDURE dbo.usp_BaoCao_KetQuaLop
    @MaLop VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT kq.MaHV, kq.HoTen, kq.DiemTongKet, kq.XepLoai, kq.TyLeChuyenCan, kq.KetQua,
           cc.SoHieu AS SoHieuChungNhan
    FROM dbo.vw_KetQuaHocTap kq
    LEFT JOIN dbo.CHUNGCHI cc ON cc.MaGD = kq.MaGD
    WHERE kq.MaLop = @MaLop AND kq.TrangThai IN (N'Đang học', N'Hoàn thành')
    ORDER BY kq.DiemTongKet DESC, kq.HoTen;
END;
GO

/* =====================================================================
   H. XML - XPATH/XQUERY - IMPORT/EXPORT
   ===================================================================== */

/* H1. usp_KhoaHoc_TimTheoKyNang: khóa học có Unit luyện kỹ năng @KyNang
       (XQuery .exist() với sql:variable) */
IF OBJECT_ID(N'dbo.usp_KhoaHoc_TimTheoKyNang', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_KhoaHoc_TimTheoKyNang;
GO
CREATE PROCEDURE dbo.usp_KhoaHoc_TimTheoKyNang
    @KyNang NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT k.MaKH, k.TenKH, k.CapDo,
           k.NoiDungXML.value('(/DeCuong/GiaoTrinh)[1]', 'NVARCHAR(200)') AS GiaoTrinh,
           k.NoiDungXML.value('count(/DeCuong/Unit[KyNang = sql:variable("@KyNang")])', 'INT') AS SoUnit
    FROM dbo.KHOAHOC k
    WHERE k.NoiDungXML.exist('/DeCuong/Unit[KyNang = sql:variable("@KyNang")]') = 1;
END;
GO

/* H2. usp_KhoaHoc_DeCuong: tách đề cương XML thành bảng quan hệ bằng .nodes() */
IF OBJECT_ID(N'dbo.usp_KhoaHoc_DeCuong', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_KhoaHoc_DeCuong;
GO
CREATE PROCEDURE dbo.usp_KhoaHoc_DeCuong
    @MaKH VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.value('@So', 'INT')                       AS Unit,
           u.value('(TenUnit)[1]', 'NVARCHAR(200)')    AS TenUnit,
           u.value('@SoBuoi', 'INT')                   AS SoBuoi,
           STUFF(u.query('for $k in KyNang return concat(", ", string($k))').value('.', 'NVARCHAR(200)'), 1, 2, '') AS KyNang
    FROM dbo.KHOAHOC k
    CROSS APPLY k.NoiDungXML.nodes('/DeCuong/Unit') AS T(u)
    WHERE k.MaKH = @MaKH
    ORDER BY Unit;
END;
GO

/* H3. usp_GiaoVien_TimTheoChungChi: giáo viên có chứng chỉ @Loai với điểm >= @DiemToiThieu
       (XQuery trên hồ sơ năng lực dạng XML không định kiểu) */
IF OBJECT_ID(N'dbo.usp_GiaoVien_TimTheoChungChi', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GiaoVien_TimTheoChungChi;
GO
CREATE PROCEDURE dbo.usp_GiaoVien_TimTheoChungChi
    @Loai          NVARCHAR(20),
    @DiemToiThieu  DECIMAL(4,1) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT gv.MaGV, gv.HoTen, gv.LoaiGV,
           gv.HoSoXML.value('(/HoSo/ChungChi[@Loai = sql:variable("@Loai")]/@Diem)[1]', 'DECIMAL(4,1)') AS Diem,
           gv.HoSoXML.value('(/HoSo/KinhNghiem/@SoNam)[1]', 'INT') AS SoNamKinhNghiem,
           gv.HoSoXML.query('/HoSo/ChuyenMon') AS ChuyenMon
    FROM dbo.GIAOVIEN gv
    WHERE gv.HoSoXML.exist('/HoSo/ChungChi[@Loai = sql:variable("@Loai")
                                         and (empty(@Diem) or @Diem >= sql:variable("@DiemToiThieu"))]') = 1
    ORDER BY Diem DESC;
END;
GO

/* H4. usp_HocVien_XuatXML: xuất danh sách học viên ra XML (FOR XML PATH) */
IF OBJECT_ID(N'dbo.usp_HocVien_XuatXML', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_XuatXML;
GO
CREATE PROCEDURE dbo.usp_HocVien_XuatXML
    @MaCN VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (
        SELECT hv.MaHV AS '@MaHV', hv.MaCN AS '@MaCN',
               hv.HoTen, hv.NgaySinh, hv.GioiTinh, hv.SoDienThoai, hv.Email,
               hv.TenPhuHuynh, hv.SDTPhuHuynh, hv.TrangThai
        FROM dbo.HOCVIEN hv
        WHERE @MaCN IS NULL OR hv.MaCN = @MaCN
        ORDER BY hv.MaHV
        FOR XML PATH('HocVien'), ROOT('DanhSachHocVien'), TYPE
    ) AS DuLieuXML;
END;
GO

/* H5. usp_HocVien_NhapXML: nhập học viên từ XML (cùng cấu trúc với file xuất).
       Bỏ qua dòng trùng SĐT/email; trả về số dòng đã nhập. */
IF OBJECT_ID(N'dbo.usp_HocVien_NhapXML', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_HocVien_NhapXML;
GO
CREATE PROCEDURE dbo.usp_HocVien_NhapXML
    @DuLieu  XML,
    @MaCN    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Nguon TABLE (
        HoTen NVARCHAR(100), NgaySinh DATE, GioiTinh NVARCHAR(5), SoDienThoai VARCHAR(15),
        Email VARCHAR(100), TenPhuHuynh NVARCHAR(100), SDTPhuHuynh VARCHAR(15));

    INSERT INTO @Nguon
    SELECT x.value('(HoTen)[1]', 'NVARCHAR(100)'),
           x.value('(NgaySinh)[1]', 'DATE'),
           ISNULL(x.value('(GioiTinh)[1]', 'NVARCHAR(5)'), N'Khác'),
           NULLIF(x.value('(SoDienThoai)[1]', 'VARCHAR(15)'), ''),
           NULLIF(x.value('(Email)[1]', 'VARCHAR(100)'), ''),
           NULLIF(x.value('(TenPhuHuynh)[1]', 'NVARCHAR(100)'), ''),
           NULLIF(x.value('(SDTPhuHuynh)[1]', 'VARCHAR(15)'), '')
    FROM @DuLieu.nodes('/DanhSachHocVien/HocVien') AS T(x);

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.HOCVIEN (HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, TenPhuHuynh, SDTPhuHuynh, MaCN)
        SELECT n.HoTen, n.NgaySinh, n.GioiTinh, n.SoDienThoai, n.Email, n.TenPhuHuynh, n.SDTPhuHuynh, @MaCN
        FROM @Nguon n
        WHERE n.HoTen IS NOT NULL AND n.NgaySinh IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN h WHERE h.SoDienThoai = n.SoDienThoai OR h.Email = n.Email);
        DECLARE @SoDong INT = @@ROWCOUNT;
        COMMIT TRANSACTION;
        SELECT @SoDong AS SoDongDaNhap, (SELECT COUNT(*) FROM @Nguon) - @SoDong AS SoDongBoQua;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =====================================================================
   I. TÀI KHOẢN - SAO LƯU (bảo mật)
   ===================================================================== */

/* I1. usp_TaiKhoan_Tao: tạo USER có mật khẩu trong CSDL độc lập + gán ROLE.
       EXECUTE AS OWNER: người gọi chỉ cần quyền EXECUTE, không cần quyền
       ALTER ANY USER; tên đăng nhập được kiểm tra ký tự và QUOTENAME
       để chống SQL injection trong dynamic SQL. */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_Tao', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_Tao;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_Tao
    @TenDangNhap  NVARCHAR(50),
    @MatKhau      NVARCHAR(128),
    @VaiTro       VARCHAR(20),
    @MaNV         VARCHAR(10) = NULL,
    @MaGV         VARCHAR(10) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Role SYSNAME, @Sql NVARCHAR(MAX);

    IF @TenDangNhap IS NULL OR @TenDangNhap LIKE N'%[^a-zA-Z0-9_.]%' OR LEN(@TenDangNhap) < 3
        THROW 50060, N'Tên đăng nhập chỉ gồm chữ không dấu, số, dấu chấm, gạch dưới (tối thiểu 3 ký tự).', 1;
    IF LEN(ISNULL(@MatKhau, N'')) < 8
        THROW 50061, N'Mật khẩu tối thiểu 8 ký tự.', 1;
    IF DATABASE_PRINCIPAL_ID(@TenDangNhap) IS NOT NULL OR EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 50062, N'Tên đăng nhập đã tồn tại.', 1;

    SET @Role = CASE @VaiTro WHEN 'QUANLY' THEN 'rl_QuanLy' WHEN 'GIAOVU' THEN 'rl_GiaoVu'
                             WHEN 'KETOAN' THEN 'rl_KeToan' WHEN 'GIAOVIEN' THEN 'rl_GiaoVien' END;
    IF @Role IS NULL
        THROW 50063, N'Vai trò không hợp lệ.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.TAIKHOAN (TenDangNhap, VaiTro, MaNV, MaGV) VALUES (@TenDangNhap, @VaiTro, @MaNV, @MaGV);

        SET @Sql = N'CREATE USER ' + QUOTENAME(@TenDangNhap)
                 + N' WITH PASSWORD = N''' + REPLACE(@MatKhau, N'''', N'''''') + N''', DEFAULT_SCHEMA = dbo;'
                 + N' ALTER ROLE ' + QUOTENAME(@Role) + N' ADD MEMBER ' + QUOTENAME(@TenDangNhap) + N';';
        EXEC sys.sp_executesql @Sql;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* I2. usp_TaiKhoan_Khoa: khóa / mở khóa (DENY / GRANT quyền CONNECT) */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_Khoa', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_Khoa;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_Khoa
    @TenDangNhap  NVARCHAR(50),
    @Khoa         BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(400);
    IF NOT EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 50064, N'Không tìm thấy tài khoản.', 1;
    IF @TenDangNhap = ORIGINAL_LOGIN()
        THROW 50065, N'Không thể tự khóa tài khoản đang đăng nhập.', 1;

    SET @Sql = CASE WHEN @Khoa = 1 THEN N'DENY CONNECT TO ' ELSE N'GRANT CONNECT TO ' END + QUOTENAME(@TenDangNhap);
    EXEC sys.sp_executesql @Sql;
    UPDATE dbo.TAIKHOAN SET TrangThai = CASE WHEN @Khoa = 1 THEN N'Đã khóa' ELSE N'Hoạt động' END
    WHERE TenDangNhap = @TenDangNhap;
END;
GO

/* I3. usp_TaiKhoan_DatLaiMatKhau: quản lý đặt lại mật khẩu cho nhân viên */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_DatLaiMatKhau', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_DatLaiMatKhau;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_DatLaiMatKhau
    @TenDangNhap  NVARCHAR(50),
    @MatKhauMoi   NVARCHAR(128)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    IF NOT EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 50064, N'Không tìm thấy tài khoản.', 1;
    IF LEN(ISNULL(@MatKhauMoi, N'')) < 8
        THROW 50061, N'Mật khẩu tối thiểu 8 ký tự.', 1;

    SET @Sql = N'ALTER USER ' + QUOTENAME(@TenDangNhap)
             + N' WITH PASSWORD = N''' + REPLACE(@MatKhauMoi, N'''', N'''''') + N''';';
    EXEC sys.sp_executesql @Sql;
END;
GO

/* I4. usp_TaiKhoan_DoiMatKhau: người dùng tự đổi mật khẩu (chạy với quyền người gọi,
       SQL Server bắt buộc nhập đúng mật khẩu cũ - OLD_PASSWORD) */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_DoiMatKhau', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_DoiMatKhau;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_DoiMatKhau
    @MatKhauCu   NVARCHAR(128),
    @MatKhauMoi  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    IF LEN(ISNULL(@MatKhauMoi, N'')) < 8
        THROW 50061, N'Mật khẩu tối thiểu 8 ký tự.', 1;

    SET @Sql = N'ALTER USER ' + QUOTENAME(USER_NAME())
             + N' WITH PASSWORD = N''' + REPLACE(@MatKhauMoi, N'''', N'''''')
             + N''' OLD_PASSWORD = N''' + REPLACE(@MatKhauCu, N'''', N'''''') + N''';';
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        -- Chuyển lỗi hệ thống (tiếng Anh) thành thông báo nghiệp vụ tiếng Việt
        IF ERROR_NUMBER() = 15151   -- sai OLD_PASSWORD
            THROW 50066, N'Mật khẩu hiện tại không đúng.', 1;
        IF ERROR_NUMBER() IN (15114, 15115, 15116, 15118)   -- vi phạm chính sách mật khẩu
            THROW 50067, N'Mật khẩu mới chưa đủ mạnh: cần chữ hoa, chữ thường, chữ số hoặc ký tự đặc biệt.', 1;
        THROW;
    END CATCH;
END;
GO

/* I5. usp_TaiKhoan_GhiNhanDangNhap: cập nhật lần đăng nhập cuối (gọi ngay sau login) */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_GhiNhanDangNhap', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_GhiNhanDangNhap;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_GhiNhanDangNhap
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.TAIKHOAN SET LanDangNhapCuoi = GETDATE() WHERE TenDangNhap = USER_NAME() COLLATE DATABASE_DEFAULT;
    SELECT TenDangNhap, VaiTro, MaNV, MaGV, TrangThai, HoTen, MaCN FROM dbo.vw_TaiKhoanHienTai;
END;
GO

/* I6. usp_TaiKhoan_DanhSach */
IF OBJECT_ID(N'dbo.usp_TaiKhoan_DanhSach', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_TaiKhoan_DanhSach;
GO
CREATE PROCEDURE dbo.usp_TaiKhoan_DanhSach
AS
BEGIN
    SET NOCOUNT ON;
    SELECT tk.TenDangNhap,
           CASE tk.VaiTro WHEN 'QUANLY' THEN N'Quản lý' WHEN 'GIAOVU' THEN N'Giáo vụ'
                          WHEN 'KETOAN' THEN N'Kế toán' WHEN 'GIAOVIEN' THEN N'Giáo viên' END AS VaiTro,
           COALESCE(nv.HoTen, gv.HoTen) AS HoTen,
           tk.TrangThai, tk.NgayTao, tk.LanDangNhapCuoi
    FROM dbo.TAIKHOAN tk
    LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = tk.MaNV
    LEFT JOIN dbo.GIAOVIEN gv ON gv.MaGV = tk.MaGV
    ORDER BY tk.VaiTro, tk.TenDangNhap;
END;
GO

/* I7. usp_SaoLuu: sao lưu FULL / DIFFERENTIAL / LOG vào thư mục trên máy chủ SQL */
IF OBJECT_ID(N'dbo.usp_SaoLuu', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_SaoLuu;
GO
CREATE PROCEDURE dbo.usp_SaoLuu
    @Loai     VARCHAR(10)    = 'FULL',
    @ThuMuc   NVARCHAR(260)  = NULL,
    @TepTin   NVARCHAR(400)  = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX), @ThoiDiem VARCHAR(20) =
        REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), '-', ''), ':', ''), ' ', '_');

    IF @Loai NOT IN ('FULL', 'DIFF', 'LOG')
        THROW 50070, N'Loại sao lưu phải là FULL, DIFF hoặc LOG.', 1;

    -- Mặc định: thư mục backup của SQL Server (Linux/Docker: /var/opt/mssql/data)
    IF @ThuMuc IS NULL
        SET @ThuMuc = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF @ThuMuc IS NULL
        SET @ThuMuc = LEFT(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)), 260);
    IF RIGHT(@ThuMuc, 1) NOT IN ('/', '\')
        SET @ThuMuc += CASE WHEN CHARINDEX('/', @ThuMuc) > 0 THEN '/' ELSE '\' END;

    SET @TepTin = @ThuMuc + N'QLTTTA_' + @Loai + N'_' + @ThoiDiem + CASE @Loai WHEN 'LOG' THEN N'.trn' ELSE N'.bak' END;
    SET @Sql = CASE @Loai
                   WHEN 'FULL' THEN N'BACKUP DATABASE QLTTTA TO DISK = @f WITH INIT, NAME = N''QLTTTA Full'''
                   WHEN 'DIFF' THEN N'BACKUP DATABASE QLTTTA TO DISK = @f WITH DIFFERENTIAL, INIT, NAME = N''QLTTTA Differential'''
                   ELSE             N'BACKUP LOG QLTTTA TO DISK = @f WITH INIT, NAME = N''QLTTTA Log'''
               END;
    EXEC sys.sp_executesql @Sql, N'@f NVARCHAR(400)', @f = @TepTin;
    SELECT @TepTin AS TepSaoLuu;
END;
GO
