#include "application/services/StatisticsService.h"

StatisticsService::StatisticsService(IStatisticsRepository& repository) : m_repository(repository) {}

Result<DashboardStats> StatisticsService::dashboard(const QString& branchId) {
    return m_repository.dashboard(branchId);
}

Result<QList<MonthlyRevenue>> StatisticsService::monthlyRevenue(int year, const QString& branchId) {
    // A sanity check of the input: an impossible year never reaches the database
    if (year < 2000 || year > 2100)
        return Result<QList<MonthlyRevenue>>::failure(tr("Invalid year."));
    return m_repository.monthlyRevenue(year, branchId);
}

Result<TableData> StatisticsService::revenueReport(const QDate& from, const QDate& to,
                                                   const QString& branchId) {
    if (!from.isValid() || !to.isValid())
        return Result<TableData>::failure(tr("Invalid dates."));
    if (from > to)
        return Result<TableData>::failure(tr("The start date must not be after the end date."));
    return m_repository.revenueReport(from, to, branchId);
}
