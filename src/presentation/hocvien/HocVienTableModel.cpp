#include "presentation/hocvien/HocVienTableModel.h"

#include "presentation/common/Format.h"

#include <QColor>

HocVienTableModel::HocVienTableModel(QObject* parent) : QAbstractTableModel(parent) {}

void HocVienTableModel::setDanhSach(QList<HocVien> danhSach) {
    beginResetModel();
    m_ds = std::move(danhSach);
    endResetModel();
}

const HocVien* HocVienTableModel::hocVienTai(int dong) const {
    return (dong >= 0 && dong < m_ds.size()) ? &m_ds.at(dong) : nullptr;
}

int HocVienTableModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_ds.size());
}

int HocVienTableModel::columnCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : SoCot;
}

QVariant HocVienTableModel::data(const QModelIndex& index, int role) const {
    const HocVien* hv = hocVienTai(index.row());
    if (!hv)
        return {};

    if (role == Qt::DisplayRole || role == Qt::UserRole) {
        const bool tho = role == Qt::UserRole;   // giá trị gốc để sắp xếp
        switch (index.column()) {
        case MaHV: return hv->maHV;
        case HoTen: return hv->hoTen;
        case NgaySinh: return tho ? QVariant(hv->ngaySinh) : QVariant(Format::ngay(hv->ngaySinh));
        case GioiTinh: return hv->gioiTinh;
        case SoDienThoai: return hv->soDienThoai;
        case PhuHuynh: return hv->tenPhuHuynh;
        case SdtPhuHuynh: return hv->sdtPhuHuynh;
        case ChiNhanh: return hv->tenCN;
        case NgayDangKy: return tho ? QVariant(hv->ngayDangKy) : QVariant(Format::ngay(hv->ngayDangKy));
        case TrangThai: return hv->trangThai;
        case SoLop: return hv->soLopDangHoc;
        case CongNo: return tho ? QVariant(hv->tongConNo) : QVariant(hv->tongConNo > 0 ? Format::tien(hv->tongConNo) : QString());
        default: return {};
        }
    }
    if (role == Qt::TextAlignmentRole && (index.column() == SoLop || index.column() == CongNo))
        return QVariant::fromValue(Qt::AlignRight | Qt::AlignVCenter);
    if (role == Qt::ForegroundRole) {
        if (index.column() == CongNo && hv->tongConNo > 0)
            return QColor(0xDC, 0x26, 0x26);
        if (index.column() == TrangThai && hv->trangThai == QStringLiteral("Đang học"))
            return QColor(0x15, 0x80, 0x3D);
    }
    return {};
}

QVariant HocVienTableModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole)
        return QAbstractTableModel::headerData(section, orientation, role);
    static const QStringList tieuDe = {
        QStringLiteral("Mã HV"),     QStringLiteral("Họ tên"),       QStringLiteral("Ngày sinh"),
        QStringLiteral("Giới tính"), QStringLiteral("Điện thoại"),   QStringLiteral("Phụ huynh"),
        QStringLiteral("SĐT phụ huynh"), QStringLiteral("Chi nhánh"), QStringLiteral("Ngày đăng ký"),
        QStringLiteral("Trạng thái"), QStringLiteral("Lớp đang học"), QStringLiteral("Công nợ")};
    return tieuDe.value(section);
}
