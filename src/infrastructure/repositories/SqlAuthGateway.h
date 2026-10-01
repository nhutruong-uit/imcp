#pragma once

#include "application/ports/IAuthGateway.h"
#include "infrastructure/db/DatabaseManager.h"

// Đăng nhập = mở kết nối SQL Server bằng tài khoản người dùng (contained database user),
// sau đó đọc vai trò từ dbo.usp_TaiKhoan_GhiNhanDangNhap.
class SqlAuthGateway : public IAuthGateway {
public:
    explicit SqlAuthGateway(DatabaseManager& db);
    Result<TaiKhoan> dangNhap(const CauHinhMayChu& cauHinh, const QString& tenDangNhap,
                              const QString& matKhau) override;
    void dangXuat() override;
    VoidResult doiMatKhau(const QString& matKhauCu, const QString& matKhauMoi) override;

private:
    DatabaseManager& m_db;
};
