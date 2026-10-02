#include "domain/entities/VaiTro.h"

VaiTro vaiTroTuMa(const QString& ma) {
    const QString m = ma.trimmed().toUpper();
    if (m == QLatin1String("QUANLY"))
        return VaiTro::QuanLy;
    if (m == QLatin1String("GIAOVU"))
        return VaiTro::GiaoVu;
    if (m == QLatin1String("KETOAN"))
        return VaiTro::KeToan;
    if (m == QLatin1String("GIAOVIEN"))
        return VaiTro::GiaoVien;
    return VaiTro::KhongXacDinh;
}

QString maVaiTro(VaiTro vaiTro) {
    switch (vaiTro) {
    case VaiTro::QuanLy:
        return QStringLiteral("QUANLY");
    case VaiTro::GiaoVu:
        return QStringLiteral("GIAOVU");
    case VaiTro::KeToan:
        return QStringLiteral("KETOAN");
    case VaiTro::GiaoVien:
        return QStringLiteral("GIAOVIEN");
    case VaiTro::KhongXacDinh:
        break;
    }
    return QString();
}

QString tenVaiTro(VaiTro vaiTro) {
    switch (vaiTro) {
    case VaiTro::QuanLy:
        return QStringLiteral("Quản lý");
    case VaiTro::GiaoVu:
        return QStringLiteral("Giáo vụ");
    case VaiTro::KeToan:
        return QStringLiteral("Kế toán");
    case VaiTro::GiaoVien:
        return QStringLiteral("Giáo viên");
    case VaiTro::KhongXacDinh:
        break;
    }
    return QStringLiteral("Không xác định");
}
