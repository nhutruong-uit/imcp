#pragma once

#include "application/ports/IStatisticsRepository.h"

#include <QCoreApplication>

// Dashboard use case: key figures and revenue per month
class StatisticsService {
    Q_DECLARE_TR_FUNCTIONS(StatisticsService)
public:
    explicit StatisticsService(IStatisticsRepository& repository);
    Result<DashboardStats> dashboard();
    Result<QList<MonthlyRevenue>> monthlyRevenue(int year);

private:
    IStatisticsRepository& m_repository;
};
