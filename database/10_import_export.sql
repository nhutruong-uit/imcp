/* =====================================================================
   File   : 10_import_export.sql - Nhập / xuất dữ liệu
   Các cách được minh họa:
     1. Xuất XML bằng FOR XML (thủ tục usp_HocVien_XuatXML)
     2. Nhập XML bằng .nodes() (thủ tục usp_HocVien_NhapXML)
     3. BULK INSERT từ file CSV
     4. bcp / sqlcmd (dòng lệnh) - xuất CSV
     5. Ứng dụng Qt: xuất Excel/CSV/PDF từ màn hình danh sách & báo cáo
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. XUẤT XML: danh sách học viên chi nhánh Thủ Đức */
EXEC dbo.usp_HocVien_XuatXML @MaCN = 'CN02';
GO

/* 2. NHẬP XML: dữ liệu từ hệ thống khác / file xuất ở trên (trong giao dịch demo rồi hoàn tác) */
BEGIN TRANSACTION;
EXEC dbo.usp_HocVien_NhapXML @MaCN = 'CN02', @DuLieu = N'
<DanhSachHocVien>
  <HocVien><HoTen>Phạm Gia Hân</HoTen><NgaySinh>2001-04-12</NgaySinh><GioiTinh>Nữ</GioiTinh>
           <SoDienThoai>0909555001</SoDienThoai><Email>han.pg@gmail.com</Email></HocVien>
  <HocVien><HoTen>Trần Quốc Việt</HoTen><NgaySinh>1999-09-02</NgaySinh><GioiTinh>Nam</GioiTinh>
           <SoDienThoai>0909555002</SoDienThoai></HocVien>
  <HocVien><HoTen>Nguyễn Văn An (trùng SĐT - bị bỏ qua)</HoTen><NgaySinh>2004-03-12</NgaySinh>
           <SoDienThoai>0901000001</SoDienThoai></HocVien>
</DanhSachHocVien>';
SELECT TOP (3) MaHV, HoTen, SoDienThoai FROM dbo.HOCVIEN ORDER BY MaHV DESC;
ROLLBACK TRANSACTION;
GO

/* 3. BULK INSERT từ CSV Unicode (UTF-16 LE, có dòng tiêu đề) vào bảng tạm rồi đưa vào HOCVIEN.
      DATAFILETYPE = 'widechar' đọc đúng tiếng Việt trên cả Windows lẫn Linux, mọi phiên bản.
      (Excel: File > Save As > "Unicode Text"; hoặc chuyển UTF-8 sang UTF-16 bằng Notepad++/iconv)
      File mẫu: database/samples/hocvien_import.csv (chép vào máy chủ SQL trước khi chạy:
      docker cp database/samples/hocvien_import.csv <container>:/var/opt/mssql/data/) */
IF OBJECT_ID('tempdb..#HocVienCSV') IS NOT NULL DROP TABLE #HocVienCSV;
CREATE TABLE #HocVienCSV (
    HoTen NVARCHAR(100), NgaySinh DATE, GioiTinh NVARCHAR(5), SoDienThoai VARCHAR(15), Email VARCHAR(100), MaCN VARCHAR(10));

BEGIN TRY
    BULK INSERT #HocVienCSV
    FROM '/var/opt/mssql/data/hocvien_import.csv'        -- Windows: 'C:\Data\hocvien_import.csv'
    WITH (DATAFILETYPE = 'widechar', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

    SELECT HoTen, NgaySinh, GioiTinh, SoDienThoai, NULLIF(Email, '') AS Email, MaCN FROM #HocVienCSV;
    -- Đưa vào bảng chính qua thủ tục để kiểm tra nghiệp vụ (ở đây chỉ minh họa nên không commit):
    -- INSERT INTO dbo.HOCVIEN (HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, MaCN) SELECT ... FROM #HocVienCSV;
END TRY
BEGIN CATCH
    PRINT N'Chưa có file CSV trên máy chủ SQL: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 4. Dòng lệnh (chạy trong terminal, không chạy trong SSMS):

   -- Xuất bảng công nợ ra CSV bằng sqlcmd
   sqlcmd -S localhost -d QLTTTA -U kt_minh -P "<mật khẩu>" -C -s"," -W -f 65001 \
          -Q "SET NOCOUNT ON; SELECT MaGD, HoTen, TenLop, ConNo FROM dbo.vw_CongNo" -o congno.csv

   -- Xuất/nhập nhanh cả bảng bằng bcp (định dạng ký tự Unicode -w)
   bcp QLTTTA.dbo.KHOAHOC out khoahoc.dat -S localhost -U sa -P "<mật khẩu>" -w -u
   bcp QLTTTA.dbo.KHOAHOC_COPY in khoahoc.dat -S localhost -U sa -P "<mật khẩu>" -w -u

   -- SSMS: chuột phải CSDL > Tasks > Import Data / Export Data (Import/Export Wizard)
*/
