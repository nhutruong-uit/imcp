#pragma once

#include "domain/entities/VaiTro.h"

#include <QString>

// Người dùng đang đăng nhập (đọc từ view dbo.vw_TaiKhoanHienTai sau khi SQL Server xác thực)
struct TaiKhoan {
    QString tenDangNhap;
    VaiTro vaiTro = VaiTro::KhongXacDinh;
    QString hoTen;
    QString maNV;
    QString maGV;
    QString maCN;
};
