#pragma once

#include "domain/common/Result.h"
#include "domain/entities/DashboardStats.h"

class IStatisticsRepository {
public:
    virtual ~IStatisticsRepository() = default;
    virtual Result<DashboardStats> dashboard() = 0;
    virtual Result<QList<MonthlyRevenue>> monthlyRevenue(int year) = 0;
};
