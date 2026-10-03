#pragma once

#include "domain/common/Result.h"
#include "domain/entities/DashboardStats.h"

// Figures of the dashboard. Port (interface, see IStudentRepository.h): implemented by
// SqlStatisticsRepository, used by StatisticsService.
class IStatisticsRepository {
public:
    virtual ~IStatisticsRepository() = default;
    virtual Result<DashboardStats> dashboard() = 0; // one row of usp_Dashboard_Stats
    // Revenue of the 12 months of that year (fn_MonthlyRevenue returns a row for every month, 0 when empty);
    // fails for roles that are not granted the function (academic staff, teachers)
    virtual Result<QList<MonthlyRevenue>> monthlyRevenue(int year) = 0;
};
