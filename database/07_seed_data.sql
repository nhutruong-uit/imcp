/* =====================================================================
   File   : 07_seed_data.sql - Dữ liệu mẫu phục vụ demo
   - Ngày tháng được tính TƯƠNG ĐỐI theo ngày chạy script (@HomNay), nên
     chạy lại vào bất kỳ ngày nào cũng có: lớp đã kết thúc, lớp đang học,
     lớp sắp khai giảng, doanh thu tháng hiện tại...
   - Dữ liệu nghiệp vụ được nạp QUA THỦ TỤC (usp_GhiDanh, usp_LopHoc_TaoBuoiHoc,
     usp_LopHoc_XetKetQua, usp_BangLuong_Chot, usp_TaiKhoan_Tao) => đồng thời
     kiểm thử trigger, function, cursor.
   - Toàn bộ là dữ liệu giả lập, không phải thông tin cá nhân thật.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

DECLARE @HomNay DATE = CAST(GETDATE() AS DATE);
DECLARE @ThuHai DATE = DATEADD(DAY, 2 - dbo.fn_ThuTrongTuan(@HomNay), @HomNay);   -- thứ Hai tuần này

/* ---------------------------------------------------------------------
   1. Danh mục: chi nhánh, phòng, chương trình, khóa học, cột điểm, khuyến mãi
   --------------------------------------------------------------------- */
INSERT INTO dbo.CHINHANH (MaCN, TenCN, DiaChi, SoDienThoai, Email, NgayThanhLap) VALUES
('CN01', N'Chi nhánh Quận 1',  N'12 Nguyễn Thị Minh Khai, P. Đa Kao, Quận 1, TP.HCM',  '02838221234', 'q1@englishcenter.edu.vn', '20180315'),
('CN02', N'Chi nhánh Thủ Đức', N'45 Võ Văn Ngân, P. Linh Chiểu, TP. Thủ Đức, TP.HCM', '02837225678', 'td@englishcenter.edu.vn', '20210901');

INSERT INTO dbo.PHONGHOC (MaPhong, MaCN, TenPhong, SucChua, LoaiPhong) VALUES
('Q1-101', 'CN01', N'Phòng 101', 25, N'Lý thuyết'),
('Q1-102', 'CN01', N'Phòng 102', 20, N'Lý thuyết'),
('Q1-201', 'CN01', N'Phòng 201', 30, N'Đa năng'),
('Q1-LAB', 'CN01', N'Phòng Lab nghe', 16, N'Phòng Lab'),
('TD-301', 'CN02', N'Phòng 301', 25, N'Lý thuyết'),
('TD-302', 'CN02', N'Phòng 302', 20, N'Lý thuyết'),
('TD-303', 'CN02', N'Phòng 303', 18, N'Đa năng'),
('TD-LAB', 'CN02', N'Phòng Lab nghe', 16, N'Phòng Lab');

INSERT INTO dbo.CHUONGTRINH (MaCT, TenCT, DoiTuong, MoTa) VALUES
('IELTS', N'Luyện thi IELTS',          N'Học sinh THPT, sinh viên, người đi làm', N'Lộ trình Foundation -> 5.5 -> 6.5+'),
('TOEIC', N'Luyện thi TOEIC',          N'Sinh viên, người đi làm',                N'Chuẩn đầu ra đại học, thăng tiến công việc'),
('GT',    N'Tiếng Anh giao tiếp',      N'Người đi làm',                           N'Phản xạ nghe nói trong công việc và đời sống'),
('KIDS',  N'Tiếng Anh thiếu nhi',      N'Trẻ 6 - 11 tuổi',                        N'Theo khung Cambridge Young Learners');

INSERT INTO dbo.KHOAHOC (MaKH, MaCT, TenKH, CapDo, SoBuoi, ThoiLuongBuoi, HocPhi, DiemDauVaoToiThieu, MaKHTienQuyet, NoiDungXML) VALUES
('IE-FND', 'IELTS', N'IELTS Foundation',       'A2', 24, 120,  6500000, 4.0, NULL, N'
<DeCuong>
  <GiaoTrinh TacGia="Cambridge University Press" NamXB="2021">Complete IELTS Foundation</GiaoTrinh>
  <MucTieu>Xây dựng nền tảng 4 kỹ năng, làm quen định dạng đề, mục tiêu band 4.5</MucTieu>
  <Unit So="1" SoBuoi="6"><TenUnit>Làm quen đề thi IELTS</TenUnit><KyNang>Listening</KyNang><KyNang>Reading</KyNang></Unit>
  <Unit So="2" SoBuoi="6"><TenUnit>Từ vựng chủ đề Education - Work</TenUnit><KyNang>Vocabulary</KyNang><KyNang>Speaking</KyNang></Unit>
  <Unit So="3" SoBuoi="6"><TenUnit>Ngữ pháp câu phức</TenUnit><KyNang>Grammar</KyNang><KyNang>Writing</KyNang></Unit>
  <Unit So="4" SoBuoi="6"><TenUnit>Luyện đề tổng hợp</TenUnit><KyNang>Listening</KyNang><KyNang>Reading</KyNang><KyNang>Writing</KyNang><KyNang>Speaking</KyNang></Unit>
</DeCuong>'),
('IE-55', 'IELTS', N'IELTS 5.5 Intensive',    'B1', 30, 120,  8500000, 5.5, 'IE-FND', N'
<DeCuong>
  <GiaoTrinh TacGia="Cambridge University Press" NamXB="2023">Cambridge IELTS 18</GiaoTrinh>
  <GiaoTrinh TacGia="Pauline Cullen" NamXB="2021">The Official Cambridge Guide to IELTS</GiaoTrinh>
  <MucTieu>Đạt band 5.5 - 6.0, thành thạo chiến lược làm bài từng dạng câu hỏi</MucTieu>
  <Unit So="1" SoBuoi="6"><TenUnit>Listening Section 1-4</TenUnit><KyNang>Listening</KyNang></Unit>
  <Unit So="2" SoBuoi="6"><TenUnit>Reading: True/False/Not Given, Matching</TenUnit><KyNang>Reading</KyNang></Unit>
  <Unit So="3" SoBuoi="6"><TenUnit>Writing Task 1: Biểu đồ</TenUnit><KyNang>Writing</KyNang></Unit>
  <Unit So="4" SoBuoi="6"><TenUnit>Writing Task 2: Nghị luận</TenUnit><KyNang>Writing</KyNang><KyNang>Grammar</KyNang></Unit>
  <Unit So="5" SoBuoi="6"><TenUnit>Speaking Part 1-3</TenUnit><KyNang>Speaking</KyNang></Unit>
</DeCuong>'),
('IE-65', 'IELTS', N'IELTS 6.5 Advanced',     'B2', 30, 120, 10500000, 6.5, 'IE-55', NULL),
('TO-450', 'TOEIC', N'TOEIC 450+',            'A2', 20,  90,  4500000, 3.0, NULL, N'
<DeCuong>
  <GiaoTrinh TacGia="ETS" NamXB="2022">ETS TOEIC Test 2022</GiaoTrinh>
  <MucTieu>Đạt 450+ TOEIC Listening &amp; Reading</MucTieu>
  <Unit So="1" SoBuoi="5"><TenUnit>Part 1-2: Photographs, Question-Response</TenUnit><KyNang>Listening</KyNang></Unit>
  <Unit So="2" SoBuoi="5"><TenUnit>Part 3-4: Conversations, Talks</TenUnit><KyNang>Listening</KyNang></Unit>
  <Unit So="3" SoBuoi="5"><TenUnit>Part 5-6: Incomplete Sentences</TenUnit><KyNang>Grammar</KyNang><KyNang>Reading</KyNang></Unit>
  <Unit So="4" SoBuoi="5"><TenUnit>Part 7: Reading Comprehension</TenUnit><KyNang>Reading</KyNang></Unit>
</DeCuong>'),
('TO-750', 'TOEIC', N'TOEIC 750+',            'B1', 24,  90,  6000000, 5.0, 'TO-450', NULL),
('GT-A1', 'GT',    N'Giao tiếp Cơ bản',       'A1', 20,  90,  3800000, NULL, NULL, N'
<DeCuong>
  <GiaoTrinh TacGia="Oxford University Press" NamXB="2019">English File Beginner</GiaoTrinh>
  <MucTieu>Tự tin giới thiệu bản thân, hỏi đáp các tình huống hằng ngày</MucTieu>
  <Unit So="1" SoBuoi="5"><TenUnit>Greetings and Introductions</TenUnit><KyNang>Speaking</KyNang><KyNang>Pronunciation</KyNang></Unit>
  <Unit So="2" SoBuoi="5"><TenUnit>Daily Routines</TenUnit><KyNang>Speaking</KyNang><KyNang>Listening</KyNang></Unit>
  <Unit So="3" SoBuoi="5"><TenUnit>Shopping and Eating Out</TenUnit><KyNang>Speaking</KyNang><KyNang>Vocabulary</KyNang></Unit>
  <Unit So="4" SoBuoi="5"><TenUnit>Travel and Directions</TenUnit><KyNang>Listening</KyNang><KyNang>Speaking</KyNang></Unit>
</DeCuong>'),
('GT-B1', 'GT',    N'Giao tiếp Trung cấp',    'B1', 24,  90,  4800000, 4.5, 'GT-A1', NULL),
('KD-STA', 'KIDS', N'Kids Starters',          'A1', 32,  90,  5200000, NULL, NULL, N'
<DeCuong>
  <GiaoTrinh TacGia="Cambridge University Press" NamXB="2018">Fun for Starters</GiaoTrinh>
  <MucTieu>Phát âm chuẩn, vốn từ 400 từ, sẵn sàng thi Cambridge Starters</MucTieu>
  <Unit So="1" SoBuoi="8"><TenUnit>Phonics</TenUnit><KyNang>Phonics</KyNang><KyNang>Pronunciation</KyNang></Unit>
  <Unit So="2" SoBuoi="8"><TenUnit>Colors and Numbers</TenUnit><KyNang>Vocabulary</KyNang><KyNang>Listening</KyNang></Unit>
  <Unit So="3" SoBuoi="8"><TenUnit>My Family</TenUnit><KyNang>Speaking</KyNang><KyNang>Vocabulary</KyNang></Unit>
  <Unit So="4" SoBuoi="8"><TenUnit>Animals</TenUnit><KyNang>Listening</KyNang><KyNang>Speaking</KyNang></Unit>
</DeCuong>'),
('KD-MOV', 'KIDS', N'Kids Movers',            'A2', 32,  90,  5600000, 4.0, 'KD-STA', NULL);

INSERT INTO dbo.THANHPHANDIEM (MaKH, TenTP, TrongSo)
SELECT k.MaKH, tp.TenTP, tp.TrongSo
FROM dbo.KHOAHOC k
JOIN (VALUES ('IELTS', N'Bài tập', 20), ('IELTS', N'Giữa khóa', 30), ('IELTS', N'Cuối khóa', 50),
             ('TOEIC', N'Chuyên cần', 10), ('TOEIC', N'Giữa khóa', 30), ('TOEIC', N'Cuối khóa', 60),
             ('GT',    N'Chuyên cần', 20), ('GT',    N'Thuyết trình', 30), ('GT', N'Cuối khóa', 50),
             ('KIDS',  N'Chuyên cần', 20), ('KIDS',  N'Giữa khóa', 30), ('KIDS', N'Cuối khóa', 50)
     ) AS tp (MaCT, TenTP, TrongSo) ON tp.MaCT = k.MaCT;

INSERT INTO dbo.KHUYENMAI (MaKM, TenKM, LoaiGiam, GiaTri, NgayBatDau, NgayKetThuc) VALUES
('KM-HE',  N'Ưu đãi mùa hè giảm 10%',          'PHANTRAM', 10,     DATEADD(WEEK, -26, @ThuHai), DATEADD(WEEK, -12, @ThuHai)),
('KM-BAN', N'Giới thiệu bạn bè giảm 500.000đ', 'SOTIEN',   500000, DATEADD(YEAR, -1, @HomNay),  DATEADD(YEAR, 1, @HomNay)),
('KM-KG',  N'Mừng khai giảng giảm 15%',        'PHANTRAM', 15,     DATEADD(WEEK, -4, @ThuHai),  DATEADD(WEEK, 6, @ThuHai));

/* ---------------------------------------------------------------------
   2. Nhân sự: nhân viên, giáo viên (mã tường minh rồi đặt lại sequence)
   --------------------------------------------------------------------- */
INSERT INTO dbo.NHANVIEN (MaNV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, DiaChi, ChucVu, MaCN, NgayVaoLam, LuongCoBan) VALUES
('NV0001', N'Trần Minh Quân',  '19850412', N'Nam', '0903111001', 'quan.tm@englishcenter.edu.vn',  N'Quận 3, TP.HCM',     N'Quản lý', 'CN01', '20180315', 25000000),
('NV0002', N'Lê Thị Lan',      '19930820', N'Nữ',  '0903111002', 'lan.lt@englishcenter.edu.vn',   N'Quận 1, TP.HCM',     N'Giáo vụ', 'CN01', '20190601', 11000000),
('NV0003', N'Phạm Văn Minh',   '19900105', N'Nam', '0903111003', 'minh.pv@englishcenter.edu.vn',  N'Quận 10, TP.HCM',    N'Kế toán', 'CN01', '20180401', 13000000),
('NV0004', N'Nguyễn Thu Hà',   '19960314', N'Nữ',  '0903111004', 'ha.nt@englishcenter.edu.vn',    N'TP. Thủ Đức, TP.HCM', N'Giáo vụ', 'CN02', '20210901', 10500000),
('NV0005', N'Võ Thanh Tùng',   '19920709', N'Nam', '0903111005', 'tung.vt@englishcenter.edu.vn',  N'Bình Thạnh, TP.HCM', N'Kế toán', 'CN02', '20210901', 12500000),
('NV0006', N'Đặng Ngọc Mai',   '19980228', N'Nữ',  '0903111006', 'mai.dn@englishcenter.edu.vn',   N'Quận 5, TP.HCM',     N'Tư vấn',  'CN01', '20220110',  9000000);
ALTER SEQUENCE dbo.seq_NHANVIEN RESTART WITH 7;

INSERT INTO dbo.GIAOVIEN (MaGV, HoTen, NgaySinh, GioiTinh, QuocTich, SoDienThoai, Email, TrinhDo, LoaiGV, DonGiaGio, MaCN, NgayVaoLam, HoSoXML) VALUES
('GV0001', N'John Smith',       '19860611', N'Nam', N'Vương quốc Anh', '0908222001', 'john.smith@englishcenter.edu.vn', N'Thạc sĩ', N'Bản ngữ', 450000, 'CN01', '20180315',
 N'<HoSo><ChungChi Loai="CELTA" Nam="2014"/><ChungChi Loai="IELTS Examiner" Nam="2019"/><KinhNghiem SoNam="10"><NoiLamViec TuNam="2014" DenNam="2018">British Council</NoiLamViec></KinhNghiem><ChuyenMon>IELTS Speaking</ChuyenMon><ChuyenMon>IELTS Writing</ChuyenMon></HoSo>'),
('GV0002', N'Nguyễn Hoàng Anh', '19900923', N'Nam', N'Việt Nam',       '0908222002', 'anh.nh@englishcenter.edu.vn',     N'Thạc sĩ', N'Việt Nam', 300000, 'CN01', '20190110',
 N'<HoSo><ChungChi Loai="IELTS" Diem="8.5" Nam="2023"/><ChungChi Loai="TESOL" Nam="2019"/><KinhNghiem SoNam="8"><NoiLamViec TuNam="2016" DenNam="2019">ILA Việt Nam</NoiLamViec></KinhNghiem><ChuyenMon>IELTS Reading</ChuyenMon><ChuyenMon>IELTS Listening</ChuyenMon></HoSo>'),
('GV0003', N'Trần Thị Hoa',     '19950517', N'Nữ',  N'Việt Nam',       '0908222003', 'hoa.tt@englishcenter.edu.vn',     N'Cử nhân', N'Việt Nam', 250000, 'CN01', '20210301',
 N'<HoSo><ChungChi Loai="IELTS" Diem="8.0" Nam="2022"/><ChungChi Loai="TESOL" Nam="2021"/><KinhNghiem SoNam="5"/><ChuyenMon>Giao tiếp</ChuyenMon></HoSo>'),
('GV0004', N'Emily Johnson',    '19920302', N'Nữ',  N'Hoa Kỳ',         '0908222004', 'emily.j@englishcenter.edu.vn',    N'Cử nhân', N'Bản ngữ', 420000, 'CN02', '20210901',
 N'<HoSo><ChungChi Loai="TESOL" Nam="2017"/><KinhNghiem SoNam="7"/><ChuyenMon>Giao tiếp</ChuyenMon><ChuyenMon>Phát âm</ChuyenMon></HoSo>'),
('GV0005', N'Lê Quốc Bảo',      '19910830', N'Nam', N'Việt Nam',       '0908222005', 'bao.lq@englishcenter.edu.vn',     N'Thạc sĩ', N'Việt Nam', 260000, 'CN01', '20200615',
 N'<HoSo><ChungChi Loai="TOEIC" Diem="990" Nam="2021"/><ChungChi Loai="IELTS" Diem="7.5" Nam="2020"/><KinhNghiem SoNam="6"/><ChuyenMon>TOEIC</ChuyenMon></HoSo>'),
('GV0006', N'Phạm Ngọc Diệp',   '19970124', N'Nữ',  N'Việt Nam',       '0908222006', 'diep.pn@englishcenter.edu.vn',    N'Cử nhân', N'Việt Nam', 220000, 'CN01', '20220801',
 N'<HoSo><ChungChi Loai="IELTS" Diem="7.5" Nam="2022"/><ChungChi Loai="TKT" Nam="2023"/><KinhNghiem SoNam="4"/><ChuyenMon>Thiếu nhi</ChuyenMon></HoSo>'),
('GV0007', N'David Brown',      '19830719', N'Nam', N'Úc',             '0908222007', 'david.b@englishcenter.edu.vn',    N'Cử nhân', N'Bản ngữ', 400000, 'CN02', '20210901',
 N'<HoSo><ChungChi Loai="CELTA" Nam="2012"/><KinhNghiem SoNam="12"/><ChuyenMon>Giao tiếp</ChuyenMon></HoSo>'),
('GV0008', N'Huỳnh Minh Thư',   '19940411', N'Nữ',  N'Việt Nam',       '0908222008', 'thu.hm@englishcenter.edu.vn',     N'Thạc sĩ', N'Việt Nam', 280000, 'CN02', '20220215',
 N'<HoSo><ChungChi Loai="IELTS" Diem="8.0" Nam="2024"/><KinhNghiem SoNam="5"/><ChuyenMon>IELTS Writing</ChuyenMon></HoSo>');
ALTER SEQUENCE dbo.seq_GIAOVIEN RESTART WITH 9;

/* ---------------------------------------------------------------------
   3. Học viên (Lop = lớp dự kiến ghi danh, NgayDK = số ngày trước hôm nay)
   --------------------------------------------------------------------- */
DECLARE @HV TABLE (MaHV VARCHAR(10), HoTen NVARCHAR(100), NgaySinh DATE, GioiTinh NVARCHAR(5),
                   SDT VARCHAR(15), Email VARCHAR(100), NgheNghiep NVARCHAR(50),
                   TenPH NVARCHAR(100), SDTPH VARCHAR(15), MaCN VARCHAR(10), NgayDK INT);
INSERT INTO @HV VALUES
('HV00001', N'Nguyễn Văn An',        '20040312', N'Nam', '0901000001', 'an.nv04@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 175),
('HV00002', N'Trần Thị Bích Ngọc',   '20030725', N'Nữ',  '0901000002', 'ngoc.ttb@gmail.com',     N'Sinh viên', NULL, NULL, 'CN01', 175),
('HV00003', N'Lê Hoàng Phúc',        '20051102', N'Nam', '0901000003', 'phuc.lh@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 174),
('HV00004', N'Phạm Minh Châu',       '20020118', N'Nữ',  '0901000004', 'chau.pm@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 174),
('HV00005', N'Hoàng Gia Huy',        '20090509', N'Nam', '0901000005', NULL,                     N'Học sinh',  N'Hoàng Văn Hải', '0911000005', 'CN01', 173),
('HV00006', N'Vũ Thảo Nguyên',       '20010930', N'Nữ',  '0901000006', 'nguyen.vt@gmail.com',    N'Nhân viên văn phòng', NULL, NULL, 'CN01', 173),
('HV00007', N'Đặng Quốc Khánh',      '19980214', N'Nam', '0901000007', 'khanh.dq@gmail.com',     N'Kỹ sư phần mềm', NULL, NULL, 'CN01', 172),
('HV00008', N'Bùi Ngọc Ánh',         '20041201', N'Nữ',  '0901000008', NULL,                     N'Sinh viên', NULL, NULL, 'CN01', 172),
('HV00009', N'Đỗ Thành Đạt',         '20030621', N'Nam', '0901000009', 'dat.dt@gmail.com',       N'Sinh viên', NULL, NULL, 'CN01', 171),
('HV00010', N'Ngô Khánh Linh',       '20100815', N'Nữ',  NULL,         NULL,                     N'Học sinh',  N'Ngô Văn Tâm', '0911000010', 'CN01', 171),
('HV00011', N'Dương Tuấn Kiệt',      '20000404', N'Nam', '0901000011', 'kiet.dt@gmail.com',      N'Nhân viên kinh doanh', NULL, NULL, 'CN01', 170),
('HV00012', N'Lý Mỹ Duyên',          '20021010', N'Nữ',  '0901000012', 'duyen.lm@gmail.com',     N'Sinh viên', NULL, NULL, 'CN01', 170),
('HV00013', N'Phan Văn Lợi',         '19900303', N'Nam', '0901000013', 'loi.pv@gmail.com',       N'Kỹ sư xây dựng', NULL, NULL, 'CN02', 130),
('HV00014', N'Trịnh Thu Trang',      '19950505', N'Nữ',  '0901000014', 'trang.tt@gmail.com',     N'Kế toán', NULL, NULL, 'CN02', 130),
('HV00015', N'Mai Đức Thắng',        '19881212', N'Nam', '0901000015', NULL,                     N'Kinh doanh tự do', NULL, NULL, 'CN02', 129),
('HV00016', N'Hồ Thị Thanh Tâm',     '19930707', N'Nữ',  '0901000016', 'tam.htt@gmail.com',      N'Giáo viên tiểu học', NULL, NULL, 'CN02', 129),
('HV00017', N'Tạ Minh Nhật',         '19990909', N'Nam', '0901000017', 'nhat.tm@gmail.com',      N'Nhân viên IT', NULL, NULL, 'CN02', 128),
('HV00018', N'Châu Ngọc Hân',        '19970121', N'Nữ',  '0901000018', 'han.cn@gmail.com',       N'Dược sĩ', NULL, NULL, 'CN02', 128),
('HV00019', N'Lâm Chí Thanh',        '19851111', N'Nam', '0901000019', NULL,                     N'Tài xế', NULL, NULL, 'CN02', 127),
('HV00020', N'Quách Bảo Trân',       '20000229', N'Nữ',  '0901000020', 'tran.qb@gmail.com',      N'Nhân viên ngân hàng', NULL, NULL, 'CN02', 127),
('HV00021', N'Võ Hoài Nam',          '19920616', N'Nam', '0901000021', 'nam.vh@gmail.com',       N'Kỹ thuật viên', NULL, NULL, 'CN02', 126),
('HV00022', N'Kiều Diễm My',         '19960808', N'Nữ',  '0901000022', 'my.kd@gmail.com',        N'Thiết kế đồ họa', NULL, NULL, 'CN02', 126),
('HV00023', N'Nguyễn Thanh Tùng',    '20010327', N'Nam', '0901000023', 'tung.nt@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 72),
('HV00024', N'Lê Phương Thảo',       '20020519', N'Nữ',  '0901000024', 'thao.lp@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 71),
('HV00025', N'Trần Đức Anh',         '19991030', N'Nam', '0901000025', 'anh.td@gmail.com',       N'Nhân viên marketing', NULL, NULL, 'CN01', 71),
('HV00026', N'Phạm Thùy Dương',      '20030414', N'Nữ',  '0901000026', NULL,                     N'Sinh viên', NULL, NULL, 'CN01', 70),
('HV00027', N'Hoàng Văn Thái',       '19970717', N'Nam', '0901000027', 'thai.hv@gmail.com',      N'Nhân viên văn phòng', NULL, NULL, 'CN01', 55),
('HV00028', N'Nguyễn Thị Hồng Nhung','20020202', N'Nữ',  '0901000028', 'nhung.nth@gmail.com',    N'Sinh viên', NULL, NULL, 'CN01', 55),
('HV00029', N'Trương Minh Trí',      '20011225', N'Nam', '0901000029', 'tri.tm@gmail.com',       N'Sinh viên', NULL, NULL, 'CN01', 54),
('HV00030', N'Lương Thị Kim Oanh',   '19980308', N'Nữ',  '0901000030', NULL,                     N'Nhân viên hành chính', NULL, NULL, 'CN01', 54),
('HV00031', N'Đinh Công Danh',       '20000902', N'Nam', '0901000031', 'danh.dc@gmail.com',      N'Kỹ thuật viên', NULL, NULL, 'CN01', 53),
('HV00032', N'Huỳnh Thị Mỹ Lệ',      '20031120', N'Nữ',  '0901000032', 'le.htm@gmail.com',       N'Sinh viên', NULL, NULL, 'CN01', 53),
('HV00033', N'Tôn Thất Bảo Long',    '19960601', N'Nam', '0901000033', 'long.ttb@gmail.com',     N'Chuyên viên nhân sự', NULL, NULL, 'CN01', 52),
('HV00034', N'Cao Ngọc Quỳnh',       '20040101', N'Nữ',  '0901000034', NULL,                     N'Sinh viên', NULL, NULL, 'CN01', 52),
('HV00035', N'La Văn Hùng',          '19940430', N'Nam', '0901000035', 'hung.lv@gmail.com',      N'Quản lý kho', NULL, NULL, 'CN01', 51),
('HV00036', N'Từ Thị Diệu Hiền',     '20020819', N'Nữ',  '0901000036', 'hien.ttd@gmail.com',     N'Sinh viên', NULL, NULL, 'CN01', 51),
('HV00037', N'Thái Minh Hiếu',       '20010515', N'Nam', '0901000037', 'hieu.tm@gmail.com',      N'Sinh viên', NULL, NULL, 'CN01', 50),
('HV00038', N'Âu Dương Phong',       '19991231', N'Nam', '0901000038', NULL,                     N'Nhân viên bán hàng', NULL, NULL, 'CN01', 50),
('HV00039', N'Nguyễn Gia Bảo',       '20170210', N'Nam', NULL, NULL, N'Học sinh', N'Nguyễn Văn Hòa',  '0912000039', 'CN01', 95),
('HV00040', N'Trần Khánh Vy',        '20160606', N'Nữ',  NULL, NULL, N'Học sinh', N'Trần Thị Mai',    '0912000040', 'CN01', 95),
('HV00041', N'Lê Minh Khang',        '20180120', N'Nam', NULL, NULL, N'Học sinh', N'Lê Văn Đức',      '0912000041', 'CN01', 94),
('HV00042', N'Phạm Bảo Ngọc',        '20170909', N'Nữ',  NULL, NULL, N'Học sinh', N'Phạm Quang Vinh', '0912000042', 'CN01', 94),
('HV00043', N'Hoàng Anh Thư',        '20161111', N'Nữ',  NULL, NULL, N'Học sinh', N'Hoàng Thị Lan',   '0912000043', 'CN01', 93),
('HV00044', N'Vũ Đức Minh',          '20170303', N'Nam', NULL, NULL, N'Học sinh', N'Vũ Văn Sơn',      '0912000044', 'CN01', 93),
('HV00045', N'Đặng Tuệ Nhi',         '20180505', N'Nữ',  NULL, NULL, N'Học sinh', N'Đặng Thị Hạnh',   '0912000045', 'CN01', 92),
('HV00046', N'Bùi Quang Huy',        '20160808', N'Nam', NULL, NULL, N'Học sinh', N'Bùi Văn Lực',     '0912000046', 'CN01', 92),
('HV00047', N'Đỗ Ngọc Hân',          '20171212', N'Nữ',  NULL, NULL, N'Học sinh', N'Đỗ Thị Thu',      '0912000047', 'CN01', 91),
('HV00048', N'Ngô Thiên Ân',         '20180707', N'Nam', NULL, NULL, N'Học sinh', N'Ngô Văn Phát',    '0912000048', 'CN01', 91),
('HV00049', N'Dương Minh Anh',       '20160404', N'Nữ',  NULL, NULL, N'Học sinh', N'Dương Thị Yến',   '0912000049', 'CN01', 90),
('HV00050', N'Lý Hoàng Nam',         '20171010', N'Nam', NULL, NULL, N'Học sinh', N'Lý Văn Tài',      '0912000050', 'CN01', 90),
('HV00051', N'Phan Thị Ngọc Trâm',   '19940222', N'Nữ',  '0901000051', 'tram.ptn@gmail.com',     N'Nhân viên xuất nhập khẩu', NULL, NULL, 'CN02', 33),
('HV00052', N'Trịnh Quốc Bảo',       '19910919', N'Nam', '0901000052', 'bao.tq@gmail.com',       N'Kỹ sư điện', NULL, NULL, 'CN02', 33),
('HV00053', N'Mai Thanh Hương',      '20050315', N'Nữ',  '0901000053', 'huong.mt@gmail.com',     N'Sinh viên', NULL, NULL, 'CN02', 26),
('HV00054', N'Hồ Minh Quân',         '20040626', N'Nam', '0901000054', 'quan.hm@gmail.com',      N'Sinh viên', NULL, NULL, 'CN02', 26),
('HV00055', N'Tạ Thị Ngọc Mai',      '20030812', N'Nữ',  '0901000055', NULL,                     N'Sinh viên', NULL, NULL, 'CN02', 25),
('HV00056', N'Châu Gia Kiệt',        '20091001', N'Nam', '0901000056', NULL,                     N'Học sinh', N'Châu Văn Lộc', '0911000056', 'CN02', 25),
('HV00057', N'Lâm Bảo Anh',          '20021205', N'Nữ',  '0901000057', 'anh.lb@gmail.com',       N'Sinh viên', NULL, NULL, 'CN02', 24),
('HV00058', N'Quách Thành Danh',     '20010117', N'Nam', '0901000058', 'danh.qt@gmail.com',      N'Nhân viên IT', NULL, NULL, 'CN02', 24),
('HV00059', N'Võ Ngọc Bích',         '20040424', N'Nữ',  '0901000059', 'bich.vn@gmail.com',      N'Sinh viên', NULL, NULL, 'CN02', 23),
('HV00060', N'Kiều Minh Tuấn',       '20000729', N'Nam', '0901000060', 'tuan.km@gmail.com',      N'Nhân viên kinh doanh', NULL, NULL, 'CN02', 23),
('HV00061', N'Nguyễn Hải Đăng',      '19980520', N'Nam', '0901000061', 'dang.nh@gmail.com',      N'Chuyên viên tư vấn du học', NULL, NULL, 'CN01', 6),
('HV00062', N'Trần Mai Anh',         '20001130', N'Nữ',  '0901000062', 'anh.tm@gmail.com',       N'Nhân viên ngân hàng', NULL, NULL, 'CN01', 4),
('HV00063', N'Lê Quang Vinh',        '19950312', N'Nam', '0901000063', 'vinh.lq@gmail.com',      N'Kỹ sư cơ khí', NULL, NULL, 'CN02', 8),
('HV00064', N'Phạm Thị Thu Hà',      '19970618', N'Nữ',  '0901000064', 'ha.ptt@gmail.com',       N'Nhân viên kế toán', NULL, NULL, 'CN02', 7),
('HV00065', N'Hoàng Minh Đức',       '19930927', N'Nam', '0901000065', NULL,                     N'Nhân viên kỹ thuật', NULL, NULL, 'CN02', 5),
('HV00066', N'Vũ Thị Hồng Gấm',      '19870214', N'Nữ',  '0901000066', 'gam.vth@gmail.com',      N'Chủ cửa hàng', NULL, NULL, 'CN01', 6),
('HV00067', N'Đặng Văn Toàn',        '19790808', N'Nam', '0901000067', NULL,                     N'Lái xe công nghệ', NULL, NULL, 'CN01', 5),
('HV00068', N'Bùi Thị Hoa',          '19991020', N'Nữ',  '0901000068', 'hoa.bt@gmail.com',       N'Nhân viên lễ tân', NULL, NULL, 'CN01', 3),
('HV00069', N'Đỗ Hữu Nghĩa',         '20061212', N'Nam', '0901000069', 'nghia.dh@gmail.com',     N'Sinh viên', NULL, NULL, 'CN01', 2),
('HV00070', N'Ngô Bảo Châu',         '20070505', N'Nữ',  '0901000070', NULL,                     N'Sinh viên', NULL, NULL, 'CN02', 2),
('HV00071', N'Dương Văn Khoa',       '20010101', N'Nam', '0901000071', 'khoa.dv@gmail.com',      N'Nhân viên văn phòng', NULL, NULL, 'CN02', 1),
('HV00072', N'Lý Thị Kim Ngân',      '20110303', N'Nữ',  NULL,         NULL,                     N'Học sinh', N'Lý Văn Quý', '0911000072', 'CN01', 0);

INSERT INTO dbo.HOCVIEN (MaHV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, NgheNghiep, TenPhuHuynh, SDTPhuHuynh, MaCN, NgayDangKy, DiaChi)
SELECT MaHV, HoTen, NgaySinh, GioiTinh, SDT, Email, NgheNghiep, TenPH, SDTPH, MaCN, DATEADD(DAY, -NgayDK, @HomNay),
       CASE MaCN WHEN 'CN01' THEN N'TP.HCM' ELSE N'TP. Thủ Đức, TP.HCM' END
FROM @HV;
ALTER SEQUENCE dbo.seq_HOCVIEN RESTART WITH 73;

/* Kiểm tra đầu vào (trigger tự đề xuất khóa học) */
INSERT INTO dbo.KIEMTRADAUVAO (MaHV, NgayKiemTra, DiemNghe, DiemNoi, DiemDoc, DiemViet, MaGVCham)
SELECT h.MaHV, DATEADD(DAY, -h.NgayDK - 3, @HomNay), k.Nghe, k.Noi, k.Doc, k.Viet, k.GV
FROM @HV h
JOIN (VALUES
    ('HV00001', 4.5, 4.0, 4.5, 4.0, 'GV0002'), ('HV00002', 5.0, 4.5, 4.5, 4.0, 'GV0002'),
    ('HV00003', 4.0, 4.0, 4.5, 4.0, 'GV0002'), ('HV00004', 5.0, 5.0, 5.5, 4.5, 'GV0002'),
    ('HV00005', 4.5, 4.0, 4.0, 4.0, 'GV0002'), ('HV00006', 5.5, 5.0, 5.0, 4.5, 'GV0002'),
    ('HV00007', 5.0, 4.5, 5.0, 4.5, 'GV0002'), ('HV00008', 4.0, 4.5, 4.0, 4.0, 'GV0002'),
    ('HV00009', 4.5, 4.5, 5.0, 4.0, 'GV0002'), ('HV00010', 4.5, 4.0, 4.5, 4.0, 'GV0002'),
    ('HV00011', 4.0, 4.0, 4.0, 4.0, 'GV0002'), ('HV00012', 5.0, 4.5, 5.0, 4.5, 'GV0002'),
    ('HV00023', 6.0, 5.5, 6.0, 5.5, 'GV0001'), ('HV00024', 6.5, 5.5, 6.0, 5.5, 'GV0001'),
    ('HV00025', 5.5, 6.0, 5.5, 5.5, 'GV0001'), ('HV00026', 6.0, 5.5, 5.5, 5.5, 'GV0001'),
    ('HV00027', 4.0, 3.5, 4.5, 3.5, 'GV0005'), ('HV00028', 3.5, 3.0, 4.0, 3.0, 'GV0005'),
    ('HV00029', 4.5, 4.0, 4.5, 4.0, 'GV0005'), ('HV00030', 3.5, 3.5, 3.5, 3.0, 'GV0005'),
    ('HV00031', 4.0, 3.0, 4.0, 3.5, 'GV0005'), ('HV00032', 3.5, 3.0, 3.5, 3.0, 'GV0005'),
    ('HV00033', 5.0, 4.0, 4.5, 4.0, 'GV0005'), ('HV00034', 3.0, 3.0, 3.5, 3.0, 'GV0005'),
    ('HV00035', 4.0, 3.5, 4.0, 3.5, 'GV0005'), ('HV00036', 3.5, 3.5, 4.0, 3.0, 'GV0005'),
    ('HV00037', 4.5, 3.5, 4.5, 3.5, 'GV0005'), ('HV00038', 3.5, 3.0, 3.5, 3.5, 'GV0005'),
    ('HV00051', 5.0, 4.5, 5.0, 4.5, 'GV0004'), ('HV00052', 5.0, 5.0, 4.5, 4.5, 'GV0004'),
    ('HV00053', 4.5, 4.0, 4.5, 4.0, 'GV0008'), ('HV00054', 4.5, 4.5, 4.5, 4.0, 'GV0008'),
    ('HV00055', 4.0, 4.0, 4.5, 4.0, 'GV0008'), ('HV00056', 4.5, 4.0, 4.0, 4.0, 'GV0008'),
    ('HV00057', 5.0, 4.5, 5.0, 4.0, 'GV0008'), ('HV00058', 4.5, 4.5, 5.0, 4.5, 'GV0008'),
    ('HV00059', 4.0, 4.5, 4.0, 4.0, 'GV0008'), ('HV00060', 5.0, 4.0, 4.5, 4.0, 'GV0008'),
    ('HV00061', 7.0, 6.5, 7.0, 6.5, 'GV0001'), ('HV00062', 7.0, 6.5, 6.5, 6.5, 'GV0001'),
    ('HV00063', 5.5, 5.0, 5.5, 5.0, 'GV0005'), ('HV00064', 5.0, 5.0, 5.5, 5.0, 'GV0005'),
    ('HV00065', 5.5, 5.0, 5.0, 5.0, 'GV0005'), ('HV00070', 3.0, 2.5, 3.0, 2.0, 'GV0008')
) AS k (MaHV, Nghe, Noi, Doc, Viet, GV) ON k.MaHV = h.MaHV;

/* ---------------------------------------------------------------------
   4. Mở lớp + lịch học + sinh buổi học (qua thủ tục)
   --------------------------------------------------------------------- */
DECLARE @Lop TABLE (STT INT, TenLop NVARCHAR(100), MaKH VARCHAR(10), MaCN VARCHAR(10), MaGV VARCHAR(10),
                    MaPhong VARCHAR(10), KhaiGiang DATE, SiSo INT, LichThu VARCHAR(20), GioBD TIME(0), GioKT TIME(0),
                    TrangThaiCuoi NVARCHAR(20));
INSERT INTO @Lop VALUES
( 1, N'IELTS Foundation K01',   'IE-FND', 'CN01', 'GV0002', 'Q1-101', DATEADD(WEEK, -21, @ThuHai),                    20, '2,4,6', '18:00', '20:00', N'Đã kết thúc'),
( 2, N'Giao tiếp Cơ bản K01',   'GT-A1',  'CN02', 'GV0007', 'TD-301', DATEADD(DAY, 1, DATEADD(WEEK, -17, @ThuHai)),   20, '3,5',   '18:30', '20:00', N'Đã kết thúc'),
( 3, N'IELTS 5.5 Intensive K01','IE-55',  'CN01', 'GV0001', 'Q1-201', DATEADD(WEEK, -8, @ThuHai),                     20, '2,4,6', '18:00', '20:00', N'Đang học'),
( 4, N'TOEIC 450+ K01',         'TO-450', 'CN01', 'GV0005', 'Q1-102', DATEADD(DAY, 1, DATEADD(WEEK, -6, @ThuHai)),    20, '3,5',   '19:00', '20:30', N'Đang học'),
( 5, N'Kids Starters K01',      'KD-STA', 'CN01', 'GV0006', 'Q1-LAB', DATEADD(DAY, 5, DATEADD(WEEK, -12, @ThuHai)),   16, '7,8',   '08:00', '09:30', N'Đang học'),
( 6, N'Giao tiếp Trung cấp K01','GT-B1',  'CN02', 'GV0004', 'TD-302', DATEADD(WEEK, -3, @ThuHai),                     20, '2,4',   '18:30', '20:00', N'Đang học'),
( 7, N'IELTS Foundation K02',   'IE-FND', 'CN02', 'GV0008', 'TD-303', DATEADD(WEEK, -2, @ThuHai),                     18, '2,4,6', '18:00', '20:00', N'Đang học'),
( 8, N'IELTS 6.5 Advanced K01', 'IE-65',  'CN01', 'GV0001', 'Q1-201', DATEADD(DAY, 1, DATEADD(WEEK, 2, @ThuHai)),     20, '3,5,7', '18:00', '20:00', N'Đang tuyển sinh'),
( 9, N'TOEIC 750+ K01',         'TO-750', 'CN02', 'GV0005', 'TD-301', DATEADD(WEEK, 1, @ThuHai),                      20, '2,4',   '19:00', '20:30', N'Đang tuyển sinh'),
(10, N'Giao tiếp Cơ bản K02',   'GT-A1',  'CN01', 'GV0003', 'Q1-102', DATEADD(DAY, 5, DATEADD(WEEK, 1, @ThuHai)),     20, '7,8',   '09:00', '10:30', N'Đang tuyển sinh');

DECLARE @i INT = 1, @MaLop VARCHAR(10), @TenLop NVARCHAR(100), @MaKH VARCHAR(10), @MaCN VARCHAR(10),
        @MaGV VARCHAR(10), @MaPhong VARCHAR(10), @KhaiGiang DATE, @SiSo INT, @LichThu VARCHAR(20),
        @GioBD TIME(0), @GioKT TIME(0), @Thu TINYINT, @Pos INT;
DECLARE @MaLopTheoSTT TABLE (STT INT PRIMARY KEY, MaLop VARCHAR(10));

WHILE @i <= 10
BEGIN
    SELECT @TenLop = TenLop, @MaKH = MaKH, @MaCN = MaCN, @MaGV = MaGV, @MaPhong = MaPhong,
           @KhaiGiang = KhaiGiang, @SiSo = SiSo, @LichThu = LichThu + ',', @GioBD = GioBD, @GioKT = GioKT
    FROM @Lop WHERE STT = @i;

    EXEC dbo.usp_LopHoc_Tao @TenLop, @MaKH, @MaCN, @MaGV, @MaPhong, @KhaiGiang, @SiSo, NULL, @MaLop OUTPUT;
    INSERT INTO @MaLopTheoSTT VALUES (@i, @MaLop);

    WHILE LEN(@LichThu) > 0
    BEGIN
        SET @Pos = CHARINDEX(',', @LichThu);
        SET @Thu = CAST(LEFT(@LichThu, @Pos - 1) AS TINYINT);
        SET @LichThu = SUBSTRING(@LichThu, @Pos + 1, 20);
        EXEC dbo.usp_LichHoc_Them @MaLop, @Thu, @GioBD, @GioKT;
    END;

    -- Chặn kết quả trả về của thủ tục để script chạy gọn
    DECLARE @KetQuaTao TABLE (SoBuoi INT, NgayKetThuc DATE);
    INSERT INTO @KetQuaTao EXEC dbo.usp_LopHoc_TaoBuoiHoc @MaLop;
    SET @i += 1;
END;

/* ---------------------------------------------------------------------
   5. Ghi danh (qua usp_GhiDanh: kiểm tra đầu vào, trùng lịch, khuyến mãi)
      Thứ tự: lớp 1, 2 học xong + xét kết quả TRƯỚC, sau đó mới ghi danh
      lớp 3 (IELTS 5.5) và lớp 6 (Giao tiếp B1) vì cần khóa tiên quyết.
   --------------------------------------------------------------------- */
DECLARE @GD TABLE (MaHV VARCHAR(10), LopSTT INT, MaKM VARCHAR(10), Dot INT);
INSERT INTO @GD (MaHV, LopSTT, MaKM, Dot)
SELECT MaHV, 1, CASE WHEN RIGHT(MaHV, 1) IN ('2', '7') THEN 'KM-HE' END, 1 FROM @HV WHERE MaHV BETWEEN 'HV00001' AND 'HV00012'
UNION ALL SELECT MaHV, 2, CASE WHEN RIGHT(MaHV, 1) = '5' THEN 'KM-HE' END, 1 FROM @HV WHERE MaHV BETWEEN 'HV00013' AND 'HV00022'
UNION ALL SELECT MaHV, 4, CASE WHEN RIGHT(MaHV, 1) = '0' THEN 'KM-BAN' END, 1 FROM @HV WHERE MaHV BETWEEN 'HV00027' AND 'HV00038'
UNION ALL SELECT MaHV, 5, CASE WHEN RIGHT(MaHV, 1) = '3' THEN 'KM-BAN' END, 1 FROM @HV WHERE MaHV BETWEEN 'HV00039' AND 'HV00050'
UNION ALL SELECT MaHV, 7, 'KM-KG', 1 FROM @HV WHERE MaHV BETWEEN 'HV00053' AND 'HV00060'
UNION ALL SELECT MaHV, 8, NULL, 1 FROM @HV WHERE MaHV IN ('HV00061', 'HV00062')
UNION ALL SELECT MaHV, 9, 'KM-KG', 1 FROM @HV WHERE MaHV BETWEEN 'HV00063' AND 'HV00065'
UNION ALL SELECT MaHV, 10, NULL, 1 FROM @HV WHERE MaHV BETWEEN 'HV00066' AND 'HV00069'
-- Đợt 2: cần kết quả lớp trước
UNION ALL SELECT MaHV, 3, NULL, 2 FROM @HV WHERE MaHV IN ('HV00001','HV00002','HV00003','HV00004','HV00006','HV00007','HV00008','HV00009',
                                                         'HV00023','HV00024','HV00025','HV00026')
UNION ALL SELECT MaHV, 6, 'KM-BAN', 2 FROM @HV WHERE MaHV IN ('HV00013','HV00014','HV00015','HV00016','HV00017','HV00018','HV00020',
                                                             'HV00051','HV00052');

DECLARE @Dot INT = 1, @MaHV VARCHAR(10), @MaKM VARCHAR(10), @LopSTT INT, @NgayGD DATE, @MaNV VARCHAR(10), @MaGD VARCHAR(10);

WHILE @Dot <= 2
BEGIN
    DECLARE cur_GhiDanh CURSOR LOCAL FAST_FORWARD FOR
        SELECT g.MaHV, g.LopSTT, g.MaKM FROM @GD g WHERE g.Dot = @Dot ORDER BY g.LopSTT, g.MaHV;
    OPEN cur_GhiDanh;
    FETCH NEXT FROM cur_GhiDanh INTO @MaHV, @LopSTT, @MaKM;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @MaLop = m.MaLop, @MaCN = l.MaCN,
               @NgayGD = CASE WHEN l.KhaiGiang > @HomNay THEN DATEADD(DAY, -(ABS(CHECKSUM(@MaHV)) % 6), @HomNay)
                              ELSE DATEADD(DAY, -10 + ABS(CHECKSUM(@MaHV)) % 5, l.KhaiGiang) END
        FROM @Lop l JOIN @MaLopTheoSTT m ON m.STT = l.STT WHERE l.STT = @LopSTT;
        SET @MaNV = CASE @MaCN WHEN 'CN01' THEN 'NV0002' ELSE 'NV0004' END;

        EXEC dbo.usp_GhiDanh @MaHV, @MaLop, @MaKM, @NgayGD, @MaNV, @MaGD OUTPUT;
        FETCH NEXT FROM cur_GhiDanh INTO @MaHV, @LopSTT, @MaKM;
    END;
    CLOSE cur_GhiDanh;
    DEALLOCATE cur_GhiDanh;

    IF @Dot = 1
    BEGIN
        /* Lớp 1, 2: đã học xong => đánh dấu buổi đã dạy, điểm danh, nhập điểm, xét kết quả */
        UPDATE l SET TrangThai = N'Đang học'
        FROM dbo.LOPHOC l JOIN @MaLopTheoSTT m ON m.MaLop = l.MaLop WHERE m.STT IN (1, 2);

        UPDATE b SET TrangThai = N'Đã dạy', NoiDung = N'Buổi ' + CAST(b.STT AS NVARCHAR(3))
        FROM dbo.BUOIHOC b JOIN @MaLopTheoSTT m ON m.MaLop = b.MaLop WHERE m.STT IN (1, 2);

        INSERT INTO dbo.DIEMDANH (MaBuoi, MaGD, TrangThai)
        SELECT b.MaBuoi, gd.MaGD,
               CASE WHEN gd.MaHV = 'HV00005' THEN   -- học viên vắng nhiều => không đạt chuyên cần
                        CASE WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 60 THEN N'Có mặt' ELSE N'Vắng không phép' END
                    ELSE CASE WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 88 THEN N'Có mặt'
                              WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 95 THEN N'Đi trễ'
                              WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 98 THEN N'Vắng có phép'
                              ELSE N'Vắng không phép' END
               END
        FROM dbo.BUOIHOC b
        JOIN dbo.GHIDANH gd ON gd.MaLop = b.MaLop
        JOIN @MaLopTheoSTT m ON m.MaLop = b.MaLop
        WHERE m.STT IN (1, 2);

        INSERT INTO dbo.DIEM (MaGD, MaTP, Diem, NgayNhap, NguoiNhap)
        SELECT gd.MaGD, tp.MaTP,
               CASE WHEN gd.MaHV IN ('HV00011', 'HV00019')        -- học viên điểm thấp => không đạt
                    THEN 3.0 + (ABS(CHECKSUM(gd.MaGD, tp.MaTP)) % 18) / 10.0
                    ELSE 6.0 + (ABS(CHECKSUM(gd.MaGD, tp.MaTP)) % 36) / 10.0 END,
               l.NgayKetThuc, N'seed'
        FROM dbo.GHIDANH gd
        JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
        JOIN dbo.THANHPHANDIEM tp ON tp.MaKH = l.MaKH
        JOIN @MaLopTheoSTT m ON m.MaLop = l.MaLop
        WHERE m.STT IN (1, 2);

        DECLARE @XetKQ TABLE (SoDat INT, SoKhongDat INT);
        SELECT @MaLop = MaLop FROM @MaLopTheoSTT WHERE STT = 1;
        INSERT INTO @XetKQ EXEC dbo.usp_LopHoc_XetKetQua @MaLop;
        SELECT @MaLop = MaLop FROM @MaLopTheoSTT WHERE STT = 2;
        INSERT INTO @XetKQ EXEC dbo.usp_LopHoc_XetKetQua @MaLop;
    END;
    SET @Dot += 1;
END;

/* ---------------------------------------------------------------------
   6. Lớp đang học: buổi đã qua => Đã dạy, điểm danh, điểm giữa khóa
   --------------------------------------------------------------------- */
UPDATE l SET TrangThai = N'Đang học'
FROM dbo.LOPHOC l JOIN @MaLopTheoSTT m ON m.MaLop = l.MaLop JOIN @Lop x ON x.STT = m.STT
WHERE x.TrangThaiCuoi = N'Đang học';

UPDATE b SET TrangThai = N'Đã dạy', NoiDung = N'Buổi ' + CAST(b.STT AS NVARCHAR(3))
FROM dbo.BUOIHOC b JOIN @MaLopTheoSTT m ON m.MaLop = b.MaLop JOIN @Lop x ON x.STT = m.STT
WHERE x.TrangThaiCuoi = N'Đang học' AND b.NgayHoc < @HomNay;

INSERT INTO dbo.DIEMDANH (MaBuoi, MaGD, TrangThai)
SELECT b.MaBuoi, gd.MaGD,
       CASE WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 88 THEN N'Có mặt'
            WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 95 THEN N'Đi trễ'
            WHEN ABS(CHECKSUM(b.MaBuoi, gd.MaGD)) % 100 < 98 THEN N'Vắng có phép'
            ELSE N'Vắng không phép' END
FROM dbo.BUOIHOC b
JOIN dbo.GHIDANH gd ON gd.MaLop = b.MaLop
JOIN @MaLopTheoSTT m ON m.MaLop = b.MaLop JOIN @Lop x ON x.STT = m.STT
WHERE x.TrangThaiCuoi = N'Đang học' AND b.TrangThai = N'Đã dạy';

-- Lớp đã qua nửa khóa: có điểm các cột quá trình (trừ "Cuối khóa")
INSERT INTO dbo.DIEM (MaGD, MaTP, Diem, NguoiNhap)
SELECT gd.MaGD, tp.MaTP, 5.5 + (ABS(CHECKSUM(gd.MaGD, tp.MaTP)) % 40) / 10.0, N'seed'
FROM dbo.GHIDANH gd
JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
JOIN dbo.THANHPHANDIEM tp ON tp.MaKH = l.MaKH AND tp.TenTP <> N'Cuối khóa'
JOIN @MaLopTheoSTT m ON m.MaLop = l.MaLop JOIN @Lop x ON x.STT = m.STT
WHERE x.TrangThaiCuoi = N'Đang học'
  AND (SELECT COUNT(*) FROM dbo.BUOIHOC b WHERE b.MaLop = l.MaLop AND b.TrangThai = N'Đã dạy') * 2
      >= (SELECT COUNT(*) FROM dbo.BUOIHOC b WHERE b.MaLop = l.MaLop);

/* ---------------------------------------------------------------------
   7. Phiếu thu: lớp đã/đang học phần lớn đóng đủ, 1/3 đóng 2 đợt
      (đợt 2 chỉ thu nếu đã đến hạn); lớp sắp mở đặt cọc.
   --------------------------------------------------------------------- */
;WITH G AS (
    SELECT gd.MaGD, gd.NgayGhiDanh, gd.HocPhiPhaiDong, l.MaCN, l.TrangThai AS TrangThaiLop,
           ROW_NUMBER() OVER (ORDER BY gd.MaGD) AS n
    FROM dbo.GHIDANH gd JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
)
INSERT INTO dbo.PHIEUTHU (MaGD, NgayThu, SoTien, HinhThuc, MaNVThu, NoiDung)
SELECT MaGD,
       CAST(CASE WHEN TrangThaiLop = N'Đang tuyển sinh' THEN @HomNay ELSE NgayGhiDanh END AS DATETIME)
           + CAST('09:00' AS DATETIME) + CAST(n % 7 AS FLOAT) / 24,
       CASE WHEN TrangThaiLop = N'Đang tuyển sinh' THEN 1000000
            WHEN n % 3 = 0 THEN ROUND(HocPhiPhaiDong / 2, -3)
            ELSE HocPhiPhaiDong END,
       CASE n % 3 WHEN 0 THEN N'Tiền mặt' WHEN 1 THEN N'Chuyển khoản' ELSE N'Thẻ' END,
       CASE MaCN WHEN 'CN01' THEN 'NV0003' ELSE 'NV0005' END,
       CASE WHEN TrangThaiLop = N'Đang tuyển sinh' THEN N'Đặt cọc giữ chỗ'
            WHEN n % 3 = 0 THEN N'Học phí đợt 1' ELSE N'Học phí toàn khóa' END
FROM G
WHERE NOT (TrangThaiLop = N'Đang tuyển sinh' AND n % 2 = 0);

-- Đợt 2 cho các khoản đóng 50% (đến hạn sau 30 ngày); lớp mới khai giảng vẫn còn nợ
INSERT INTO dbo.PHIEUTHU (MaGD, NgayThu, SoTien, HinhThuc, MaNVThu, NoiDung)
SELECT gd.MaGD, DATEADD(DAY, 30, CAST(gd.NgayGhiDanh AS DATETIME)) + CAST('10:30' AS DATETIME),
       gd.HocPhiPhaiDong - gd.DaDong, N'Chuyển khoản',
       CASE l.MaCN WHEN 'CN01' THEN 'NV0003' ELSE 'NV0005' END, N'Học phí đợt 2'
FROM dbo.GHIDANH gd JOIN dbo.LOPHOC l ON l.MaLop = gd.MaLop
WHERE gd.DaDong > 0 AND gd.DaDong < gd.HocPhiPhaiDong
  AND l.TrangThai IN (N'Đang học', N'Đã kết thúc')
  AND DATEADD(DAY, 30, gd.NgayGhiDanh) < @HomNay
  AND RIGHT(gd.MaHV, 1) NOT IN ('1', '8');   -- vài học viên chậm đóng => còn công nợ

/* ---------------------------------------------------------------------
   8. Chốt lương 2 tháng gần nhất (cursor trong usp_BangLuong_Chot)
   --------------------------------------------------------------------- */
DECLARE @Luong TABLE (MaGV VARCHAR(10), HoTen NVARCHAR(100), SoBuoi INT, SoGio DECIMAL(6,2), DonGiaGio DECIMAL(12,0),
                      Thuong DECIMAL(12,0), KhauTru DECIMAL(12,0), TongLuong DECIMAL(14,0), TrangThai NVARCHAR(20));
DECLARE @ThangChot DATE = DATEADD(MONTH, -2, @HomNay), @T TINYINT, @N SMALLINT;
WHILE @ThangChot < DATEADD(DAY, 1 - DAY(@HomNay), @HomNay)
BEGIN
    SET @T = MONTH(@ThangChot); SET @N = YEAR(@ThangChot);
    INSERT INTO @Luong EXEC dbo.usp_BangLuong_Chot @T, @N;
    SET @ThangChot = DATEADD(MONTH, 1, @ThangChot);
END;
UPDATE dbo.BANGLUONG SET TrangThai = N'Đã chi trả'
WHERE DATEFROMPARTS(Nam, Thang, 1) < DATEADD(MONTH, -1, DATEADD(DAY, 1 - DAY(@HomNay), @HomNay));

/* ---------------------------------------------------------------------
   9. Tài khoản đăng nhập mẫu (contained users) - mật khẩu demo: xem docs/SETUP.md
   --------------------------------------------------------------------- */
EXEC dbo.usp_TaiKhoan_Tao N'ql_quan',     N'Demo@2026', 'QUANLY',   'NV0001', NULL;
EXEC dbo.usp_TaiKhoan_Tao N'gvu_lan',     N'Demo@2026', 'GIAOVU',   'NV0002', NULL;
EXEC dbo.usp_TaiKhoan_Tao N'gvu_ha',      N'Demo@2026', 'GIAOVU',   'NV0004', NULL;
EXEC dbo.usp_TaiKhoan_Tao N'kt_minh',     N'Demo@2026', 'KETOAN',   'NV0003', NULL;
EXEC dbo.usp_TaiKhoan_Tao N'kt_tung',     N'Demo@2026', 'KETOAN',   'NV0005', NULL;
EXEC dbo.usp_TaiKhoan_Tao N'gv_john',     N'Demo@2026', 'GIAOVIEN', NULL, 'GV0001';
EXEC dbo.usp_TaiKhoan_Tao N'gv_hoanganh', N'Demo@2026', 'GIAOVIEN', NULL, 'GV0002';
EXEC dbo.usp_TaiKhoan_Tao N'gv_hoa',      N'Demo@2026', 'GIAOVIEN', NULL, 'GV0003';
EXEC dbo.usp_TaiKhoan_Tao N'gv_bao',      N'Demo@2026', 'GIAOVIEN', NULL, 'GV0005';
GO

/* Tổng kết dữ liệu mẫu */
SELECT N'HOCVIEN' AS Bang, COUNT(*) AS SoDong FROM dbo.HOCVIEN
UNION ALL SELECT N'LOPHOC', COUNT(*) FROM dbo.LOPHOC
UNION ALL SELECT N'BUOIHOC', COUNT(*) FROM dbo.BUOIHOC
UNION ALL SELECT N'GHIDANH', COUNT(*) FROM dbo.GHIDANH
UNION ALL SELECT N'PHIEUTHU', COUNT(*) FROM dbo.PHIEUTHU
UNION ALL SELECT N'DIEMDANH', COUNT(*) FROM dbo.DIEMDANH
UNION ALL SELECT N'DIEM', COUNT(*) FROM dbo.DIEM
UNION ALL SELECT N'CHUNGCHI', COUNT(*) FROM dbo.CHUNGCHI
UNION ALL SELECT N'BANGLUONG', COUNT(*) FROM dbo.BANGLUONG
UNION ALL SELECT N'TAIKHOAN', COUNT(*) FROM dbo.TAIKHOAN
UNION ALL SELECT N'NHATKYHETHONG', COUNT(*) FROM dbo.NHATKYHETHONG;
GO
