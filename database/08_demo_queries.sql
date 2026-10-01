/* =====================================================================
   File   : 08_demo_queries.sql - Truy vấn minh họa (dùng khi báo cáo/vấn đáp)
   Chạy từng câu trong SSMS / VS Code (mssql) để trình bày kết quả.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ===================== PHẦN A. TRUY VẤN SQL ===================== */

-- Q1. (Kết nhiều bảng) Danh sách lớp đang học: khóa học, giáo viên, phòng, sĩ số
SELECT l.MaLop, l.TenLop, k.TenKH, gv.HoTen AS GiaoVien, p.TenPhong, cn.TenCN,
       dbo.fn_SiSoHienTai(l.MaLop) AS SiSo, l.SiSoToiDa
FROM dbo.LOPHOC l
JOIN dbo.KHOAHOC k   ON k.MaKH = l.MaKH
JOIN dbo.GIAOVIEN gv ON gv.MaGV = l.MaGV
JOIN dbo.PHONGHOC p  ON p.MaPhong = l.MaPhong
JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
WHERE l.TrangThai = N'Đang học'
ORDER BY cn.TenCN, l.NgayKhaiGiang;

-- Q2. (GROUP BY + HAVING) Chương trình có doanh thu trên 50 triệu
SELECT ct.TenCT, COUNT(DISTINCT gd.MaHV) AS SoHocVien, SUM(pt.SoTien) AS DoanhThu
FROM dbo.PHIEUTHU pt
JOIN dbo.GHIDANH gd     ON gd.MaGD = pt.MaGD
JOIN dbo.LOPHOC l       ON l.MaLop = gd.MaLop
JOIN dbo.KHOAHOC k      ON k.MaKH = l.MaKH
JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT
WHERE pt.TrangThai = N'Hợp lệ'
GROUP BY ct.TenCT
HAVING SUM(pt.SoTien) > 50000000
ORDER BY DoanhThu DESC;

-- Q3. (Truy vấn lồng + NOT EXISTS) Học viên đã kiểm tra đầu vào nhưng chưa ghi danh lớp nào
SELECT hv.MaHV, hv.HoTen, kt.DiemTong, k.TenKH AS KhoaDeXuat
FROM dbo.HOCVIEN hv
JOIN dbo.KIEMTRADAUVAO kt ON kt.MaHV = hv.MaHV
LEFT JOIN dbo.KHOAHOC k   ON k.MaKH = kt.MaKHDeXuat
WHERE NOT EXISTS (SELECT 1 FROM dbo.GHIDANH gd WHERE gd.MaHV = hv.MaHV);

-- Q4. (Phép chia quan hệ) Học viên đã học qua TẤT CẢ khóa học của chương trình IELTS
--      đang có lớp mở (không tồn tại khóa IELTS nào mà học viên chưa ghi danh)
SELECT hv.MaHV, hv.HoTen
FROM dbo.HOCVIEN hv
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.KHOAHOC k
    WHERE k.MaCT = 'IELTS' AND EXISTS (SELECT 1 FROM dbo.LOPHOC l WHERE l.MaKH = k.MaKH AND l.TrangThai <> N'Đang tuyển sinh')
      AND NOT EXISTS (SELECT 1 FROM dbo.GHIDANH gd JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
                      WHERE gd.MaHV = hv.MaHV AND l.MaKH = k.MaKH));

-- Q5. (CTE + hàm cửa sổ) Top 3 học viên điểm cao nhất mỗi lớp đã kết thúc
WITH XepHang AS (
    SELECT gd.MaLop, hv.HoTen, gd.DiemTongKet,
           DENSE_RANK() OVER (PARTITION BY gd.MaLop ORDER BY gd.DiemTongKet DESC) AS Hang
    FROM dbo.GHIDANH gd JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
    WHERE gd.DiemTongKet IS NOT NULL
)
SELECT MaLop, Hang, HoTen, DiemTongKet FROM XepHang WHERE Hang <= 3 ORDER BY MaLop, Hang;

-- Q6. (Hàm cửa sổ tích lũy) Doanh thu từng tháng và lũy kế trong năm
SELECT Thang, DoanhThu,
       SUM(DoanhThu) OVER (ORDER BY Thang ROWS UNBOUNDED PRECEDING) AS LuyKe
FROM dbo.fn_DoanhThuTheoThang(YEAR(GETDATE()), NULL)
ORDER BY Thang;

-- Q7. (PIVOT) Số học viên theo chương trình x chi nhánh
SELECT TenCT, ISNULL([CN01], 0) AS [Quận 1], ISNULL([CN02], 0) AS [Thủ Đức]
FROM (
    SELECT ct.TenCT, l.MaCN, gd.MaHV
    FROM dbo.GHIDANH gd
    JOIN dbo.LOPHOC l       ON l.MaLop = gd.MaLop
    JOIN dbo.KHOAHOC k      ON k.MaKH = l.MaKH
    JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT
) src
PIVOT (COUNT(MaHV) FOR MaCN IN ([CN01], [CN02])) pv;

-- Q8. (Truy vấn đệ quy) Lộ trình khóa học tiên quyết từ khóa IELTS 6.5 ngược về gốc
WITH LoTrinh AS (
    SELECT MaKH, TenKH, MaKHTienQuyet, 0 AS Cap FROM dbo.KHOAHOC WHERE MaKH = 'IE-65'
    UNION ALL
    SELECT k.MaKH, k.TenKH, k.MaKHTienQuyet, lt.Cap + 1
    FROM dbo.KHOAHOC k JOIN LoTrinh lt ON k.MaKH = lt.MaKHTienQuyet
)
SELECT Cap, MaKH, TenKH FROM LoTrinh ORDER BY Cap DESC;

-- Q9. Giáo viên dạy nhiều giờ nhất tháng trước (dùng inline TVF)
SELECT TOP (3) gv.MaGV, gv.HoTen, COUNT(*) AS SoBuoi
FROM dbo.GIAOVIEN gv
CROSS APPLY dbo.fn_LichDayGiaoVien(gv.MaGV, DATEADD(MONTH, -1, DATEADD(DAY, 1 - DAY(GETDATE()), CAST(GETDATE() AS DATE))),
                                   DATEADD(DAY, -DAY(GETDATE()), CAST(GETDATE() AS DATE))) ld
WHERE ld.TrangThai = N'Đã dạy'
GROUP BY gv.MaGV, gv.HoTen
ORDER BY SoBuoi DESC;

-- Q10. Học viên có tỷ lệ chuyên cần dưới 85% ở lớp đang học (cảnh báo)
SELECT * FROM dbo.vw_KetQuaHocTap
WHERE TrangThai = N'Đang học' AND TyLeChuyenCan < 85
ORDER BY TyLeChuyenCan;

/* ===================== PHẦN B. XPATH / XQUERY ===================== */

-- X1. .value(): giáo trình đầu tiên và mục tiêu của từng khóa học
SELECT MaKH, TenKH,
       NoiDungXML.value('(/DeCuong/GiaoTrinh)[1]', 'NVARCHAR(200)')   AS GiaoTrinh,
       NoiDungXML.value('(/DeCuong/GiaoTrinh/@NamXB)[1]', 'INT')      AS NamXB,
       NoiDungXML.value('(/DeCuong/MucTieu)[1]', 'NVARCHAR(300)')     AS MucTieu
FROM dbo.KHOAHOC
WHERE NoiDungXML IS NOT NULL;

-- X2. .query(): lấy nguyên các Unit luyện Speaking dưới dạng XML
SELECT MaKH, NoiDungXML.query('/DeCuong/Unit[KyNang = "Speaking"]') AS UnitSpeaking
FROM dbo.KHOAHOC WHERE NoiDungXML IS NOT NULL;

-- X3. .exist(): giáo viên có IELTS từ 8.0 trở lên
SELECT MaGV, HoTen,
       HoSoXML.value('(/HoSo/ChungChi[@Loai = "IELTS"]/@Diem)[1]', 'DECIMAL(3,1)') AS IELTS
FROM dbo.GIAOVIEN
WHERE HoSoXML.exist('/HoSo/ChungChi[@Loai = "IELTS" and @Diem >= 8.0]') = 1;

-- X4. .nodes() + CROSS APPLY: tách mọi chứng chỉ của giáo viên thành bảng quan hệ
SELECT gv.MaGV, gv.HoTen,
       c.value('@Loai', 'NVARCHAR(30)')  AS ChungChi,
       c.value('@Diem', 'DECIMAL(5,1)')  AS Diem,
       c.value('@Nam', 'INT')            AS Nam
FROM dbo.GIAOVIEN gv
CROSS APPLY gv.HoSoXML.nodes('/HoSo/ChungChi') AS T(c)
ORDER BY gv.MaGV, Nam;

-- X5. FLWOR: các Unit có từ 6 buổi, sắp xếp giảm dần số buổi, dựng lại XML mới
SELECT MaKH,
       NoiDungXML.query('
           for $u in /DeCuong/Unit
           where $u/@SoBuoi >= 6
           order by $u/@SoBuoi descending
           return <Unit ma="{data($u/@So)}" buoi="{data($u/@SoBuoi)}">{data($u/TenUnit)}</Unit>') AS UnitDai
FROM dbo.KHOAHOC WHERE NoiDungXML IS NOT NULL;

-- X6. Kiểm tra nhất quán XML - quan hệ: tổng số buổi các Unit = KHOAHOC.SoBuoi
SELECT MaKH, SoBuoi,
       NoiDungXML.value('sum(/DeCuong/Unit/@SoBuoi)', 'INT') AS TongBuoiTrongDeCuong,
       CASE WHEN SoBuoi = NoiDungXML.value('sum(/DeCuong/Unit/@SoBuoi)', 'INT') THEN N'Khớp' ELSE N'Lệch' END AS KiemTra
FROM dbo.KHOAHOC WHERE NoiDungXML IS NOT NULL;

-- X7. .modify(): thêm chứng chỉ mới vào hồ sơ giáo viên (XML DML) - chạy trong giao dịch rồi hoàn tác
BEGIN TRANSACTION;
UPDATE dbo.GIAOVIEN
SET HoSoXML.modify('insert <ChungChi Loai="CELTA" Nam="2026"/> as last into (/HoSo)[1]')
WHERE MaGV = 'GV0003';
SELECT HoSoXML FROM dbo.GIAOVIEN WHERE MaGV = 'GV0003';
ROLLBACK TRANSACTION;

-- X8. FOR XML RAW / PATH: xuất danh sách lớp kèm học viên (cấu trúc lồng nhau)
SELECT l.MaLop AS '@MaLop', l.TenLop AS 'TenLop',
       (SELECT hv.MaHV AS '@MaHV', hv.HoTen AS 'text()'
        FROM dbo.GHIDANH gd JOIN dbo.HOCVIEN hv ON hv.MaHV = gd.MaHV
        WHERE gd.MaLop = l.MaLop
        FOR XML PATH('HocVien'), TYPE) AS 'DanhSach'
FROM dbo.LOPHOC l
WHERE l.TrangThai = N'Đang học'
FOR XML PATH('Lop'), ROOT('TrungTam');

-- X9. Nhật ký kiểm toán: đọc dữ liệu cũ/mới (XML) của các lần sửa điểm
SELECT TOP (10) ThoiGian, NguoiThucHien, HanhDong, KhoaChinh,
       DuLieuCu.value('(/Diem/Diem)[1]', 'DECIMAL(4,2)')  AS DiemCu,
       DuLieuMoi.value('(/Diem/Diem)[1]', 'DECIMAL(4,2)') AS DiemMoi
FROM dbo.NHATKYHETHONG
WHERE BangDuLieu = N'DIEM'
ORDER BY MaNK DESC;

/* ===================== PHẦN C. GỌI THỦ TỤC / HÀM ===================== */
EXEC dbo.usp_ThongKe_TongQuan;
EXEC dbo.usp_HocVien_TimKiem @TuKhoa = N'Nguyễn';
EXEC dbo.usp_KhoaHoc_TimTheoKyNang @KyNang = N'Speaking';
EXEC dbo.usp_KhoaHoc_DeCuong @MaKH = 'IE-55';
EXEC dbo.usp_GiaoVien_TimTheoChungChi @Loai = N'IELTS', @DiemToiThieu = 8.0;
SELECT * FROM dbo.fn_CongNoHocVien('HV00031');
SELECT dbo.fn_XepLoai(8.25) AS XepLoai, dbo.fn_ThuTrongTuan(GETDATE()) AS ThuHomNay;
GO
