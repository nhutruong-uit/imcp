/* =====================================================================
   File   : 06_security.sql - Xác thực & phân quyền
   Mô hình:
     - Mỗi tài khoản ứng dụng = 1 USER có mật khẩu trong CSDL độc lập
       (contained database user) => SQL Server tự xác thực, mật khẩu được
       băm và quản lý bởi DBMS, không lưu trong bảng của ứng dụng.
     - 4 ROLE theo vai trò nghiệp vụ; quyền GRANT cho ROLE, không cho user.
     - Nguyên tắc đặc quyền tối thiểu: role nghiệp vụ KHÔNG có quyền trên
       bảng gốc, chỉ EXECUTE thủ tục và SELECT view. Nhờ "ownership chaining"
       (view/thủ tục và bảng cùng chủ sở hữu dbo), người dùng truy cập dữ
       liệu được qua view/thủ tục mà không cần quyền trên bảng.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. Tạo ROLE */
IF DATABASE_PRINCIPAL_ID('rl_QuanLy')   IS NULL CREATE ROLE rl_QuanLy   AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_GiaoVu')   IS NULL CREATE ROLE rl_GiaoVu   AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_KeToan')   IS NULL CREATE ROLE rl_KeToan   AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_GiaoVien') IS NULL CREATE ROLE rl_GiaoVien AUTHORIZATION dbo;
GO

/* 2. Quyền chung cho mọi người dùng đã đăng nhập */
GRANT SELECT  ON dbo.vw_TaiKhoanHienTai           TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_TaiKhoan_GhiNhanDangNhap TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_TaiKhoan_DoiMatKhau      TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
-- Danh mục dùng cho combobox (không chứa dữ liệu nhạy cảm)
GRANT SELECT ON dbo.CHINHANH    TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
GRANT SELECT ON dbo.CHUONGTRINH TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
GRANT SELECT ON dbo.KHOAHOC     TO rl_QuanLy, rl_GiaoVu, rl_KeToan, rl_GiaoVien;
GRANT SELECT ON dbo.PHONGHOC    TO rl_QuanLy, rl_GiaoVu, rl_GiaoVien;
GO

/* 3. QUẢN LÝ: toàn quyền nghiệp vụ, quản trị tài khoản, sao lưu */
ALTER ROLE db_datareader ADD MEMBER rl_QuanLy;
GRANT EXECUTE ON SCHEMA::dbo TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.CHINHANH      TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.PHONGHOC      TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.CHUONGTRINH   TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.KHOAHOC       TO rl_QuanLy;
GRANT INSERT, UPDATE, DELETE ON dbo.THANHPHANDIEM TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.NHANVIEN      TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.GIAOVIEN      TO rl_QuanLy;
GRANT INSERT, UPDATE ON dbo.KHUYENMAI     TO rl_QuanLy;
-- Kể cả quản lý cũng không được sửa nhật ký và xóa chứng từ
DENY UPDATE, DELETE ON dbo.NHATKYHETHONG TO rl_QuanLy;
DENY DELETE ON dbo.PHIEUTHU TO rl_QuanLy;
GO

/* 4. GIÁO VỤ: học viên, lớp, lịch, ghi danh, kiểm tra đầu vào */
GRANT SELECT ON dbo.vw_HocVien_TongQuan   TO rl_GiaoVu;
GRANT SELECT ON dbo.vw_LopHoc_ChiTiet     TO rl_GiaoVu;
GRANT SELECT ON dbo.vw_BuoiHoc_ChiTiet    TO rl_GiaoVu;
GRANT SELECT ON dbo.vw_KetQuaHocTap       TO rl_GiaoVu;
GRANT SELECT ON dbo.vw_CongNo             TO rl_GiaoVu;
GRANT SELECT ON dbo.GIAOVIEN (MaGV, HoTen, LoaiGV, QuocTich, TrinhDo, MaCN, TrangThai) TO rl_GiaoVu; -- phân quyền mức CỘT: không thấy đơn giá giờ
GRANT SELECT ON dbo.KHUYENMAI             TO rl_GiaoVu;
GRANT SELECT ON dbo.THANHPHANDIEM         TO rl_GiaoVu;
GRANT SELECT ON dbo.KIEMTRADAUVAO         TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_Them              TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_CapNhat           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_Xoa               TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_TimKiem           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_ChiTiet           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_XuatXML           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_HocVien_NhapXML           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_LopHoc_Tao                TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_LichHoc_Them              TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_LopHoc_TaoBuoiHoc         TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_LopHoc_CapNhatTrangThai   TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_LopHoc_XetKetQua          TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_BuoiHoc_CapNhat           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_GhiDanh                   TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_GhiDanh_ChuyenLop         TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_GhiDanh_CapNhatTrangThai  TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_GhiDanh_TheoLop           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_KiemTraDauVao_Them        TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_DiemDanh_TheoBuoi         TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_DiemDanh_Luu              TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_Diem_Luu                  TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_KhoaHoc_TimTheoKyNang     TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_KhoaHoc_DeCuong           TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_GiaoVien_TimTheoChungChi  TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_ThongKe_TongQuan          TO rl_GiaoVu;
GRANT EXECUTE ON dbo.usp_BaoCao_KetQuaLop          TO rl_GiaoVu;
GRANT SELECT  ON dbo.fn_LichDayGiaoVien            TO rl_GiaoVu;
-- Giáo vụ không được xem lương, không được thu tiền
DENY SELECT ON dbo.BANGLUONG TO rl_GiaoVu;
DENY EXECUTE ON dbo.usp_PhieuThu_Tao TO rl_GiaoVu;
GO

/* 5. KẾ TOÁN: học phí, công nợ, doanh thu, lương */
GRANT SELECT ON dbo.vw_CongNo             TO rl_KeToan;
GRANT SELECT ON dbo.vw_DoanhThuThang      TO rl_KeToan;
GRANT SELECT ON dbo.vw_LopHoc_ChiTiet     TO rl_KeToan;
GRANT SELECT ON dbo.vw_HocVien_TongQuan   TO rl_KeToan;
GRANT SELECT ON dbo.KHUYENMAI             TO rl_KeToan;
GRANT SELECT ON dbo.PHIEUTHU              TO rl_KeToan;
GRANT SELECT ON dbo.BANGLUONG             TO rl_KeToan;
GRANT SELECT ON dbo.GIAOVIEN (MaGV, HoTen, LoaiGV, DonGiaGio, MaCN, TrangThai) TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_HocVien_TimKiem      TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_GhiDanh_TheoLop      TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_PhieuThu_Tao         TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_PhieuThu_Huy         TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_PhieuThu_InBienLai   TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_BangLuong_Chot       TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_BaoCao_DoanhThu      TO rl_KeToan;
GRANT EXECUTE ON dbo.usp_ThongKe_TongQuan     TO rl_KeToan;
GRANT SELECT  ON dbo.fn_DoanhThuTheoThang     TO rl_KeToan;
GRANT SELECT  ON dbo.fn_CongNoHocVien         TO rl_KeToan;
-- Kế toán không được sửa điểm, không được ghi danh
DENY EXECUTE ON dbo.usp_Diem_Luu TO rl_KeToan;
DENY EXECUTE ON dbo.usp_GhiDanh  TO rl_KeToan;
GO

/* 6. GIÁO VIÊN: chỉ dữ liệu lớp mình dạy (qua view lọc theo người đăng nhập) */
GRANT SELECT ON dbo.vw_GV_LopCuaToi       TO rl_GiaoVien;
GRANT SELECT ON dbo.vw_GV_HocVienCuaToi   TO rl_GiaoVien;
GRANT SELECT ON dbo.vw_GV_LichDayCuaToi   TO rl_GiaoVien;
GRANT SELECT ON dbo.vw_GV_DiemLopCuaToi   TO rl_GiaoVien;
GRANT SELECT ON dbo.vw_GV_LuongCuaToi     TO rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_BuoiHoc_CapNhat      TO rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_DiemDanh_TheoBuoi    TO rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_DiemDanh_Luu         TO rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_Diem_Luu             TO rl_GiaoVien;
GRANT EXECUTE ON dbo.usp_KhoaHoc_DeCuong      TO rl_GiaoVien;
-- Chặn tường minh dữ liệu nhạy cảm (DENY ưu tiên hơn GRANT)
DENY SELECT ON dbo.HOCVIEN   TO rl_GiaoVien;
DENY SELECT ON dbo.PHIEUTHU  TO rl_GiaoVien;
DENY SELECT ON dbo.BANGLUONG TO rl_GiaoVien;
GO

/* 7. Tài khoản mẫu (mật khẩu demo ghi trong docs/SETUP.md, đổi ngay khi triển khai thật).
      Hồ sơ NHANVIEN/GIAOVIEN tương ứng được tạo trong 07_seed_data.sql,
      vì vậy phần tạo tài khoản được gọi ở cuối file seed. */
