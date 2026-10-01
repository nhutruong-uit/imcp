#pragma once

#include "application/ports/IThongKeRepository.h"
#include "infrastructure/db/DatabaseManager.h"

class SqlThongKeRepository : public IThongKeRepository {
public:
    explicit SqlThongKeRepository(DatabaseManager& db);
    Result<ThongKeTongQuan> tongQuan() override;
    Result<QList<DoanhThuThang>> doanhThuTheoThang(int nam) override;

private:
    DatabaseManager& m_db;
};
