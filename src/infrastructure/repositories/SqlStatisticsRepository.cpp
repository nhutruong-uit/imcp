#include "infrastructure/repositories/SqlStatisticsRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlStatisticsRepository::SqlStatisticsRepository(DatabaseManager& db) : m_db(db) {}

Result<DashboardStats> SqlStatisticsRepository::dashboard() {
    QSqlQuery q = makeQuery(m_db.db());
    if (!q.exec(QStringLiteral("EXEC dbo.usp_Dashboard_Stats")))
        return Result<DashboardStats>::failure(errorOf(q));
    DashboardStats stats;
    if (q.next()) {
        stats.activeStudents = q.value(0).toInt();
        stats.activeClasses = q.value(1).toInt();
        stats.enrollingClasses = q.value(2).toInt();
        if (!q.value(3).isNull()) // NULL: the current role may not see revenue
            stats.revenueThisMonth = q.value(3).toLongLong();
        stats.outstandingTuition = q.value(4).toLongLong();
        stats.sessionsToday = q.value(5).toInt();
    }
    return Result<DashboardStats>::success(stats);
}

Result<QList<MonthlyRevenue>> SqlStatisticsRepository::monthlyRevenue(int year) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT Month, Revenue FROM dbo.fn_MonthlyRevenue(?, NULL) ORDER BY Month"),
            {year}))
        return Result<QList<MonthlyRevenue>>::failure(errorOf(q));
    QList<MonthlyRevenue> months;
    while (q.next())
        months.append({q.value(0).toInt(), q.value(1).toLongLong()});
    return Result<QList<MonthlyRevenue>>::success(months);
}
