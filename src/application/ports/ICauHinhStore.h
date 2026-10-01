#pragma once

#include "domain/entities/CauHinhMayChu.h"

// Lưu/đọc cấu hình máy chủ và tên đăng nhập gần nhất (không lưu mật khẩu)
class ICauHinhStore {
public:
    virtual ~ICauHinhStore() = default;
    virtual CauHinhMayChu docCauHinh() const = 0;
    virtual void luuCauHinh(const CauHinhMayChu& cauHinh) = 0;
    virtual QString tenDangNhapGanNhat() const = 0;
    virtual void luuTenDangNhap(const QString& tenDangNhap) = 0;
};
