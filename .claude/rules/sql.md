---
paths:
  - "database/**/*.sql"
---
# Quy tắc viết T-SQL (database/)

Bổ sung cho mục "CSDL" trong `CLAUDE.md` (SQL Server 2012+, mẫu DROP/GO, THROW 5xxxx, trigger tập hợp, GRANT).

## Định dạng
- Từ khóa **VIẾT HOA** (`SELECT`, `JOIN`, `BEGIN TRY`), thụt lề **4 dấu cách**, mỗi câu lệnh kết thúc bằng `;`.
- Luôn ghi schema: `dbo.HOCVIEN`, `dbo.usp_GhiDanh`. Chuỗi tiếng Việt luôn có tiền tố `N'...'`.
- Tham số căn cột như mẫu `usp_HocVien_Them`; tham số tùy chọn có `= NULL` ở cuối dòng.
- Mỗi đối tượng mở đầu bằng **một dòng chú thích có mã mục** theo nhóm trong file:
  `/* C4. usp_GhiDanh_HuyLop: hủy ghi danh, hoàn tiền nếu chưa học buổi nào */`.
- Không dùng `SELECT *` trong thủ tục/view (trừ truy vấn minh họa); không dùng `sp_` làm tiền tố.

## Mẫu thủ tục ghi dữ liệu nhiều bước
```sql
/* C4. usp_Xxx_Yyy: <mô tả một dòng> */
IF OBJECT_ID(N'dbo.usp_Xxx_Yyy', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Xxx_Yyy;
GO
CREATE PROCEDURE dbo.usp_Xxx_Yyy
    @MaA     VARCHAR(10),
    @GhiChu  NVARCHAR(200) = NULL,
    @MaMoi   VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Kiểm tra nghiệp vụ trước, báo lỗi tiếng Việt (mã theo dải của nhóm, xem bảng dưới)
    IF NOT EXISTS (SELECT 1 FROM dbo.BANG_A WHERE MaA = @MaA)
        THROW 50024, N'Không tìm thấy ...', 1;

    -- 2. Ghi dữ liệu trong giao dịch
    BEGIN TRY
        BEGIN TRANSACTION;
        ...
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
```
Thủ tục một câu lệnh ghi thì không cần TRY/TRANSACTION (như `usp_HocVien_Them`).

## Dải mã lỗi THROW (mỗi nhóm thủ tục một chục số - chọn số chưa dùng trong dải)
| Nhóm (mục trong 04_procedures.sql) | Dải | | Nhóm | Dải |
|---|---|---|---|---|
| A. Học viên | 50001-50009 | | E. Điểm danh, điểm, xét kết quả | 50040-50049 |
| B. Lớp học, lịch, buổi học | 50010-50019 | | F. Lương | 50050-50059 |
| C. Ghi danh, chuyển lớp | 50020-50029 | | I. Tài khoản | 50060-50069 |
| D. Phiếu thu | 50030-50039 | | I7. Sao lưu | 50070-50079 |
Nhóm mới: dùng dải chục kế tiếp chưa có (50080...). `50099` dành cho `12_kiem_thu.sql`. Trigger dùng
`RAISERROR (N'...', 16, 1); ROLLBACK TRANSACTION;`. Tra số đã dùng: `grep -o "THROW 50[0-9]*" database/04_procedures.sql | sort -u`.

## Mẫu trigger (luôn xử lý TẬP HỢP dòng)
```sql
CREATE TRIGGER dbo.trg_BANG_MucDich
ON dbo.BANG
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(CotLienQuan) RETURN;          -- bỏ qua khi cột liên quan không đổi
    IF EXISTS (SELECT 1 FROM inserted i JOIN ... WHERE <vi phạm>)   -- join với inserted, KHÔNG dùng biến đơn
    BEGIN
        RAISERROR (N'<thông báo tiếng Việt>.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO
```
Cấm: `SELECT @x = Cot FROM inserted` (chỉ lấy được 1 dòng), cursor trong trigger.

## Bắt buộc khi thêm/sửa đối tượng
1. `GRANT` cho đúng role trong `06_security.sql` (role nghiệp vụ không có quyền trên bảng gốc).
2. Ca kiểm thử trong `12_kiem_thu.sql` + đăng ký mã ca và mẫu thông báo trong `#MongDoi` (xem `tests.md`).
3. Chạy lại toàn bộ: `scripts/test_all.sh` (gồm `db_init` từ đầu) - không chỉ chạy riêng file vừa sửa.
4. Nếu đổi số lượng đối tượng/nội dung được trích trong báo cáo: chạy `/imcp-update-report`.
