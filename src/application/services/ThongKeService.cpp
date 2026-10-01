#include "application/services/ThongKeService.h"

ThongKeService::ThongKeService(IThongKeRepository& repository) : m_repository(repository) {}

Result<ThongKeTongQuan> ThongKeService::tongQuan() {
    return m_repository.tongQuan();
}

Result<QList<DoanhThuThang>> ThongKeService::doanhThuTheoThang(int nam) {
    if (nam < 2000 || nam > 2100)
        return Result<QList<DoanhThuThang>>::failure(QStringLiteral("Năm không hợp lệ."));
    return m_repository.doanhThuTheoThang(nam);
}
