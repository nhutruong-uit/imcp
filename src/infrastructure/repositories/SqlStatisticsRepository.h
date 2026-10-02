#pragma once

#include "application/ports/IStatisticsRepository.h"
#include "infrastructure/db/DatabaseManager.h"

class SqlStatisticsRepository : public IStatisticsRepository {
public:
    explicit SqlStatisticsRepository(DatabaseManager& db);
    Result<DashboardStats> dashboard() override;
    Result<QList<MonthlyRevenue>> monthlyRevenue(int year) override;

private:
    DatabaseManager& m_db;
};
