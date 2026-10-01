#pragma once

#include "application/ports/IAuthGateway.h"
#include "application/ports/ICauHinhStore.h"

#include <optional>

// Use case: đăng nhập / đăng xuất / đổi mật khẩu, giữ thông tin phiên làm việc
class AuthService {
public:
    AuthService(IAuthGateway& gateway, ICauHinhStore& store);

    CauHinhMayChu cauHinh() const;
    void luuCauHinh(const CauHinhMayChu& cauHinh);
    QString tenDangNhapGanNhat() const;

    Result<TaiKhoan> dangNhap(const QString& tenDangNhap, const QString& matKhau);
    void dangXuat();
    VoidResult doiMatKhau(const QString& matKhauCu, const QString& matKhauMoi, const QString& nhapLai);

    bool daDangNhap() const { return m_taiKhoan.has_value(); }
    const TaiKhoan& taiKhoan() const { return *m_taiKhoan; }
    VaiTro vaiTro() const { return m_taiKhoan ? m_taiKhoan->vaiTro : VaiTro::KhongXacDinh; }

private:
    IAuthGateway& m_gateway;
    ICauHinhStore& m_store;
    std::optional<TaiKhoan> m_taiKhoan;
};
