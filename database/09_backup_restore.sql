/* =====================================================================
   File   : 09_backup_restore.sql - Sao lưu & phục hồi
   Chiến lược đề xuất cho trung tâm:
     - FULL      : 1 lần/tuần (Chủ nhật 23:00)
     - DIFFERENTIAL: mỗi đêm (23:00)
     - LOG       : mỗi 30 phút trong giờ làm việc
     => mất dữ liệu tối đa 30 phút (RPO), phục hồi = FULL + DIFF gần nhất + các LOG sau đó.
   Đường dẫn bên dưới dành cho SQL Server trên Docker/Linux; trên Windows đổi
   thành dạng 'C:\Backup\...'. Chạy bằng tài khoản sa / db_owner.
   ===================================================================== */
USE master;
GO

DECLARE @ThuMuc NVARCHAR(200) = N'/var/opt/mssql/data/';   -- Windows: N'C:\Backup\'
DECLARE @Full NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_full.bak',
        @Diff NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_diff.bak',
        @Log  NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_log.trn';

/* 1. Sao lưu toàn phần (FULL) - kèm CHECKSUM để phát hiện hỏng trang */
BACKUP DATABASE QLTTTA TO DISK = @Full
WITH INIT, CHECKSUM, NAME = N'QLTTTA - Full', STATS = 25;

/* Mô phỏng phát sinh dữ liệu sau FULL */
INSERT INTO QLTTTA.dbo.KHUYENMAI (MaKM, TenKM, LoaiGiam, GiaTri, NgayBatDau, NgayKetThuc)
VALUES ('KM-DEMO', N'Khuyến mãi demo sao lưu', 'SOTIEN', 200000, CAST(GETDATE() AS DATE), DATEADD(DAY, 7, CAST(GETDATE() AS DATE)));

/* 2. Sao lưu vi sai (DIFFERENTIAL): chỉ các extent thay đổi kể từ FULL gần nhất */
BACKUP DATABASE QLTTTA TO DISK = @Diff
WITH DIFFERENTIAL, INIT, CHECKSUM, NAME = N'QLTTTA - Differential';

/* 3. Sao lưu nhật ký giao dịch (LOG) - yêu cầu RECOVERY FULL */
UPDATE QLTTTA.dbo.KHUYENMAI SET GiaTri = 300000 WHERE MaKM = 'KM-DEMO';
BACKUP LOG QLTTTA TO DISK = @Log
WITH INIT, CHECKSUM, NAME = N'QLTTTA - Log';

/* 4. Kiểm tra bản sao lưu */
RESTORE VERIFYONLY FROM DISK = @Full WITH CHECKSUM;
RESTORE HEADERONLY FROM DISK = @Full;
RESTORE FILELISTONLY FROM DISK = @Full;
GO

/* 5. Phục hồi theo chuỗi FULL -> DIFF -> LOG sang một CSDL MỚI (QLTTTA_KhoiPhuc)
      để không ảnh hưởng CSDL đang chạy. MOVE đổi tên file vật lý. */
DECLARE @ThuMuc NVARCHAR(200) = N'/var/opt/mssql/data/';
DECLARE @Full NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_full.bak',
        @Diff NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_diff.bak',
        @Log  NVARCHAR(300) = @ThuMuc + N'QLTTTA_demo_log.trn',
        @Mdf  NVARCHAR(300) = @ThuMuc + N'QLTTTA_KhoiPhuc.mdf',
        @Ldf  NVARCHAR(300) = @ThuMuc + N'QLTTTA_KhoiPhuc_log.ldf';

IF DB_ID(N'QLTTTA_KhoiPhuc') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA_KhoiPhuc SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA_KhoiPhuc;
END;

RESTORE DATABASE QLTTTA_KhoiPhuc FROM DISK = @Full
WITH MOVE N'QLTTTA' TO @Mdf, MOVE N'QLTTTA_log' TO @Ldf, NORECOVERY, REPLACE;

RESTORE DATABASE QLTTTA_KhoiPhuc FROM DISK = @Diff WITH NORECOVERY;

RESTORE LOG QLTTTA_KhoiPhuc FROM DISK = @Log WITH RECOVERY;   -- RECOVERY: đưa CSDL về trạng thái dùng được
GO

/* 6. Đối chiếu: bản phục hồi có dữ liệu phát sinh sau FULL (nhờ DIFF + LOG).
      User độc lập (contained user) đi theo CSDL nên đăng nhập được ngay,
      không bị "orphaned user" như user gắn với login cấp server. */
SELECT 'QLTTTA' AS CSDL, MaKM, GiaTri FROM QLTTTA.dbo.KHUYENMAI WHERE MaKM = 'KM-DEMO'
UNION ALL
SELECT 'QLTTTA_KhoiPhuc', MaKM, GiaTri FROM QLTTTA_KhoiPhuc.dbo.KHUYENMAI WHERE MaKM = 'KM-DEMO';

SELECT name, type_desc, authentication_type_desc
FROM QLTTTA_KhoiPhuc.sys.database_principals
WHERE authentication_type_desc = 'DATABASE';
GO

/* 7. Lịch sử sao lưu (msdb) */
SELECT TOP (10) bs.database_name, bs.type AS Loai,      -- D = Full, I = Differential, L = Log
       bs.backup_start_date, bs.backup_finish_date,
       CAST(bs.backup_size / 1024.0 / 1024 AS DECIMAL(10,2)) AS KichThuocMB, bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'QLTTTA'
ORDER BY bs.backup_finish_date DESC;
GO

/* 8. Dọn dữ liệu demo */
DELETE FROM QLTTTA.dbo.KHUYENMAI WHERE MaKM = 'KM-DEMO';
IF DB_ID(N'QLTTTA_KhoiPhuc') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA_KhoiPhuc SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA_KhoiPhuc;
END;
GO
