#include "infrastructure/repositories/SqlStatisticsRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlStatisticsRepository::SqlStatisticsRepository(DatabaseManager& db) : m_db(db) {}

Result<DashboardStats> SqlStatisticsRepository::dashboard(const QString& branchId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Dashboard_Stats @BranchId = ?"),
                      {stringOrNull(branchId)}))
        return Result<DashboardStats>::failure(errorOf(q));
    // Columns: ActiveStudents, ActiveClasses, EnrollingClasses, RevenueThisMonth, TotalOutstanding,
    //          SessionsToday (one row)
    DashboardStats stats;
    if (q.next()) {
        stats.activeStudents = field(q, "ActiveStudents").toInt();
        stats.activeClasses = field(q, "ActiveClasses").toInt();
        stats.enrollingClasses = field(q, "EnrollingClasses").toInt();
        if (!field(q, "RevenueThisMonth").isNull()) // NULL: the current role may not see revenue
            stats.revenueThisMonth = field(q, "RevenueThisMonth").toLongLong();
        stats.outstandingTuition = field(q, "TotalOutstanding").toLongLong();
        stats.sessionsToday = field(q, "SessionsToday").toInt();
    }
    return Result<DashboardStats>::success(stats);
}

Result<QList<MonthlyRevenue>> SqlStatisticsRepository::monthlyRevenue(int year, const QString& branchId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db,
                      QStringLiteral("SELECT Month, Revenue FROM dbo.fn_MonthlyRevenue(?, ?) ORDER BY Month"),
                      {year, stringOrNull(branchId)}))
        return Result<QList<MonthlyRevenue>>::failure(errorOf(q));
    QList<MonthlyRevenue> months;
    while (q.next())
        months.append({field(q, "Month").toInt(), field(q, "Revenue").toLongLong()});
    return afterRead(q, months);
}

Result<TableData> SqlStatisticsRepository::revenueReport(const QDate& from, const QDate& to,
                                                         const QString& branchId) {
    return queryTable(m_db,
                      QStringLiteral("EXEC dbo.usp_Report_Revenue @FromDate = ?, @ToDate = ?, @BranchId = ?"),
                      {from, to, stringOrNull(branchId)});
}
