#pragma once

#include "application/ports/ICauHinhStore.h"

// Lưu cấu hình bằng QSettings (Windows: Registry, macOS: file plist trong ~/Library/Preferences)
class QSettingsCauHinhStore : public ICauHinhStore {
public:
    CauHinhMayChu docCauHinh() const override;
    void luuCauHinh(const CauHinhMayChu& cauHinh) override;
    QString tenDangNhapGanNhat() const override;
    void luuTenDangNhap(const QString& tenDangNhap) override;
};
