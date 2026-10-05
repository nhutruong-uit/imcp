#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/DashboardStats.h"

#include <QDate>

// Figures of the dashboard and the revenue report. Port (interface, see IStudentRepository.h): implemented by
// SqlStatisticsRepository, used by StatisticsService. branchId empty = the whole center.
class IStatisticsRepository {
public:
    virtual ~IStatisticsRepository() = default;
    virtual Result<DashboardStats> dashboard(const QString& branchId) = 0; // one row of usp_Dashboard_Stats
    // Revenue of the 12 months of that year (fn_MonthlyRevenue returns a row for every month, 0 when empty);
    // fails for roles that are not granted the function (academic staff, teachers)
    virtual Result<QList<MonthlyRevenue>> monthlyRevenue(int year, const QString& branchId) = 0;
    // usp_Report_Revenue: revenue per branch, program and course between two days of the center
    virtual Result<TableData> revenueReport(const QDate& from, const QDate& to, const QString& branchId) = 0;
};
