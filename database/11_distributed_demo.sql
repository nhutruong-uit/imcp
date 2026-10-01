/* =====================================================================
   File   : 11_distributed_demo.sql - Minh họa CSDL PHÂN TÁN theo chi nhánh
   Ý tưởng (Chương 5 - CSDL phân tán):
     - Phân mảnh NGANG CHÍNH bảng HOCVIEN theo MaCN: mỗi chi nhánh giữ
       học viên của mình tại "trạm" (site) riêng.
     - Phân mảnh NGANG DẪN XUẤT: GHIDANH/PHIEUTHU đi theo lớp của chi nhánh.
     - NHÂN BẢN (replication) bảng danh mục ít thay đổi: CHUONGTRINH, KHOAHOC.
     - Trong suốt phân tán: view gộp UNION ALL (distributed partitioned view),
       CHECK (MaCN = ...) giúp bộ tối ưu chỉ đọc đúng mảnh cần thiết.
   Demo trên 1 máy chủ bằng 2 CSDL; thực tế mỗi CSDL nằm trên 1 server,
   view tham chiếu qua Linked Server: [SRV_TD].QLTTTA_CN02.dbo.HOCVIEN
   ===================================================================== */
USE master;
GO
IF DB_ID(N'QLTTTA_CN01') IS NOT NULL BEGIN ALTER DATABASE QLTTTA_CN01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE QLTTTA_CN01; END;
IF DB_ID(N'QLTTTA_CN02') IS NOT NULL BEGIN ALTER DATABASE QLTTTA_CN02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE QLTTTA_CN02; END;
CREATE DATABASE QLTTTA_CN01 COLLATE Vietnamese_CI_AS;
CREATE DATABASE QLTTTA_CN02 COLLATE Vietnamese_CI_AS;
GO

/* 1. Mảnh HOCVIEN_CN01 = σ(MaCN = 'CN01')(HOCVIEN) tại trạm Quận 1 */
USE QLTTTA_CN01;
GO
CREATE TABLE dbo.HOCVIEN (
    MaHV VARCHAR(10) NOT NULL PRIMARY KEY, HoTen NVARCHAR(100) NOT NULL, NgaySinh DATE NOT NULL,
    SoDienThoai VARCHAR(15) NULL, TrangThai NVARCHAR(20) NOT NULL,
    MaCN VARCHAR(10) NOT NULL CONSTRAINT CK_HOCVIEN_MaCN CHECK (MaCN = 'CN01'));
INSERT INTO dbo.HOCVIEN SELECT MaHV, HoTen, NgaySinh, SoDienThoai, TrangThai, MaCN FROM QLTTTA.dbo.HOCVIEN WHERE MaCN = 'CN01';
-- Nhân bản danh mục khóa học tại mọi trạm
SELECT MaKH, TenKH, CapDo, HocPhi INTO dbo.KHOAHOC FROM QLTTTA.dbo.KHOAHOC;
GO

/* 2. Mảnh HOCVIEN_CN02 = σ(MaCN = 'CN02')(HOCVIEN) tại trạm Thủ Đức */
USE QLTTTA_CN02;
GO
CREATE TABLE dbo.HOCVIEN (
    MaHV VARCHAR(10) NOT NULL PRIMARY KEY, HoTen NVARCHAR(100) NOT NULL, NgaySinh DATE NOT NULL,
    SoDienThoai VARCHAR(15) NULL, TrangThai NVARCHAR(20) NOT NULL,
    MaCN VARCHAR(10) NOT NULL CONSTRAINT CK_HOCVIEN_MaCN CHECK (MaCN = 'CN02'));
INSERT INTO dbo.HOCVIEN SELECT MaHV, HoTen, NgaySinh, SoDienThoai, TrangThai, MaCN FROM QLTTTA.dbo.HOCVIEN WHERE MaCN = 'CN02';
SELECT MaKH, TenKH, CapDo, HocPhi INTO dbo.KHOAHOC FROM QLTTTA.dbo.KHOAHOC;
GO

/* 3. Trạm trung tâm: view phân tán gộp các mảnh (tái thiết HOCVIEN = CN01 ∪ CN02) */
USE QLTTTA_CN01;
GO
CREATE VIEW dbo.vw_HocVien_ToanHeThong
AS
SELECT MaHV, HoTen, NgaySinh, SoDienThoai, TrangThai, MaCN FROM QLTTTA_CN01.dbo.HOCVIEN
UNION ALL
SELECT MaHV, HoTen, NgaySinh, SoDienThoai, TrangThai, MaCN FROM QLTTTA_CN02.dbo.HOCVIEN;
GO

/* 4. Kiểm tra tính đúng đắn của phân mảnh:
      - Đầy đủ (completeness): tổng số dòng các mảnh = bảng gốc
      - Tách biệt (disjointness): không MaHV nào nằm ở 2 mảnh
      - Tái thiết (reconstruction): UNION ALL các mảnh = bảng gốc */
SELECT (SELECT COUNT(*) FROM QLTTTA.dbo.HOCVIEN) AS BangGoc,
       (SELECT COUNT(*) FROM QLTTTA_CN01.dbo.HOCVIEN) AS ManhCN01,
       (SELECT COUNT(*) FROM QLTTTA_CN02.dbo.HOCVIEN) AS ManhCN02,
       (SELECT COUNT(*) FROM dbo.vw_HocVien_ToanHeThong) AS TaiThiet,
       (SELECT COUNT(*) FROM QLTTTA_CN01.dbo.HOCVIEN a JOIN QLTTTA_CN02.dbo.HOCVIEN b ON a.MaHV = b.MaHV) AS TrungLap;

/* 5. Truy vấn có điều kiện MaCN: xem Execution Plan (Ctrl+M trong SSMS) sẽ thấy
      chỉ mảnh CN02 được quét nhờ CHECK constraint (partition elimination). */
SELECT MaHV, HoTen FROM dbo.vw_HocVien_ToanHeThong WHERE MaCN = 'CN02';
GO
