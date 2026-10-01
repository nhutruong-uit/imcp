/* =====================================================================
   File   : 05_triggers.sql - Trigger
   Dùng trigger cho các ràng buộc toàn vẹn mà CHECK/FOREIGN KEY không diễn
   đạt được (ràng buộc liên quan hệ, liên bộ, thuộc tính dẫn xuất) và cho
   nhật ký kiểm toán. Tất cả trigger xử lý theo TẬP HỢP (nhiều dòng trong
   inserted/deleted), không giả định chỉ có 1 dòng.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* T1. trg_LOPHOC_KiemTraPhong (liên quan hệ LOPHOC - PHONGHOC)
       - Phòng học phải thuộc cùng chi nhánh với lớp
       - Sĩ số tối đa của lớp không vượt sức chứa phòng */
IF OBJECT_ID(N'dbo.trg_LOPHOC_KiemTraPhong', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_LOPHOC_KiemTraPhong;
GO
CREATE TRIGGER dbo.trg_LOPHOC_KiemTraPhong
ON dbo.LOPHOC
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.PHONGHOC p ON p.MaPhong = i.MaPhong WHERE p.MaCN <> i.MaCN)
    BEGIN
        RAISERROR (N'Phòng học phải thuộc cùng chi nhánh với lớp học.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.PHONGHOC p ON p.MaPhong = i.MaPhong WHERE i.SiSoToiDa > p.SucChua)
    BEGIN
        RAISERROR (N'Sĩ số tối đa của lớp vượt quá sức chứa của phòng học.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

/* T2. trg_LICHHOC_KiemTraTrungLich (liên bộ, liên quan hệ)
       Hai lớp còn hoạt động, thời gian học giao nhau, cùng thứ, giờ chồng lấn
       thì không được dùng chung phòng hoặc chung giáo viên. */
IF OBJECT_ID(N'dbo.trg_LICHHOC_KiemTraTrungLich', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_LICHHOC_KiemTraTrungLich;
GO
CREATE TRIGGER dbo.trg_LICHHOC_KiemTraTrungLich
ON dbo.LICHHOC
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Msg NVARCHAR(400);

    SELECT TOP (1) @Msg = N'Trùng lịch với lớp ' + l2.MaLop + N' ('
           + CASE WHEN l1.MaPhong = l2.MaPhong THEN N'cùng phòng ' + l1.MaPhong ELSE N'cùng giáo viên ' + l1.MaGV END
           + N').'
    FROM inserted i
    JOIN dbo.LOPHOC l1  ON l1.MaLop = i.MaLop
    JOIN dbo.LICHHOC lh ON lh.Thu = i.Thu AND lh.MaLop <> i.MaLop
                       AND lh.GioBatDau < i.GioKetThuc AND i.GioBatDau < lh.GioKetThuc
    JOIN dbo.LOPHOC l2  ON l2.MaLop = lh.MaLop
    WHERE l2.TrangThai IN (N'Đang tuyển sinh', N'Đang học')
      AND (l1.MaPhong = l2.MaPhong OR l1.MaGV = l2.MaGV)
      AND l2.NgayKhaiGiang <= ISNULL(l1.NgayKetThuc, DATEADD(MONTH, 6, l1.NgayKhaiGiang))
      AND l1.NgayKhaiGiang <= ISNULL(l2.NgayKetThuc, DATEADD(MONTH, 6, l2.NgayKhaiGiang));

    IF @Msg IS NOT NULL
    BEGIN
        RAISERROR (@Msg, 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T3. trg_GHIDANH_KiemTraSiSo: số học viên đang học không vượt sĩ số tối đa */
IF OBJECT_ID(N'dbo.trg_GHIDANH_KiemTraSiSo', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_GHIDANH_KiemTraSiSo;
GO
CREATE TRIGGER dbo.trg_GHIDANH_KiemTraSiSo
ON dbo.GHIDANH
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(MaLop) OR UPDATE(TrangThai)) RETURN;

    DECLARE @MaLop VARCHAR(10);
    SELECT TOP (1) @MaLop = l.MaLop
    FROM dbo.LOPHOC l
    WHERE l.MaLop IN (SELECT MaLop FROM inserted)
      AND (SELECT COUNT(*) FROM dbo.GHIDANH gd
           WHERE gd.MaLop = l.MaLop AND gd.TrangThai IN (N'Đang học', N'Hoàn thành')) > l.SiSoToiDa;

    IF @MaLop IS NOT NULL
    BEGIN
        RAISERROR (N'Lớp %s đã đủ sĩ số tối đa.', 16, 1, @MaLop);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T4. trg_PHIEUTHU_CapNhatDaDong (thuộc tính dẫn xuất liên quan hệ)
       GHIDANH.DaDong = SUM(PHIEUTHU.SoTien) của các phiếu Hợp lệ.
       Nếu vượt học phí phải đóng thì CHECK của GHIDANH báo lỗi => rollback. */
IF OBJECT_ID(N'dbo.trg_PHIEUTHU_CapNhatDaDong', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_PHIEUTHU_CapNhatDaDong;
GO
CREATE TRIGGER dbo.trg_PHIEUTHU_CapNhatDaDong
ON dbo.PHIEUTHU
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.GHIDANH gd
        JOIN (SELECT MaGD, SUM(SoTien) AS Tong FROM dbo.PHIEUTHU
              WHERE TrangThai = N'Hợp lệ' AND MaGD IN (SELECT MaGD FROM inserted UNION SELECT MaGD FROM deleted)
              GROUP BY MaGD) t ON t.MaGD = gd.MaGD
        WHERE t.Tong > gd.HocPhiPhaiDong)
    BEGIN
        RAISERROR (N'Số tiền thu vượt quá học phí còn nợ của học viên.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE gd
    SET DaDong = ISNULL((SELECT SUM(pt.SoTien) FROM dbo.PHIEUTHU pt
                         WHERE pt.MaGD = gd.MaGD AND pt.TrangThai = N'Hợp lệ'), 0)
    FROM dbo.GHIDANH gd
    WHERE gd.MaGD IN (SELECT MaGD FROM inserted UNION SELECT MaGD FROM deleted);
END;
GO

/* T5. trg_PHIEUTHU_KhongXoa (INSTEAD OF DELETE): chứng từ tài chính không được
       xóa vật lý, chỉ được hủy bằng usp_PhieuThu_Huy. */
IF OBJECT_ID(N'dbo.trg_PHIEUTHU_KhongXoa', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_PHIEUTHU_KhongXoa;
GO
CREATE TRIGGER dbo.trg_PHIEUTHU_KhongXoa
ON dbo.PHIEUTHU
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR (N'Không được xóa phiếu thu. Hãy dùng chức năng Hủy phiếu thu.', 16, 1);
END;
GO

/* T6. trg_DIEMDANH_KiemTraLop: học viên được điểm danh phải thuộc đúng lớp của buổi học */
IF OBJECT_ID(N'dbo.trg_DIEMDANH_KiemTraLop', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_DIEMDANH_KiemTraLop;
GO
CREATE TRIGGER dbo.trg_DIEMDANH_KiemTraLop
ON dbo.DIEMDANH
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.BUOIHOC b ON b.MaBuoi = i.MaBuoi
               JOIN dbo.GHIDANH gd ON gd.MaGD = i.MaGD
               WHERE gd.MaLop <> b.MaLop)
    BEGIN
        RAISERROR (N'Học viên không thuộc lớp của buổi học này.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T7. trg_DIEM_KiemTraThanhPhan: cột điểm phải thuộc khóa học của lớp học viên ghi danh */
IF OBJECT_ID(N'dbo.trg_DIEM_KiemTraThanhPhan', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_DIEM_KiemTraThanhPhan;
GO
CREATE TRIGGER dbo.trg_DIEM_KiemTraThanhPhan
ON dbo.DIEM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.GHIDANH gd       ON gd.MaGD = i.MaGD
               JOIN dbo.LOPHOC l         ON l.MaLop = gd.MaLop
               JOIN dbo.THANHPHANDIEM tp ON tp.MaTP = i.MaTP
               WHERE tp.MaKH <> l.MaKH)
    BEGIN
        RAISERROR (N'Cột điểm không thuộc khóa học của lớp.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T8. trg_DIEM_NhatKy: ghi nhật ký mọi thay đổi điểm (dữ liệu cũ/mới dạng XML) */
IF OBJECT_ID(N'dbo.trg_DIEM_NhatKy', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_DIEM_NhatKy;
GO
CREATE TRIGGER dbo.trg_DIEM_NhatKy
ON dbo.DIEM
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.NHATKYHETHONG (BangDuLieu, HanhDong, KhoaChinh, DuLieuCu, DuLieuMoi)
    SELECT N'DIEM',
           CASE WHEN i.MaGD IS NOT NULL AND d.MaGD IS NOT NULL THEN 'UPDATE'
                WHEN i.MaGD IS NOT NULL THEN 'INSERT' ELSE 'DELETE' END,
           COALESCE(i.MaGD, d.MaGD) + N'/' + CAST(COALESCE(i.MaTP, d.MaTP) AS NVARCHAR(10)),
           (SELECT d.Diem, d.NguoiNhap FOR XML PATH('Diem'), TYPE),
           (SELECT i.Diem, i.NguoiNhap FOR XML PATH('Diem'), TYPE)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.MaGD = i.MaGD AND d.MaTP = i.MaTP
    WHERE i.MaGD IS NULL OR d.MaGD IS NULL OR i.Diem <> d.Diem;
END;
GO

/* T9. trg_PHIEUTHU_NhatKy: ghi nhật ký lập/hủy phiếu thu */
IF OBJECT_ID(N'dbo.trg_PHIEUTHU_NhatKy', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_PHIEUTHU_NhatKy;
GO
CREATE TRIGGER dbo.trg_PHIEUTHU_NhatKy
ON dbo.PHIEUTHU
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.NHATKYHETHONG (BangDuLieu, HanhDong, KhoaChinh, DuLieuCu, DuLieuMoi)
    SELECT N'PHIEUTHU',
           CASE WHEN d.MaPT IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
           i.MaPT,
           CASE WHEN d.MaPT IS NULL THEN NULL
                ELSE (SELECT d.MaGD, d.SoTien, d.TrangThai FOR XML PATH('PhieuThu'), TYPE) END,
           (SELECT i.MaGD, i.SoTien, i.HinhThuc, i.TrangThai, i.LyDoHuy FOR XML PATH('PhieuThu'), TYPE)
    FROM inserted i
    LEFT JOIN deleted d ON d.MaPT = i.MaPT;
END;
GO

/* T10. trg_NHATKY_KhongSua (INSTEAD OF UPDATE, DELETE): nhật ký chỉ được ghi thêm */
IF OBJECT_ID(N'dbo.trg_NHATKY_KhongSua', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_NHATKY_KhongSua;
GO
CREATE TRIGGER dbo.trg_NHATKY_KhongSua
ON dbo.NHATKYHETHONG
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR (N'Nhật ký hệ thống chỉ được ghi thêm, không được sửa hoặc xóa.', 16, 1);
END;
GO

/* T11. trg_KIEMTRADAUVAO_DeXuat: tự động đề xuất khóa học theo điểm tổng */
IF OBJECT_ID(N'dbo.trg_KIEMTRADAUVAO_DeXuat', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_KIEMTRADAUVAO_DeXuat;
GO
CREATE TRIGGER dbo.trg_KIEMTRADAUVAO_DeXuat
ON dbo.KIEMTRADAUVAO
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(DiemNghe) OR UPDATE(DiemNoi) OR UPDATE(DiemDoc) OR UPDATE(DiemViet)) RETURN;

    UPDATE kt
    SET MaKHDeXuat = dbo.fn_DeXuatKhoaHoc(kt.DiemTong, NULL)
    FROM dbo.KIEMTRADAUVAO kt
    JOIN inserted i ON i.MaKT = kt.MaKT;
END;
GO

/* T12. trg_CHUNGCHI_KiemTraKetQua: chỉ cấp chứng nhận cho lượt ghi danh có kết quả Đạt */
IF OBJECT_ID(N'dbo.trg_CHUNGCHI_KiemTraKetQua', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_CHUNGCHI_KiemTraKetQua;
GO
CREATE TRIGGER dbo.trg_CHUNGCHI_KiemTraKetQua
ON dbo.CHUNGCHI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.GHIDANH gd ON gd.MaGD = i.MaGD
               WHERE ISNULL(gd.KetQua, N'') <> N'Đạt')
    BEGIN
        RAISERROR (N'Chỉ cấp chứng nhận cho học viên có kết quả Đạt.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T13. trg_BUOIHOC_KhongSuaDaDay: buổi đã dạy không được đổi ngày/giờ/phòng
        (giữ đúng dữ liệu tính lương và điểm danh) */
IF OBJECT_ID(N'dbo.trg_BUOIHOC_KhongSuaDaDay', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_BUOIHOC_KhongSuaDaDay;
GO
CREATE TRIGGER dbo.trg_BUOIHOC_KhongSuaDaDay
ON dbo.BUOIHOC
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.MaBuoi = i.MaBuoi
               WHERE d.TrangThai = N'Đã dạy'
                 AND (i.NgayHoc <> d.NgayHoc OR i.GioBatDau <> d.GioBatDau OR i.GioKetThuc <> d.GioKetThuc
                      OR i.MaGV <> d.MaGV OR i.MaPhong <> d.MaPhong))
    BEGIN
        RAISERROR (N'Không được thay đổi thời gian, phòng, giáo viên của buổi đã dạy.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO
