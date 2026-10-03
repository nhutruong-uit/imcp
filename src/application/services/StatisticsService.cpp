#include "application/services/StatisticsService.h"

StatisticsService::StatisticsService(IStatisticsRepository& repository) : m_repository(repository) {}

Result<DashboardStats> StatisticsService::dashboard() {
    return m_repository.dashboard();
}

Result<QList<MonthlyRevenue>> StatisticsService::monthlyRevenue(int year) {
    // A sanity check of the input: an impossible year never reaches the database
    if (year < 2000 || year > 2100)
        return Result<QList<MonthlyRevenue>>::failure(tr("Invalid year."));
    return m_repository.monthlyRevenue(year);
}
