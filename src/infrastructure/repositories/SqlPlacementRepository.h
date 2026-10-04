#pragma once

#include "application/ports/IPlacementRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IPlacementRepository with SQL Server: usp_PlacementTest_Search / _Add and the teachers who may grade a
// test.
class SqlPlacementRepository : public IPlacementRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlPlacementRepository)
public:
    explicit SqlPlacementRepository(DatabaseManager& db);
    Result<TableData> search(const QString& keyword, const QString& studentId) override;
    Result<PlacementResult> add(const PlacementTest& test) override;
    Result<QList<LookupItem>> graderOptions() override;

private:
    DatabaseManager& m_db;
};
