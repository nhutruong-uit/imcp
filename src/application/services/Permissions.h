#pragma once

#include "domain/entities/VaiTro.h"

#include <QList>
#include <QString>

// Chức năng (mục menu) của ứng dụng
enum class ChucNang {
    TongQuan,
    HocVien,
    LopHoc,
    LichHoc,
    KetQuaHocTap,
    CongNo,
    DoanhThu,
    BangLuong,
    TaiKhoan,
    LopCuaToi,
    LichDayCuaToi,
    LuongCuaToi
};

struct ThongTinChucNang {
    ChucNang id;
    QString ten;
    QString icon;    // tên file trong resources/icons (không có đuôi .svg)
    QString nhom;    // nhóm hiển thị trên menu
};

// Ma trận phân quyền phía ứng dụng: quyết định menu nào được HIỂN THỊ.
// Quyền thật sự vẫn do SQL Server kiểm soát bằng GRANT/DENY trên role (06_security.sql);
// nếu ứng dụng có lỗi hiển thị nhầm, CSDL vẫn từ chối truy cập.
class PhanQuyen {
public:
    static QList<ChucNang> chucNangDuocPhep(VaiTro vaiTro);
    static bool duocPhep(VaiTro vaiTro, ChucNang chucNang);
    static bool duocSuaHocVien(VaiTro vaiTro);
    static ThongTinChucNang thongTin(ChucNang chucNang);
};
