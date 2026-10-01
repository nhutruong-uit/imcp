/* =====================================================================
   File   : 03_views.sql - Khung nhìn (View)
   - View tổng hợp phục vụ form/báo cáo
   - View bảo mật: giới hạn DÒNG (chỉ lớp của giáo viên đang đăng nhập)
     và CỘT (ẩn SĐT, email, học phí) => phân quyền GRANT trên view
     thay vì trên bảng gốc.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. vw_TaiKhoanHienTai: thông tin người đang đăng nhập (ứng dụng đọc sau login) */
IF OBJECT_ID(N'dbo.vw_TaiKhoanHienTai', N'V') IS NOT NULL DROP VIEW dbo.vw_TaiKhoanHienTai;
GO
CREATE VIEW dbo.vw_TaiKhoanHienTai
AS
SELECT tk.TenDangNhap, tk.VaiTro, tk.MaNV, tk.MaGV, tk.TrangThai,
       COALESCE(nv.HoTen, gv.HoTen) AS HoTen,
       COALESCE(nv.MaCN, gv.MaCN)   AS MaCN
FROM dbo.TAIKHOAN tk
LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = tk.MaNV
LEFT JOIN dbo.GIAOVIEN gv ON gv.MaGV = tk.MaGV
WHERE tk.TenDangNhap = ORIGINAL_LOGIN();
GO

/* 2. vw_HocVien_TongQuan: học viên + số lớp đang học + tổng công nợ */
IF OBJECT_ID(N'dbo.vw_HocVien_TongQuan', N'V') IS NOT NULL DROP VIEW dbo.vw_HocVien_TongQuan;
GO
CREATE VIEW dbo.vw_HocVien_TongQuan
AS
SELECT hv.MaHV, hv.HoTen, hv.NgaySinh, hv.GioiTinh, hv.SoDienThoai, hv.Email,
       hv.TenPhuHuynh, hv.SDTPhuHuynh, hv.MaCN, cn.TenCN, hv.NgayDangKy, hv.TrangThai,
       ISNULL(t.SoLopDangHoc, 0) AS SoLopDangHoc,
       ISNULL(t.TongConNo, 0)    AS TongConNo
FROM dbo.HOCVIEN hv
JOIN dbo.CHINHANH cn ON cn.MaCN = hv.MaCN
LEFT JOIN (
    SELECT MaHV,
           SUM(CASE WHEN TrangThai = N'Đang học' THEN 1 ELSE 0 END) AS SoLopDangHoc,
           SUM(CASE WHEN TrangThai <> N'Đã nghỉ' THEN HocPhiPhaiDong - DaDong ELSE 0 END) AS TongConNo
    FROM dbo.GHIDANH
    GROUP BY MaHV
) t ON t.MaHV = hv.MaHV;
GO

/* 3. vw_LopHoc_ChiTiet: lớp + khóa học + giáo viên + phòng + sĩ số + lịch học */
IF OBJECT_ID(N'dbo.vw_LopHoc_ChiTiet', N'V') IS NOT NULL DROP VIEW dbo.vw_LopHoc_ChiTiet;
GO
CREATE VIEW dbo.vw_LopHoc_ChiTiet
AS
SELECT l.MaLop, l.TenLop, l.MaKH, k.TenKH, k.CapDo, ct.TenCT,
       l.MaCN, cn.TenCN, l.MaGV, gv.HoTen AS TenGV, l.MaPhong, p.TenPhong,
       l.NgayKhaiGiang, l.NgayKetThuc, l.SiSoToiDa,
       ISNULL(ss.SiSo, 0)               AS SiSoHienTai,
       l.SiSoToiDa - ISNULL(ss.SiSo, 0) AS ChoTrong,
       l.HocPhi, l.TrangThai,
       STUFF((SELECT N', ' + CASE lh.Thu WHEN 8 THEN N'CN' ELSE N'T' + CAST(lh.Thu AS NVARCHAR(1)) END
                     + N' ' + LEFT(CONVERT(NVARCHAR(8), lh.GioBatDau, 108), 5)
                     + N'-' + LEFT(CONVERT(NVARCHAR(8), lh.GioKetThuc, 108), 5)
              FROM dbo.LICHHOC lh WHERE lh.MaLop = l.MaLop ORDER BY lh.Thu
              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(200)'), 1, 2, N'') AS LichHoc
FROM dbo.LOPHOC l
JOIN dbo.KHOAHOC k      ON k.MaKH = l.MaKH
JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT
JOIN dbo.CHINHANH cn    ON cn.MaCN = l.MaCN
JOIN dbo.GIAOVIEN gv    ON gv.MaGV = l.MaGV
JOIN dbo.PHONGHOC p     ON p.MaPhong = l.MaPhong
LEFT JOIN (
    SELECT MaLop, COUNT(*) AS SiSo FROM dbo.GHIDANH
    WHERE TrangThai IN (N'Đang học', N'Hoàn thành') GROUP BY MaLop
) ss ON ss.MaLop = l.MaLop;
GO

/* 4. vw_CongNo: các khoản ghi danh còn nợ học phí (dành cho kế toán) */
IF OBJECT_ID(N'dbo.vw_CongNo', N'V') IS NOT NULL DROP VIEW dbo.vw_CongNo;
GO
CREATE VIEW dbo.vw_CongNo
AS
SELECT gd.MaGD, hv.MaHV, hv.HoTen, COALESCE(hv.SoDienThoai, hv.SDTPhuHuynh) AS SoLienLac,
       l.MaLop, l.TenLop, l.MaCN, gd.NgayGhiDanh, gd.HocPhiPhaiDong, gd.DaDong,
       gd.HocPhiPhaiDong - gd.DaDong AS ConNo,
       DATEDIFF(DAY, gd.NgayGhiDanh, CAST(GETDATE() AS DATE)) AS SoNgayTuGhiDanh
FROM dbo.GHIDANH gd
JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
JOIN dbo.LOPHOC l   ON l.MaLop = gd.MaLop
WHERE gd.HocPhiPhaiDong > gd.DaDong AND gd.TrangThai <> N'Đã nghỉ';
GO

/* 5. vw_DoanhThuThang: doanh thu theo tháng và chi nhánh */
IF OBJECT_ID(N'dbo.vw_DoanhThuThang', N'V') IS NOT NULL DROP VIEW dbo.vw_DoanhThuThang;
GO
CREATE VIEW dbo.vw_DoanhThuThang
AS
SELECT YEAR(pt.NgayThu) AS Nam, MONTH(pt.NgayThu) AS Thang, l.MaCN, cn.TenCN,
       COUNT(*) AS SoPhieu, SUM(pt.SoTien) AS DoanhThu
FROM dbo.PHIEUTHU pt
JOIN dbo.GHIDANH gd  ON gd.MaGD = pt.MaGD
JOIN dbo.LOPHOC l    ON l.MaLop = gd.MaLop
JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
WHERE pt.TrangThai = N'Hợp lệ'
GROUP BY YEAR(pt.NgayThu), MONTH(pt.NgayThu), l.MaCN, cn.TenCN;
GO

/* 6. vw_KetQuaHocTap: điểm tổng kết, chuyên cần, xếp loại của từng lượt ghi danh */
IF OBJECT_ID(N'dbo.vw_KetQuaHocTap', N'V') IS NOT NULL DROP VIEW dbo.vw_KetQuaHocTap;
GO
CREATE VIEW dbo.vw_KetQuaHocTap
AS
SELECT gd.MaGD, gd.MaLop, l.TenLop, gd.MaHV, hv.HoTen,
       dbo.fn_TinhDiemTongKet(gd.MaGD)              AS DiemTongKet,
       dbo.fn_XepLoai(dbo.fn_TinhDiemTongKet(gd.MaGD)) AS XepLoai,
       dbo.fn_TyLeChuyenCan(gd.MaGD)                AS TyLeChuyenCan,
       gd.KetQua, gd.TrangThai
FROM dbo.GHIDANH gd
JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
JOIN dbo.LOPHOC l   ON l.MaLop = gd.MaLop;
GO

/* 7. vw_BuoiHoc_ChiTiet: thời khóa biểu chi tiết từng buổi */
IF OBJECT_ID(N'dbo.vw_BuoiHoc_ChiTiet', N'V') IS NOT NULL DROP VIEW dbo.vw_BuoiHoc_ChiTiet;
GO
CREATE VIEW dbo.vw_BuoiHoc_ChiTiet
AS
SELECT b.MaBuoi, b.MaLop, l.TenLop, b.STT, b.NgayHoc, b.GioBatDau, b.GioKetThuc,
       b.MaPhong, p.TenPhong, l.MaCN, b.MaGV, gv.HoTen AS TenGV, b.NoiDung, b.TrangThai
FROM dbo.BUOIHOC b
JOIN dbo.LOPHOC l    ON l.MaLop = b.MaLop
JOIN dbo.PHONGHOC p  ON p.MaPhong = b.MaPhong
JOIN dbo.GIAOVIEN gv ON gv.MaGV = b.MaGV;
GO

/* 8. vw_KhoaHoc_TrongSoChuaHopLe: khóa học có tổng trọng số điểm khác 100%
      (SQL Server không có ràng buộc trì hoãn - deferred constraint - nên
      kiểm tra bằng view + kiểm tra lại trong thủ tục xét kết quả). */
IF OBJECT_ID(N'dbo.vw_KhoaHoc_TrongSoChuaHopLe', N'V') IS NOT NULL DROP VIEW dbo.vw_KhoaHoc_TrongSoChuaHopLe;
GO
CREATE VIEW dbo.vw_KhoaHoc_TrongSoChuaHopLe
AS
SELECT k.MaKH, k.TenKH, ISNULL(SUM(tp.TrongSo), 0) AS TongTrongSo
FROM dbo.KHOAHOC k
LEFT JOIN dbo.THANHPHANDIEM tp ON tp.MaKH = k.MaKH
GROUP BY k.MaKH, k.TenKH
HAVING ISNULL(SUM(tp.TrongSo), 0) <> 100;
GO

/* ===== VIEW BẢO MẬT CHO GIÁO VIÊN (lọc theo người đăng nhập) ===== */

/* 9. vw_GV_LopCuaToi: chỉ các lớp giáo viên đang đăng nhập phụ trách */
IF OBJECT_ID(N'dbo.vw_GV_LopCuaToi', N'V') IS NOT NULL DROP VIEW dbo.vw_GV_LopCuaToi;
GO
CREATE VIEW dbo.vw_GV_LopCuaToi
AS
SELECT l.MaLop, l.TenLop, k.TenKH, p.TenPhong, cn.TenCN, l.NgayKhaiGiang, l.NgayKetThuc,
       l.TrangThai, dbo.fn_SiSoHienTai(l.MaLop) AS SiSo
FROM dbo.LOPHOC l
JOIN dbo.KHOAHOC k   ON k.MaKH = l.MaKH
JOIN dbo.PHONGHOC p  ON p.MaPhong = l.MaPhong
JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
WHERE l.MaGV = dbo.fn_MaGVHienTai();
GO

/* 10. vw_GV_HocVienCuaToi: học viên trong lớp của giáo viên, ẨN SĐT/email/học phí */
IF OBJECT_ID(N'dbo.vw_GV_HocVienCuaToi', N'V') IS NOT NULL DROP VIEW dbo.vw_GV_HocVienCuaToi;
GO
CREATE VIEW dbo.vw_GV_HocVienCuaToi
AS
SELECT gd.MaGD, l.MaLop, l.TenLop, hv.MaHV, hv.HoTen, hv.GioiTinh, gd.TrangThai,
       dbo.fn_TyLeChuyenCan(gd.MaGD) AS TyLeChuyenCan
FROM dbo.GHIDANH gd
JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
JOIN dbo.LOPHOC l   ON l.MaLop = gd.MaLop
WHERE l.MaGV = dbo.fn_MaGVHienTai();
GO

/* 11. vw_GV_LichDayCuaToi: các buổi dạy của giáo viên đang đăng nhập */
IF OBJECT_ID(N'dbo.vw_GV_LichDayCuaToi', N'V') IS NOT NULL DROP VIEW dbo.vw_GV_LichDayCuaToi;
GO
CREATE VIEW dbo.vw_GV_LichDayCuaToi
AS
SELECT b.MaBuoi, b.MaLop, l.TenLop, b.STT, b.NgayHoc, b.GioBatDau, b.GioKetThuc,
       p.TenPhong, b.NoiDung, b.TrangThai
FROM dbo.BUOIHOC b
JOIN dbo.LOPHOC l   ON l.MaLop = b.MaLop
JOIN dbo.PHONGHOC p ON p.MaPhong = b.MaPhong
WHERE b.MaGV = dbo.fn_MaGVHienTai();
GO

/* 12. vw_GV_DiemLopCuaToi: điểm thành phần của học viên trong lớp mình dạy */
IF OBJECT_ID(N'dbo.vw_GV_DiemLopCuaToi', N'V') IS NOT NULL DROP VIEW dbo.vw_GV_DiemLopCuaToi;
GO
CREATE VIEW dbo.vw_GV_DiemLopCuaToi
AS
SELECT gd.MaGD, l.MaLop, hv.MaHV, hv.HoTen, tp.MaTP, tp.TenTP, tp.TrongSo, d.Diem
FROM dbo.GHIDANH gd
JOIN dbo.HOCVIEN hv       ON hv.MaHV = gd.MaHV
JOIN dbo.LOPHOC l         ON l.MaLop = gd.MaLop
JOIN dbo.THANHPHANDIEM tp ON tp.MaKH = l.MaKH
LEFT JOIN dbo.DIEM d      ON d.MaGD = gd.MaGD AND d.MaTP = tp.MaTP
WHERE l.MaGV = dbo.fn_MaGVHienTai();
GO

/* 13. vw_GV_LuongCuaToi: bảng lương của chính giáo viên đang đăng nhập */
IF OBJECT_ID(N'dbo.vw_GV_LuongCuaToi', N'V') IS NOT NULL DROP VIEW dbo.vw_GV_LuongCuaToi;
GO
CREATE VIEW dbo.vw_GV_LuongCuaToi
AS
SELECT Thang, Nam, SoBuoi, SoGio, DonGiaGio, Thuong, KhauTru, TongLuong, TrangThai
FROM dbo.BANGLUONG
WHERE MaGV = dbo.fn_MaGVHienTai();
GO
