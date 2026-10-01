/* =====================================================================
   File   : 01_tables.sql - Sequence, XML Schema, bảng và ràng buộc
   Quy ước: Bảng VIẾT HOA không dấu; cột PascalCase; ràng buộc đặt tên
            PK_<BANG>, FK_<CON>_<CHA>, UQ_<BANG>_<Cot>, CK_<BANG>_<Cot>,
            DF_<BANG>_<Cot>
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   1. SEQUENCE sinh mã tự động (SQL Server 2012+)
   --------------------------------------------------------------------- */
CREATE SEQUENCE dbo.seq_NHANVIEN AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_GIAOVIEN AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_HOCVIEN  AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_LOPHOC   AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_GHIDANH  AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_PHIEUTHU AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_KIEMTRA  AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_CHUNGCHI AS INT START WITH 1 INCREMENT BY 1;
GO

/* ---------------------------------------------------------------------
   2. XML SCHEMA COLLECTION cho đề cương khóa học (XML có kiểu - typed XML)
   --------------------------------------------------------------------- */
CREATE XML SCHEMA COLLECTION dbo.xsc_DeCuongKhoaHoc AS N'
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
  <xs:element name="DeCuong">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="GiaoTrinh" maxOccurs="unbounded">
          <xs:complexType>
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="TacGia" type="xs:string" use="optional"/>
                <xs:attribute name="NamXB" type="xs:int" use="optional"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        </xs:element>
        <xs:element name="MucTieu" type="xs:string"/>
        <xs:element name="Unit" maxOccurs="unbounded">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="TenUnit" type="xs:string"/>
              <xs:element name="KyNang" type="xs:string" maxOccurs="unbounded"/>
            </xs:sequence>
            <xs:attribute name="So" type="xs:int" use="required"/>
            <xs:attribute name="SoBuoi" type="xs:int" use="required"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

/* ---------------------------------------------------------------------
   3. CHINHANH - Chi nhánh của trung tâm
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CHINHANH (
    MaCN          VARCHAR(10)    NOT NULL,
    TenCN         NVARCHAR(100)  NOT NULL,
    DiaChi        NVARCHAR(200)  NOT NULL,
    SoDienThoai   VARCHAR(15)    NULL,
    Email         VARCHAR(100)   NULL,
    NgayThanhLap  DATE           NULL,
    TrangThai     NVARCHAR(20)   NOT NULL CONSTRAINT DF_CHINHANH_TrangThai DEFAULT (N'Hoạt động'),
    CONSTRAINT PK_CHINHANH PRIMARY KEY (MaCN),
    CONSTRAINT UQ_CHINHANH_TenCN UNIQUE (TenCN),
    CONSTRAINT CK_CHINHANH_SoDienThoai CHECK (SoDienThoai NOT LIKE '%[^0-9]%' AND LEN(SoDienThoai) BETWEEN 9 AND 11),
    CONSTRAINT CK_CHINHANH_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_CHINHANH_TrangThai CHECK (TrangThai IN (N'Hoạt động', N'Tạm ngưng'))
);
GO

/* ---------------------------------------------------------------------
   4. PHONGHOC - Phòng học thuộc chi nhánh
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PHONGHOC (
    MaPhong    VARCHAR(10)   NOT NULL,
    MaCN       VARCHAR(10)   NOT NULL,
    TenPhong   NVARCHAR(50)  NOT NULL,
    SucChua    INT           NOT NULL,
    LoaiPhong  NVARCHAR(30)  NOT NULL CONSTRAINT DF_PHONGHOC_LoaiPhong DEFAULT (N'Lý thuyết'),
    TrangThai  NVARCHAR(20)  NOT NULL CONSTRAINT DF_PHONGHOC_TrangThai DEFAULT (N'Sẵn sàng'),
    CONSTRAINT PK_PHONGHOC PRIMARY KEY (MaPhong),
    CONSTRAINT FK_PHONGHOC_CHINHANH FOREIGN KEY (MaCN) REFERENCES dbo.CHINHANH (MaCN),
    CONSTRAINT UQ_PHONGHOC_MaCN_TenPhong UNIQUE (MaCN, TenPhong),
    CONSTRAINT CK_PHONGHOC_SucChua CHECK (SucChua BETWEEN 1 AND 100),
    CONSTRAINT CK_PHONGHOC_LoaiPhong CHECK (LoaiPhong IN (N'Lý thuyết', N'Phòng Lab', N'Đa năng')),
    CONSTRAINT CK_PHONGHOC_TrangThai CHECK (TrangThai IN (N'Sẵn sàng', N'Bảo trì'))
);
GO

/* ---------------------------------------------------------------------
   5. NHANVIEN - Nhân viên văn phòng (quản lý, giáo vụ, kế toán, tư vấn)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.NHANVIEN (
    MaNV         VARCHAR(10)    NOT NULL CONSTRAINT DF_NHANVIEN_MaNV
                     DEFAULT ('NV' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_NHANVIEN AS VARCHAR(10)), 4)),
    HoTen        NVARCHAR(100)  NOT NULL,
    NgaySinh     DATE           NOT NULL,
    GioiTinh     NVARCHAR(5)    NOT NULL,
    SoDienThoai  VARCHAR(15)    NOT NULL,
    Email        VARCHAR(100)   NULL,
    DiaChi       NVARCHAR(200)  NULL,
    ChucVu       NVARCHAR(30)   NOT NULL,
    MaCN         VARCHAR(10)    NOT NULL,
    NgayVaoLam   DATE           NOT NULL CONSTRAINT DF_NHANVIEN_NgayVaoLam DEFAULT (CAST(GETDATE() AS DATE)),
    LuongCoBan   DECIMAL(12,0)  NOT NULL CONSTRAINT DF_NHANVIEN_LuongCoBan DEFAULT (0),
    TrangThai    NVARCHAR(20)   NOT NULL CONSTRAINT DF_NHANVIEN_TrangThai DEFAULT (N'Đang làm'),
    CONSTRAINT PK_NHANVIEN PRIMARY KEY (MaNV),
    CONSTRAINT FK_NHANVIEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES dbo.CHINHANH (MaCN),
    CONSTRAINT UQ_NHANVIEN_SoDienThoai UNIQUE (SoDienThoai),
    CONSTRAINT CK_NHANVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CONSTRAINT CK_NHANVIEN_SoDienThoai CHECK (SoDienThoai NOT LIKE '%[^0-9]%' AND LEN(SoDienThoai) BETWEEN 9 AND 11),
    CONSTRAINT CK_NHANVIEN_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_NHANVIEN_ChucVu CHECK (ChucVu IN (N'Quản lý', N'Giáo vụ', N'Kế toán', N'Tư vấn')),
    CONSTRAINT CK_NHANVIEN_LuongCoBan CHECK (LuongCoBan >= 0),
    -- Ràng buộc liên thuộc tính: nhân viên phải đủ 18 tuổi khi vào làm
    CONSTRAINT CK_NHANVIEN_Tuoi CHECK (DATEADD(YEAR, 18, NgaySinh) <= NgayVaoLam),
    CONSTRAINT CK_NHANVIEN_TrangThai CHECK (TrangThai IN (N'Đang làm', N'Đã nghỉ'))
);
GO
-- UNIQUE cho cột cho phép NULL: dùng filtered index (nhiều dòng NULL vẫn hợp lệ)
CREATE UNIQUE INDEX UX_NHANVIEN_Email ON dbo.NHANVIEN (Email) WHERE Email IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   6. GIAOVIEN - Giáo viên (Việt Nam / bản ngữ), hồ sơ năng lực dạng XML
   --------------------------------------------------------------------- */
CREATE TABLE dbo.GIAOVIEN (
    MaGV         VARCHAR(10)    NOT NULL CONSTRAINT DF_GIAOVIEN_MaGV
                     DEFAULT ('GV' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_GIAOVIEN AS VARCHAR(10)), 4)),
    HoTen        NVARCHAR(100)  NOT NULL,
    NgaySinh     DATE           NOT NULL,
    GioiTinh     NVARCHAR(5)    NOT NULL,
    QuocTich     NVARCHAR(50)   NOT NULL CONSTRAINT DF_GIAOVIEN_QuocTich DEFAULT (N'Việt Nam'),
    SoDienThoai  VARCHAR(15)    NOT NULL,
    Email        VARCHAR(100)   NOT NULL,
    TrinhDo      NVARCHAR(20)   NOT NULL,
    LoaiGV       NVARCHAR(20)   NOT NULL,
    DonGiaGio    DECIMAL(12,0)  NOT NULL,
    HoSoXML      XML            NULL,
    MaCN         VARCHAR(10)    NOT NULL,
    NgayVaoLam   DATE           NOT NULL CONSTRAINT DF_GIAOVIEN_NgayVaoLam DEFAULT (CAST(GETDATE() AS DATE)),
    TrangThai    NVARCHAR(20)   NOT NULL CONSTRAINT DF_GIAOVIEN_TrangThai DEFAULT (N'Đang dạy'),
    CONSTRAINT PK_GIAOVIEN PRIMARY KEY (MaGV),
    CONSTRAINT FK_GIAOVIEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES dbo.CHINHANH (MaCN),
    CONSTRAINT UQ_GIAOVIEN_SoDienThoai UNIQUE (SoDienThoai),
    CONSTRAINT UQ_GIAOVIEN_Email UNIQUE (Email),
    CONSTRAINT CK_GIAOVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CONSTRAINT CK_GIAOVIEN_SoDienThoai CHECK (SoDienThoai NOT LIKE '%[^0-9]%' AND LEN(SoDienThoai) BETWEEN 9 AND 11),
    CONSTRAINT CK_GIAOVIEN_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_GIAOVIEN_TrinhDo CHECK (TrinhDo IN (N'Cử nhân', N'Thạc sĩ', N'Tiến sĩ')),
    CONSTRAINT CK_GIAOVIEN_LoaiGV CHECK (LoaiGV IN (N'Việt Nam', N'Bản ngữ')),
    CONSTRAINT CK_GIAOVIEN_DonGiaGio CHECK (DonGiaGio > 0),
    -- Ràng buộc liên thuộc tính: giáo viên bản ngữ không mang quốc tịch Việt Nam
    CONSTRAINT CK_GIAOVIEN_BanNgu CHECK (LoaiGV = N'Việt Nam' OR QuocTich <> N'Việt Nam'),
    CONSTRAINT CK_GIAOVIEN_TrangThai CHECK (TrangThai IN (N'Đang dạy', N'Tạm nghỉ', N'Đã nghỉ'))
);
GO

/* ---------------------------------------------------------------------
   7. TAIKHOAN - Tài khoản đăng nhập ứng dụng.
      TenDangNhap trùng tên USER (contained user) trong SQL Server;
      mật khẩu do SQL Server quản lý (không lưu trong bảng).
   --------------------------------------------------------------------- */
CREATE TABLE dbo.TAIKHOAN (
    TenDangNhap      NVARCHAR(50)  NOT NULL,
    VaiTro           VARCHAR(20)   NOT NULL,
    MaNV             VARCHAR(10)   NULL,
    MaGV             VARCHAR(10)   NULL,
    TrangThai        NVARCHAR(20)  NOT NULL CONSTRAINT DF_TAIKHOAN_TrangThai DEFAULT (N'Hoạt động'),
    NgayTao          DATETIME      NOT NULL CONSTRAINT DF_TAIKHOAN_NgayTao DEFAULT (GETDATE()),
    LanDangNhapCuoi  DATETIME      NULL,
    CONSTRAINT PK_TAIKHOAN PRIMARY KEY (TenDangNhap),
    CONSTRAINT FK_TAIKHOAN_NHANVIEN FOREIGN KEY (MaNV) REFERENCES dbo.NHANVIEN (MaNV),
    CONSTRAINT FK_TAIKHOAN_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES dbo.GIAOVIEN (MaGV),
    CONSTRAINT CK_TAIKHOAN_VaiTro CHECK (VaiTro IN ('QUANLY', 'GIAOVU', 'KETOAN', 'GIAOVIEN')),
    CONSTRAINT CK_TAIKHOAN_TrangThai CHECK (TrangThai IN (N'Hoạt động', N'Đã khóa')),
    -- Tài khoản giáo viên gắn với GIAOVIEN, các vai trò khác gắn với NHANVIEN
    CONSTRAINT CK_TAIKHOAN_DoiTuong CHECK (
        (VaiTro = 'GIAOVIEN' AND MaGV IS NOT NULL AND MaNV IS NULL) OR
        (VaiTro <> 'GIAOVIEN' AND MaNV IS NOT NULL AND MaGV IS NULL))
);
GO
CREATE UNIQUE INDEX UX_TAIKHOAN_MaNV ON dbo.TAIKHOAN (MaNV) WHERE MaNV IS NOT NULL;
CREATE UNIQUE INDEX UX_TAIKHOAN_MaGV ON dbo.TAIKHOAN (MaGV) WHERE MaGV IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   8. HOCVIEN - Học viên
   --------------------------------------------------------------------- */
CREATE TABLE dbo.HOCVIEN (
    MaHV          VARCHAR(10)    NOT NULL CONSTRAINT DF_HOCVIEN_MaHV
                      DEFAULT ('HV' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_HOCVIEN AS VARCHAR(10)), 5)),
    HoTen         NVARCHAR(100)  NOT NULL,
    NgaySinh      DATE           NOT NULL,
    GioiTinh      NVARCHAR(5)    NOT NULL,
    SoDienThoai   VARCHAR(15)    NULL,
    Email         VARCHAR(100)   NULL,
    DiaChi        NVARCHAR(200)  NULL,
    NgheNghiep    NVARCHAR(50)   NULL,
    TenPhuHuynh   NVARCHAR(100)  NULL,
    SDTPhuHuynh   VARCHAR(15)    NULL,
    MaCN          VARCHAR(10)    NOT NULL,
    NgayDangKy    DATE           NOT NULL CONSTRAINT DF_HOCVIEN_NgayDangKy DEFAULT (CAST(GETDATE() AS DATE)),
    TrangThai     NVARCHAR(20)   NOT NULL CONSTRAINT DF_HOCVIEN_TrangThai DEFAULT (N'Tiềm năng'),
    GhiChu        NVARCHAR(500)  NULL,
    CONSTRAINT PK_HOCVIEN PRIMARY KEY (MaHV),
    CONSTRAINT FK_HOCVIEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES dbo.CHINHANH (MaCN),
    CONSTRAINT CK_HOCVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CONSTRAINT CK_HOCVIEN_SoDienThoai CHECK (SoDienThoai NOT LIKE '%[^0-9]%' AND LEN(SoDienThoai) BETWEEN 9 AND 11),
    CONSTRAINT CK_HOCVIEN_SDTPhuHuynh CHECK (SDTPhuHuynh NOT LIKE '%[^0-9]%' AND LEN(SDTPhuHuynh) BETWEEN 9 AND 11),
    CONSTRAINT CK_HOCVIEN_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_HOCVIEN_NgaySinh CHECK (NgaySinh > '19300101' AND DATEADD(YEAR, 4, NgaySinh) <= NgayDangKy),
    -- Ràng buộc liên thuộc tính: học viên dưới 18 tuổi phải có thông tin phụ huynh
    CONSTRAINT CK_HOCVIEN_PhuHuynh CHECK (
        DATEADD(YEAR, 18, NgaySinh) <= NgayDangKy
        OR (TenPhuHuynh IS NOT NULL AND SDTPhuHuynh IS NOT NULL)),
    -- Phải liên lạc được: có SĐT học viên hoặc SĐT phụ huynh
    CONSTRAINT CK_HOCVIEN_LienLac CHECK (SoDienThoai IS NOT NULL OR SDTPhuHuynh IS NOT NULL),
    CONSTRAINT CK_HOCVIEN_TrangThai CHECK (TrangThai IN (N'Tiềm năng', N'Đang học', N'Bảo lưu', N'Ngừng học'))
);
GO
CREATE UNIQUE INDEX UX_HOCVIEN_SoDienThoai ON dbo.HOCVIEN (SoDienThoai) WHERE SoDienThoai IS NOT NULL;
CREATE UNIQUE INDEX UX_HOCVIEN_Email ON dbo.HOCVIEN (Email) WHERE Email IS NOT NULL;
CREATE INDEX IX_HOCVIEN_HoTen ON dbo.HOCVIEN (HoTen);
GO

/* ---------------------------------------------------------------------
   9. CHUONGTRINH - Chương trình đào tạo (IELTS, TOEIC, Giao tiếp, Thiếu nhi)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CHUONGTRINH (
    MaCT      VARCHAR(10)    NOT NULL,
    TenCT     NVARCHAR(100)  NOT NULL,
    DoiTuong  NVARCHAR(100)  NULL,
    MoTa      NVARCHAR(500)  NULL,
    CONSTRAINT PK_CHUONGTRINH PRIMARY KEY (MaCT),
    CONSTRAINT UQ_CHUONGTRINH_TenCT UNIQUE (TenCT)
);
GO

/* ---------------------------------------------------------------------
   10. KHOAHOC - Khóa học (cấp độ CEFR), tự tham chiếu khóa tiên quyết
   --------------------------------------------------------------------- */
CREATE TABLE dbo.KHOAHOC (
    MaKH                VARCHAR(10)    NOT NULL,
    MaCT                VARCHAR(10)    NOT NULL,
    TenKH               NVARCHAR(100)  NOT NULL,
    CapDo               VARCHAR(2)     NOT NULL,
    SoBuoi              INT            NOT NULL,
    ThoiLuongBuoi       INT            NOT NULL CONSTRAINT DF_KHOAHOC_ThoiLuongBuoi DEFAULT (90),
    HocPhi              DECIMAL(12,0)  NOT NULL,
    DiemDauVaoToiThieu  DECIMAL(4,2)   NULL,
    MaKHTienQuyet       VARCHAR(10)    NULL,
    NoiDungXML          XML (CONTENT dbo.xsc_DeCuongKhoaHoc) NULL,
    TrangThai           NVARCHAR(20)   NOT NULL CONSTRAINT DF_KHOAHOC_TrangThai DEFAULT (N'Đang mở'),
    CONSTRAINT PK_KHOAHOC PRIMARY KEY (MaKH),
    CONSTRAINT FK_KHOAHOC_CHUONGTRINH FOREIGN KEY (MaCT) REFERENCES dbo.CHUONGTRINH (MaCT),
    CONSTRAINT FK_KHOAHOC_KHOAHOC FOREIGN KEY (MaKHTienQuyet) REFERENCES dbo.KHOAHOC (MaKH),
    CONSTRAINT UQ_KHOAHOC_TenKH UNIQUE (TenKH),
    CONSTRAINT CK_KHOAHOC_CapDo CHECK (CapDo IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    CONSTRAINT CK_KHOAHOC_SoBuoi CHECK (SoBuoi BETWEEN 1 AND 200),
    CONSTRAINT CK_KHOAHOC_ThoiLuongBuoi CHECK (ThoiLuongBuoi BETWEEN 30 AND 240),
    CONSTRAINT CK_KHOAHOC_HocPhi CHECK (HocPhi >= 0),
    CONSTRAINT CK_KHOAHOC_DiemDauVao CHECK (DiemDauVaoToiThieu BETWEEN 0 AND 10),
    CONSTRAINT CK_KHOAHOC_TienQuyet CHECK (MaKHTienQuyet <> MaKH),
    CONSTRAINT CK_KHOAHOC_TrangThai CHECK (TrangThai IN (N'Đang mở', N'Ngừng mở'))
);
GO

/* ---------------------------------------------------------------------
   11. THANHPHANDIEM - Cột điểm và trọng số của từng khóa học
   --------------------------------------------------------------------- */
CREATE TABLE dbo.THANHPHANDIEM (
    MaTP     INT IDENTITY(1,1)  NOT NULL,
    MaKH     VARCHAR(10)        NOT NULL,
    TenTP    NVARCHAR(50)       NOT NULL,
    TrongSo  DECIMAL(5,2)       NOT NULL,
    CONSTRAINT PK_THANHPHANDIEM PRIMARY KEY (MaTP),
    CONSTRAINT FK_THANHPHANDIEM_KHOAHOC FOREIGN KEY (MaKH) REFERENCES dbo.KHOAHOC (MaKH),
    CONSTRAINT UQ_THANHPHANDIEM_MaKH_TenTP UNIQUE (MaKH, TenTP),
    CONSTRAINT CK_THANHPHANDIEM_TrongSo CHECK (TrongSo > 0 AND TrongSo <= 100)
);
GO

/* ---------------------------------------------------------------------
   12. LOPHOC - Lớp học (một đợt mở của khóa học tại một chi nhánh)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.LOPHOC (
    MaLop          VARCHAR(10)    NOT NULL CONSTRAINT DF_LOPHOC_MaLop
                       DEFAULT ('LH' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_LOPHOC AS VARCHAR(10)), 4)),
    TenLop         NVARCHAR(100)  NOT NULL,
    MaKH           VARCHAR(10)    NOT NULL,
    MaCN           VARCHAR(10)    NOT NULL,
    MaGV           VARCHAR(10)    NOT NULL,
    MaPhong        VARCHAR(10)    NOT NULL,
    NgayKhaiGiang  DATE           NOT NULL,
    NgayKetThuc    DATE           NULL,
    SiSoToiDa      INT            NOT NULL CONSTRAINT DF_LOPHOC_SiSoToiDa DEFAULT (20),
    HocPhi         DECIMAL(12,0)  NOT NULL,
    TrangThai      NVARCHAR(20)   NOT NULL CONSTRAINT DF_LOPHOC_TrangThai DEFAULT (N'Đang tuyển sinh'),
    CONSTRAINT PK_LOPHOC PRIMARY KEY (MaLop),
    CONSTRAINT FK_LOPHOC_KHOAHOC FOREIGN KEY (MaKH) REFERENCES dbo.KHOAHOC (MaKH),
    CONSTRAINT FK_LOPHOC_CHINHANH FOREIGN KEY (MaCN) REFERENCES dbo.CHINHANH (MaCN),
    CONSTRAINT FK_LOPHOC_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES dbo.GIAOVIEN (MaGV),
    CONSTRAINT FK_LOPHOC_PHONGHOC FOREIGN KEY (MaPhong) REFERENCES dbo.PHONGHOC (MaPhong),
    CONSTRAINT CK_LOPHOC_SiSoToiDa CHECK (SiSoToiDa BETWEEN 1 AND 50),
    CONSTRAINT CK_LOPHOC_HocPhi CHECK (HocPhi >= 0),
    CONSTRAINT CK_LOPHOC_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayKhaiGiang),
    CONSTRAINT CK_LOPHOC_TrangThai CHECK (TrangThai IN (N'Đang tuyển sinh', N'Đang học', N'Đã kết thúc', N'Đã hủy'))
);
GO
CREATE INDEX IX_LOPHOC_MaKH ON dbo.LOPHOC (MaKH);
CREATE INDEX IX_LOPHOC_MaGV ON dbo.LOPHOC (MaGV);
GO

/* ---------------------------------------------------------------------
   13. LICHHOC - Lịch học cố định hằng tuần của lớp (Thu: 2..7, 8 = Chủ nhật)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.LICHHOC (
    MaLop       VARCHAR(10)  NOT NULL,
    Thu         TINYINT      NOT NULL,
    GioBatDau   TIME(0)      NOT NULL,
    GioKetThuc  TIME(0)      NOT NULL,
    CONSTRAINT PK_LICHHOC PRIMARY KEY (MaLop, Thu),
    CONSTRAINT FK_LICHHOC_LOPHOC FOREIGN KEY (MaLop) REFERENCES dbo.LOPHOC (MaLop) ON DELETE CASCADE,
    CONSTRAINT CK_LICHHOC_Thu CHECK (Thu BETWEEN 2 AND 8),
    CONSTRAINT CK_LICHHOC_Gio CHECK (GioKetThuc > GioBatDau AND GioBatDau >= '07:00' AND GioKetThuc <= '22:00')
);
GO

/* ---------------------------------------------------------------------
   14. BUOIHOC - Từng buổi học cụ thể (sinh tự động từ LICHHOC)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.BUOIHOC (
    MaBuoi      INT IDENTITY(1,1)  NOT NULL,
    MaLop       VARCHAR(10)        NOT NULL,
    STT         INT                NOT NULL,
    NgayHoc     DATE               NOT NULL,
    GioBatDau   TIME(0)            NOT NULL,
    GioKetThuc  TIME(0)            NOT NULL,
    MaPhong     VARCHAR(10)        NOT NULL,
    MaGV        VARCHAR(10)        NOT NULL,
    NoiDung     NVARCHAR(200)      NULL,
    TrangThai   NVARCHAR(20)       NOT NULL CONSTRAINT DF_BUOIHOC_TrangThai DEFAULT (N'Chưa dạy'),
    CONSTRAINT PK_BUOIHOC PRIMARY KEY (MaBuoi),
    CONSTRAINT FK_BUOIHOC_LOPHOC FOREIGN KEY (MaLop) REFERENCES dbo.LOPHOC (MaLop) ON DELETE CASCADE,
    CONSTRAINT FK_BUOIHOC_PHONGHOC FOREIGN KEY (MaPhong) REFERENCES dbo.PHONGHOC (MaPhong),
    CONSTRAINT FK_BUOIHOC_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES dbo.GIAOVIEN (MaGV),
    CONSTRAINT UQ_BUOIHOC_MaLop_STT UNIQUE (MaLop, STT),
    CONSTRAINT CK_BUOIHOC_STT CHECK (STT >= 1),
    CONSTRAINT CK_BUOIHOC_Gio CHECK (GioKetThuc > GioBatDau),
    CONSTRAINT CK_BUOIHOC_TrangThai CHECK (TrangThai IN (N'Chưa dạy', N'Đã dạy', N'Hủy'))
);
GO
CREATE INDEX IX_BUOIHOC_NgayHoc ON dbo.BUOIHOC (NgayHoc) INCLUDE (MaLop, MaGV, MaPhong, GioBatDau, GioKetThuc);
GO

/* ---------------------------------------------------------------------
   15. KHUYENMAI - Chương trình khuyến mãi học phí
   --------------------------------------------------------------------- */
CREATE TABLE dbo.KHUYENMAI (
    MaKM         VARCHAR(10)    NOT NULL,
    TenKM        NVARCHAR(100)  NOT NULL,
    LoaiGiam     VARCHAR(10)    NOT NULL,
    GiaTri       DECIMAL(12,2)  NOT NULL,
    NgayBatDau   DATE           NOT NULL,
    NgayKetThuc  DATE           NOT NULL,
    CONSTRAINT PK_KHUYENMAI PRIMARY KEY (MaKM),
    CONSTRAINT CK_KHUYENMAI_LoaiGiam CHECK (LoaiGiam IN ('PHANTRAM', 'SOTIEN')),
    CONSTRAINT CK_KHUYENMAI_GiaTri CHECK (GiaTri > 0 AND (LoaiGiam <> 'PHANTRAM' OR GiaTri <= 50)),
    CONSTRAINT CK_KHUYENMAI_Ngay CHECK (NgayKetThuc >= NgayBatDau)
);
GO

/* ---------------------------------------------------------------------
   16. GHIDANH - Học viên ghi danh vào lớp (quan hệ n-n HOCVIEN - LOPHOC)
       DaDong là thuộc tính dẫn xuất = SUM(PHIEUTHU.SoTien), do trigger duy trì.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.GHIDANH (
    MaGD            VARCHAR(10)    NOT NULL CONSTRAINT DF_GHIDANH_MaGD
                        DEFAULT ('GD' + RIGHT('000000' + CAST(NEXT VALUE FOR dbo.seq_GHIDANH AS VARCHAR(10)), 6)),
    MaHV            VARCHAR(10)    NOT NULL,
    MaLop           VARCHAR(10)    NOT NULL,
    NgayGhiDanh     DATE           NOT NULL CONSTRAINT DF_GHIDANH_NgayGhiDanh DEFAULT (CAST(GETDATE() AS DATE)),
    HocPhiGoc       DECIMAL(12,0)  NOT NULL,
    MaKM            VARCHAR(10)    NULL,
    SoTienGiam      DECIMAL(12,0)  NOT NULL CONSTRAINT DF_GHIDANH_SoTienGiam DEFAULT (0),
    HocPhiPhaiDong  AS (HocPhiGoc - SoTienGiam) PERSISTED,
    DaDong          DECIMAL(12,0)  NOT NULL CONSTRAINT DF_GHIDANH_DaDong DEFAULT (0),
    TrangThai       NVARCHAR(20)   NOT NULL CONSTRAINT DF_GHIDANH_TrangThai DEFAULT (N'Đang học'),
    DiemTongKet     DECIMAL(4,2)   NULL,
    KetQua          NVARCHAR(20)   NULL,
    MaNVGhiDanh     VARCHAR(10)    NULL,
    CONSTRAINT PK_GHIDANH PRIMARY KEY (MaGD),
    CONSTRAINT FK_GHIDANH_HOCVIEN FOREIGN KEY (MaHV) REFERENCES dbo.HOCVIEN (MaHV),
    CONSTRAINT FK_GHIDANH_LOPHOC FOREIGN KEY (MaLop) REFERENCES dbo.LOPHOC (MaLop),
    CONSTRAINT FK_GHIDANH_KHUYENMAI FOREIGN KEY (MaKM) REFERENCES dbo.KHUYENMAI (MaKM),
    CONSTRAINT FK_GHIDANH_NHANVIEN FOREIGN KEY (MaNVGhiDanh) REFERENCES dbo.NHANVIEN (MaNV),
    CONSTRAINT UQ_GHIDANH_MaHV_MaLop UNIQUE (MaHV, MaLop),
    CONSTRAINT CK_GHIDANH_HocPhiGoc CHECK (HocPhiGoc >= 0),
    CONSTRAINT CK_GHIDANH_SoTienGiam CHECK (SoTienGiam >= 0 AND SoTienGiam <= HocPhiGoc),
    -- Ràng buộc liên thuộc tính: số tiền đã đóng không vượt học phí phải đóng
    CONSTRAINT CK_GHIDANH_DaDong CHECK (DaDong >= 0 AND DaDong <= HocPhiGoc - SoTienGiam),
    CONSTRAINT CK_GHIDANH_TrangThai CHECK (TrangThai IN (N'Đang học', N'Bảo lưu', N'Đã nghỉ', N'Hoàn thành')),
    CONSTRAINT CK_GHIDANH_DiemTongKet CHECK (DiemTongKet BETWEEN 0 AND 10),
    CONSTRAINT CK_GHIDANH_KetQua CHECK (KetQua IN (N'Đạt', N'Không đạt'))
);
GO
CREATE INDEX IX_GHIDANH_MaLop ON dbo.GHIDANH (MaLop) INCLUDE (MaHV, TrangThai);
GO

/* ---------------------------------------------------------------------
   17. PHIEUTHU - Phiếu thu học phí (đóng nhiều đợt cho một lần ghi danh)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PHIEUTHU (
    MaPT       VARCHAR(10)    NOT NULL CONSTRAINT DF_PHIEUTHU_MaPT
                   DEFAULT ('PT' + RIGHT('000000' + CAST(NEXT VALUE FOR dbo.seq_PHIEUTHU AS VARCHAR(10)), 6)),
    MaGD       VARCHAR(10)    NOT NULL,
    NgayThu    DATETIME       NOT NULL CONSTRAINT DF_PHIEUTHU_NgayThu DEFAULT (GETDATE()),
    SoTien     DECIMAL(12,0)  NOT NULL,
    HinhThuc   NVARCHAR(20)   NOT NULL CONSTRAINT DF_PHIEUTHU_HinhThuc DEFAULT (N'Tiền mặt'),
    MaNVThu    VARCHAR(10)    NOT NULL,
    NoiDung    NVARCHAR(200)  NULL,
    TrangThai  NVARCHAR(20)   NOT NULL CONSTRAINT DF_PHIEUTHU_TrangThai DEFAULT (N'Hợp lệ'),
    LyDoHuy    NVARCHAR(200)  NULL,
    CONSTRAINT PK_PHIEUTHU PRIMARY KEY (MaPT),
    CONSTRAINT FK_PHIEUTHU_GHIDANH FOREIGN KEY (MaGD) REFERENCES dbo.GHIDANH (MaGD),
    CONSTRAINT FK_PHIEUTHU_NHANVIEN FOREIGN KEY (MaNVThu) REFERENCES dbo.NHANVIEN (MaNV),
    CONSTRAINT CK_PHIEUTHU_SoTien CHECK (SoTien > 0),
    CONSTRAINT CK_PHIEUTHU_HinhThuc CHECK (HinhThuc IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ')),
    CONSTRAINT CK_PHIEUTHU_TrangThai CHECK (TrangThai IN (N'Hợp lệ', N'Đã hủy')),
    CONSTRAINT CK_PHIEUTHU_LyDoHuy CHECK (TrangThai = N'Hợp lệ' OR LyDoHuy IS NOT NULL)
);
GO
CREATE INDEX IX_PHIEUTHU_MaGD ON dbo.PHIEUTHU (MaGD) INCLUDE (SoTien, TrangThai);
CREATE INDEX IX_PHIEUTHU_NgayThu ON dbo.PHIEUTHU (NgayThu) INCLUDE (SoTien, TrangThai, MaGD);
GO

/* ---------------------------------------------------------------------
   18. DIEMDANH - Điểm danh học viên theo buổi học
   --------------------------------------------------------------------- */
CREATE TABLE dbo.DIEMDANH (
    MaBuoi     INT            NOT NULL,
    MaGD       VARCHAR(10)    NOT NULL,
    TrangThai  NVARCHAR(20)   NOT NULL CONSTRAINT DF_DIEMDANH_TrangThai DEFAULT (N'Có mặt'),
    GhiChu     NVARCHAR(200)  NULL,
    CONSTRAINT PK_DIEMDANH PRIMARY KEY (MaBuoi, MaGD),
    CONSTRAINT FK_DIEMDANH_BUOIHOC FOREIGN KEY (MaBuoi) REFERENCES dbo.BUOIHOC (MaBuoi) ON DELETE CASCADE,
    CONSTRAINT FK_DIEMDANH_GHIDANH FOREIGN KEY (MaGD) REFERENCES dbo.GHIDANH (MaGD),
    CONSTRAINT CK_DIEMDANH_TrangThai CHECK (TrangThai IN (N'Có mặt', N'Đi trễ', N'Vắng có phép', N'Vắng không phép'))
);
GO

/* ---------------------------------------------------------------------
   19. DIEM - Điểm từng thành phần của học viên trong lớp
   --------------------------------------------------------------------- */
CREATE TABLE dbo.DIEM (
    MaGD       VARCHAR(10)   NOT NULL,
    MaTP       INT           NOT NULL,
    Diem       DECIMAL(4,2)  NOT NULL,
    NgayNhap   DATETIME      NOT NULL CONSTRAINT DF_DIEM_NgayNhap DEFAULT (GETDATE()),
    NguoiNhap  NVARCHAR(128) NOT NULL CONSTRAINT DF_DIEM_NguoiNhap DEFAULT (ORIGINAL_LOGIN()),
    CONSTRAINT PK_DIEM PRIMARY KEY (MaGD, MaTP),
    CONSTRAINT FK_DIEM_GHIDANH FOREIGN KEY (MaGD) REFERENCES dbo.GHIDANH (MaGD),
    CONSTRAINT FK_DIEM_THANHPHANDIEM FOREIGN KEY (MaTP) REFERENCES dbo.THANHPHANDIEM (MaTP),
    CONSTRAINT CK_DIEM_Diem CHECK (Diem BETWEEN 0 AND 10)
);
GO

/* ---------------------------------------------------------------------
   20. KIEMTRADAUVAO - Kiểm tra xếp lớp đầu vào (4 kỹ năng)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.KIEMTRADAUVAO (
    MaKT         VARCHAR(10)   NOT NULL CONSTRAINT DF_KIEMTRADAUVAO_MaKT
                     DEFAULT ('KT' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_KIEMTRA AS VARCHAR(10)), 5)),
    MaHV         VARCHAR(10)   NOT NULL,
    NgayKiemTra  DATE          NOT NULL CONSTRAINT DF_KIEMTRADAUVAO_Ngay DEFAULT (CAST(GETDATE() AS DATE)),
    DiemNghe     DECIMAL(4,2)  NOT NULL,
    DiemNoi      DECIMAL(4,2)  NOT NULL,
    DiemDoc      DECIMAL(4,2)  NOT NULL,
    DiemViet     DECIMAL(4,2)  NOT NULL,
    DiemTong     AS CAST((DiemNghe + DiemNoi + DiemDoc + DiemViet) / 4 AS DECIMAL(4,2)) PERSISTED,
    MaKHDeXuat   VARCHAR(10)   NULL,
    MaGVCham     VARCHAR(10)   NULL,
    GhiChu       NVARCHAR(200) NULL,
    CONSTRAINT PK_KIEMTRADAUVAO PRIMARY KEY (MaKT),
    CONSTRAINT FK_KIEMTRADAUVAO_HOCVIEN FOREIGN KEY (MaHV) REFERENCES dbo.HOCVIEN (MaHV),
    CONSTRAINT FK_KIEMTRADAUVAO_KHOAHOC FOREIGN KEY (MaKHDeXuat) REFERENCES dbo.KHOAHOC (MaKH),
    CONSTRAINT FK_KIEMTRADAUVAO_GIAOVIEN FOREIGN KEY (MaGVCham) REFERENCES dbo.GIAOVIEN (MaGV),
    CONSTRAINT CK_KIEMTRADAUVAO_Diem CHECK (
        DiemNghe BETWEEN 0 AND 10 AND DiemNoi BETWEEN 0 AND 10 AND
        DiemDoc  BETWEEN 0 AND 10 AND DiemViet BETWEEN 0 AND 10)
);
GO

/* ---------------------------------------------------------------------
   21. CHUNGCHI - Chứng nhận hoàn thành khóa học do trung tâm cấp
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CHUNGCHI (
    MaCC         VARCHAR(10)   NOT NULL CONSTRAINT DF_CHUNGCHI_MaCC
                     DEFAULT ('CC' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_CHUNGCHI AS VARCHAR(10)), 5)),
    MaGD         VARCHAR(10)   NOT NULL,
    SoHieu       VARCHAR(20)   NOT NULL,
    NgayCap      DATE          NOT NULL CONSTRAINT DF_CHUNGCHI_NgayCap DEFAULT (CAST(GETDATE() AS DATE)),
    DiemTongKet  DECIMAL(4,2)  NOT NULL,
    XepLoai      NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_CHUNGCHI PRIMARY KEY (MaCC),
    CONSTRAINT FK_CHUNGCHI_GHIDANH FOREIGN KEY (MaGD) REFERENCES dbo.GHIDANH (MaGD),
    CONSTRAINT UQ_CHUNGCHI_MaGD UNIQUE (MaGD),
    CONSTRAINT UQ_CHUNGCHI_SoHieu UNIQUE (SoHieu),
    CONSTRAINT CK_CHUNGCHI_DiemTongKet CHECK (DiemTongKet BETWEEN 5 AND 10),
    CONSTRAINT CK_CHUNGCHI_XepLoai CHECK (XepLoai IN (N'Xuất sắc', N'Giỏi', N'Khá', N'Trung bình'))
);
GO

/* ---------------------------------------------------------------------
   22. BANGLUONG - Bảng lương giáo viên theo tháng (chốt bằng cursor)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.BANGLUONG (
    MaBL       INT IDENTITY(1,1)  NOT NULL,
    MaGV       VARCHAR(10)        NOT NULL,
    Thang      TINYINT            NOT NULL,
    Nam        SMALLINT           NOT NULL,
    SoBuoi     INT                NOT NULL,
    SoGio      DECIMAL(6,2)       NOT NULL,
    DonGiaGio  DECIMAL(12,0)      NOT NULL,
    Thuong     DECIMAL(12,0)      NOT NULL CONSTRAINT DF_BANGLUONG_Thuong DEFAULT (0),
    KhauTru    DECIMAL(12,0)      NOT NULL CONSTRAINT DF_BANGLUONG_KhauTru DEFAULT (0),
    TongLuong  AS (CAST(SoGio * DonGiaGio AS DECIMAL(14,0)) + Thuong - KhauTru) PERSISTED,
    NgayChot   DATETIME           NOT NULL CONSTRAINT DF_BANGLUONG_NgayChot DEFAULT (GETDATE()),
    TrangThai  NVARCHAR(20)       NOT NULL CONSTRAINT DF_BANGLUONG_TrangThai DEFAULT (N'Đã chốt'),
    CONSTRAINT PK_BANGLUONG PRIMARY KEY (MaBL),
    CONSTRAINT FK_BANGLUONG_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES dbo.GIAOVIEN (MaGV),
    CONSTRAINT UQ_BANGLUONG_MaGV_Thang_Nam UNIQUE (MaGV, Thang, Nam),
    CONSTRAINT CK_BANGLUONG_Thang CHECK (Thang BETWEEN 1 AND 12),
    CONSTRAINT CK_BANGLUONG_Nam CHECK (Nam >= 2020),
    CONSTRAINT CK_BANGLUONG_SoLieu CHECK (SoBuoi >= 0 AND SoGio >= 0 AND Thuong >= 0 AND KhauTru >= 0),
    CONSTRAINT CK_BANGLUONG_TrangThai CHECK (TrangThai IN (N'Đã chốt', N'Đã chi trả'))
);
GO

/* ---------------------------------------------------------------------
   23. NHATKYHETHONG - Nhật ký kiểm toán (audit log), ghi bởi trigger
   --------------------------------------------------------------------- */
CREATE TABLE dbo.NHATKYHETHONG (
    MaNK           BIGINT IDENTITY(1,1)  NOT NULL,
    ThoiGian       DATETIME              NOT NULL CONSTRAINT DF_NHATKY_ThoiGian DEFAULT (GETDATE()),
    NguoiThucHien  NVARCHAR(128)         NOT NULL CONSTRAINT DF_NHATKY_NguoiThucHien DEFAULT (ORIGINAL_LOGIN()),
    BangDuLieu     NVARCHAR(50)          NOT NULL,
    HanhDong       VARCHAR(10)           NOT NULL,
    KhoaChinh      NVARCHAR(100)         NOT NULL,
    DuLieuCu       XML                   NULL,
    DuLieuMoi      XML                   NULL,
    CONSTRAINT PK_NHATKYHETHONG PRIMARY KEY (MaNK),
    CONSTRAINT CK_NHATKYHETHONG_HanhDong CHECK (HanhDong IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO
