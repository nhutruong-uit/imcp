#pragma once

#include "application/ports/IStatisticsRepository.h"

#include <QCoreApplication>

// Dashboard and report use case: key figures and revenue per month (DashboardPage, for the whole center or
// one branch) and the revenue per course of a period (RevenuePage). branchId empty = the whole center.
class StatisticsService {
    Q_DECLARE_TR_FUNCTIONS(StatisticsService)
public:
    explicit StatisticsService(IStatisticsRepository& repository);
    Result<DashboardStats> dashboard(const QString& branchId = QString());
    Result<QList<MonthlyRevenue>> monthlyRevenue(int year, const QString& branchId = QString());
    Result<TableData> revenueReport(const QDate& from, const QDate& to, const QString& branchId = QString());

private:
    IStatisticsRepository& m_repository;
};
