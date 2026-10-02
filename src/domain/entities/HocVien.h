#pragma once

#include <QDate>
#include <QString>
#include <QStringList>

// Các giá trị hợp lệ - trùng khớp ràng buộc CHECK của bảng HOCVIEN
namespace HocVienGiaTri {
QStringList gioiTinh();      // Nam, Nữ, Khác
QStringList trangThai();     // Tiềm năng, Đang học, Bảo lưu, Ngừng học
} // namespace HocVienGiaTri

// Thực thể Học viên (bảng HOCVIEN) + vài thông tin tổng hợp khi hiển thị danh sách
struct HocVien {
    QString maHV;
    QString hoTen;
    QDate ngaySinh;
    QString gioiTinh = QStringLiteral("Nam");
    QString soDienThoai;
    QString email;
    QString diaChi;
    QString ngheNghiep;
    QString tenPhuHuynh;
    QString sdtPhuHuynh;
    QString maCN;
    QDate ngayDangKy;
    QString trangThai = QStringLiteral("Tiềm năng");
    QString ghiChu;

    // Chỉ dùng khi hiển thị (lấy từ view vw_HocVien_TongQuan)
    QString tenCN;
    int soLopDangHoc = 0;
    qint64 tongConNo = 0;

    int tuoi(const QDate& tinhDen) const;
    bool canThongTinPhuHuynh(const QDate& tinhDen) const;

    // Quy tắc nghiệp vụ kiểm tra ngay tại ứng dụng (phản hồi nhanh cho người dùng).
    // CSDL vẫn là nơi kiểm tra cuối cùng bằng CHECK/trigger/thủ tục.
    QStringList kiemTra(const QDate& homNay) const;
};

// Điều kiện tìm kiếm học viên
struct BoLocHocVien {
    QString tuKhoa;
    QString maCN;       // rỗng = tất cả chi nhánh
    QString trangThai;  // rỗng = tất cả trạng thái
};
