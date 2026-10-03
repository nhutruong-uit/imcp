#pragma once

#include "application/ports/IStatisticsRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Implements the port IStatisticsRepository: dashboard figures (usp_Dashboard_Stats), the monthly revenue
// chart (fn_MonthlyRevenue) and the revenue per course of a period (usp_Report_Revenue)
class SqlStatisticsRepository : public IStatisticsRepository {
public:
    explicit SqlStatisticsRepository(DatabaseManager& db);
    Result<DashboardStats> dashboard(const QString& branchId) override;
    Result<QList<MonthlyRevenue>> monthlyRevenue(int year, const QString& branchId) override;
    Result<TableData> revenueReport(const QDate& from, const QDate& to, const QString& branchId) override;

private:
    DatabaseManager& m_db;
};
