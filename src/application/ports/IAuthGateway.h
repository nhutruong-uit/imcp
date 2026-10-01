#pragma once

#include "domain/common/Result.h"
#include "domain/entities/CauHinhMayChu.h"
#include "domain/entities/TaiKhoan.h"

// Cổng xác thực: hiện thực ở tầng infrastructure bằng cách mở kết nối SQL Server
// với chính tên đăng nhập/mật khẩu người dùng (xác thực do DBMS đảm nhiệm).
class IAuthGateway {
public:
    virtual ~IAuthGateway() = default;
    virtual Result<TaiKhoan> dangNhap(const CauHinhMayChu& cauHinh, const QString& tenDangNhap,
                                      const QString& matKhau) = 0;
    virtual void dangXuat() = 0;
    virtual VoidResult doiMatKhau(const QString& matKhauCu, const QString& matKhauMoi) = 0;
};
