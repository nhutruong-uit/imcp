#pragma once

#include <QString>

// Vai trò người dùng - tương ứng các ROLE trong SQL Server (rl_QuanLy, rl_GiaoVu, ...)
enum class VaiTro { QuanLy, GiaoVu, KeToan, GiaoVien, KhongXacDinh };

// "QUANLY" -> VaiTro::QuanLy (mã lưu trong cột TAIKHOAN.VaiTro)
VaiTro vaiTroTuMa(const QString& ma);
QString maVaiTro(VaiTro vaiTro);
QString tenVaiTro(VaiTro vaiTro);
