#include "application/services/HocVienService.h"

namespace {
// Chuẩn hóa dữ liệu nhập: bỏ khoảng trắng thừa, chuỗi rỗng coi như không có
HocVien chuanHoa(HocVien hv) {
    hv.hoTen = hv.hoTen.simplified();
    hv.soDienThoai = hv.soDienThoai.trimmed();
    hv.email = hv.email.trimmed().toLower();
    hv.diaChi = hv.diaChi.trimmed();
    hv.ngheNghiep = hv.ngheNghiep.trimmed();
    hv.tenPhuHuynh = hv.tenPhuHuynh.simplified();
    hv.sdtPhuHuynh = hv.sdtPhuHuynh.trimmed();
    hv.ghiChu = hv.ghiChu.trimmed();
    return hv;
}
} // namespace

HocVienService::HocVienService(IHocVienRepository& repository, IDanhMucRepository& danhMuc)
    : m_repository(repository), m_danhMuc(danhMuc) {}

Result<QList<HocVien>> HocVienService::timKiem(const BoLocHocVien& boLoc) {
    BoLocHocVien b = boLoc;
    b.tuKhoa = b.tuKhoa.trimmed();
    return m_repository.timKiem(b);
}

Result<HocVien> HocVienService::layChiTiet(const QString& maHV) {
    if (maHV.isEmpty())
        return Result<HocVien>::failure(QStringLiteral("Chưa chọn học viên."));
    return m_repository.layTheoMa(maHV);
}

Result<QString> HocVienService::themMoi(const HocVien& hocVien, const QDate& homNay) {
    const HocVien hv = chuanHoa(hocVien);
    const QStringList loi = hv.kiemTra(homNay);
    if (!loi.isEmpty())
        return Result<QString>::failure(loi.join(QLatin1Char('\n')));
    return m_repository.them(hv);
}

VoidResult HocVienService::capNhat(const HocVien& hocVien, const QDate& homNay) {
    if (hocVien.maHV.isEmpty())
        return VoidResult::failure(QStringLiteral("Thiếu mã học viên."));
    const HocVien hv = chuanHoa(hocVien);
    const QStringList loi = hv.kiemTra(homNay);
    if (!loi.isEmpty())
        return VoidResult::failure(loi.join(QLatin1Char('\n')));
    return m_repository.capNhat(hv);
}

VoidResult HocVienService::xoa(const QString& maHV) {
    if (maHV.isEmpty())
        return VoidResult::failure(QStringLiteral("Chưa chọn học viên."));
    return m_repository.xoa(maHV);
}

Result<QList<ChiNhanh>> HocVienService::danhSachChiNhanh() {
    return m_danhMuc.danhSachChiNhanh();
}
