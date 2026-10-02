#include "infrastructure/config/QSettingsCauHinhStore.h"

#include <QSettings>

CauHinhMayChu QSettingsCauHinhStore::docCauHinh() const {
    QSettings s;
    CauHinhMayChu macDinh;
    CauHinhMayChu c;
    c.mayChu = s.value(QStringLiteral("server/host"), macDinh.mayChu).toString();
    c.csdl = s.value(QStringLiteral("server/database"), macDinh.csdl).toString();
    c.tinCayChungChi = s.value(QStringLiteral("server/trustCertificate"), macDinh.tinCayChungChi).toBool();
    return c;
}

void QSettingsCauHinhStore::luuCauHinh(const CauHinhMayChu& cauHinh) {
    QSettings s;
    s.setValue(QStringLiteral("server/host"), cauHinh.mayChu.trimmed());
    s.setValue(QStringLiteral("server/database"), cauHinh.csdl.trimmed());
    s.setValue(QStringLiteral("server/trustCertificate"), cauHinh.tinCayChungChi);
}

QString QSettingsCauHinhStore::tenDangNhapGanNhat() const {
    return QSettings().value(QStringLiteral("login/lastUser")).toString();
}

void QSettingsCauHinhStore::luuTenDangNhap(const QString& tenDangNhap) {
    QSettings().setValue(QStringLiteral("login/lastUser"), tenDangNhap);
}
