/* =====================================================================
   ĐỒ ÁN IE103 - QUẢN LÝ THÔNG TIN
   Đề tài : Hệ thống quản lý trung tâm tiếng Anh
   File   : 00_create_database.sql - Tạo cơ sở dữ liệu QLTTTA
   Chạy   : bằng tài khoản sysadmin (sa), SQL Server 2012 trở lên
   ===================================================================== */
USE master;
GO

-- 1. Bật xác thực cho CSDL độc lập (contained database authentication).
--    Cho phép tạo user có mật khẩu nằm ngay trong CSDL, không cần login
--    cấp server => backup/restore sang máy khác không bị "orphaned user".
EXEC sp_configure 'contained database authentication', 1;
RECONFIGURE;
GO

-- 2. Xóa CSDL cũ (nếu có) để chạy lại từ đầu
IF DB_ID(N'QLTTTA') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA;
END
GO

-- 3. Tạo CSDL: chế độ độc lập một phần, collation tiếng Việt
--    (sắp xếp/so sánh đúng chữ có dấu: "Đỗ" đứng sau "Dương").
CREATE DATABASE QLTTTA
    CONTAINMENT = PARTIAL
    COLLATE Vietnamese_CI_AS;
GO

-- 4. Mô hình phục hồi FULL để sao lưu được cả transaction log
ALTER DATABASE QLTTTA SET RECOVERY FULL;
GO
