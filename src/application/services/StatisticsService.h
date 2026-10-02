#pragma once

#include "application/ports/IThongKeRepository.h"

class ThongKeService {
public:
    explicit ThongKeService(IThongKeRepository& repository);
    Result<ThongKeTongQuan> tongQuan();
    Result<QList<DoanhThuThang>> doanhThuTheoThang(int nam);

private:
    IThongKeRepository& m_repository;
};
