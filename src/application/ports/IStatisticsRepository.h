#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ThongKe.h"

class IThongKeRepository {
public:
    virtual ~IThongKeRepository() = default;
    virtual Result<ThongKeTongQuan> tongQuan() = 0;
    virtual Result<QList<DoanhThuThang>> doanhThuTheoThang(int nam) = 0;
};
