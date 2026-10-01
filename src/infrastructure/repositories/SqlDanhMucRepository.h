#pragma once

#include "application/ports/IDanhMucRepository.h"
#include "infrastructure/db/DatabaseManager.h"

class SqlDanhMucRepository : public IDanhMucRepository {
public:
    explicit SqlDanhMucRepository(DatabaseManager& db);
    Result<QList<ChiNhanh>> danhSachChiNhanh() override;

private:
    DatabaseManager& m_db;
};
