#include "application/services/AuthService.h"

AuthService::AuthService(IAuthGateway& gateway, ICauHinhStore& store) : m_gateway(gateway), m_store(store) {}

CauHinhMayChu AuthService::cauHinh() const {
    return m_store.docCauHinh();
}

void AuthService::luuCauHinh(const CauHinhMayChu& cauHinh) {
    m_store.luuCauHinh(cauHinh);
}

QString AuthService::tenDangNhapGanNhat() const {
    return m_store.tenDangNhapGanNhat();
}

Result<TaiKhoan> AuthService::dangNhap(const QString& tenDangNhap, const QString& matKhau) {
    const QString ten = tenDangNhap.trimmed();
    if (ten.isEmpty() || matKhau.isEmpty())
        return Result<TaiKhoan>::failure(QStringLiteral("Vui lòng nhập tên đăng nhập và mật khẩu."));

    const CauHinhMayChu cauHinh = m_store.docCauHinh();
    if (cauHinh.mayChu.trimmed().isEmpty() || cauHinh.csdl.trimmed().isEmpty())
        return Result<TaiKhoan>::failure(QStringLiteral("Chưa cấu hình máy chủ CSDL."));

    auto ketQua = m_gateway.dangNhap(cauHinh, ten, matKhau);
    if (!ketQua.ok())
        return ketQua;

    if (ketQua.value().vaiTro == VaiTro::KhongXacDinh) {
        m_gateway.dangXuat();
        return Result<TaiKhoan>::failure(
            QStringLiteral("Tài khoản SQL Server hợp lệ nhưng chưa được gán vai trò trong hệ thống."));
    }

    m_store.luuTenDangNhap(ten);
    m_taiKhoan = ketQua.value();
    return ketQua;
}

void AuthService::dangXuat() {
    m_gateway.dangXuat();
    m_taiKhoan.reset();
}

VoidResult AuthService::doiMatKhau(const QString& matKhauCu, const QString& matKhauMoi, const QString& nhapLai) {
    if (!daDangNhap())
        return VoidResult::failure(QStringLiteral("Bạn chưa đăng nhập."));
    if (matKhauMoi.size() < 8)
        return VoidResult::failure(QStringLiteral("Mật khẩu mới tối thiểu 8 ký tự."));
    if (matKhauMoi != nhapLai)
        return VoidResult::failure(QStringLiteral("Mật khẩu nhập lại không khớp."));
    if (matKhauMoi == matKhauCu)
        return VoidResult::failure(QStringLiteral("Mật khẩu mới phải khác mật khẩu cũ."));
    return m_gateway.doiMatKhau(matKhauCu, matKhauMoi);
}
