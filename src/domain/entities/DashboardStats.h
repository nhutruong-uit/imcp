#pragma once

#include <QList>
#include <optional>

// Key figures of the dashboard (procedure dbo.usp_Dashboard_Stats), shown as the cards of DashboardPage.
// Money is a whole number of dong (qint64 = 64-bit integer; the database stores DECIMAL(12,0)).
struct DashboardStats {
    int activeStudents = 0;
    int activeClasses = 0;
    int enrollingClasses = 0;
    std::optional<qint64> revenueThisMonth; // empty = the user's role may not see revenue
    qint64 outstandingTuition = 0;
    int sessionsToday = 0;
};

// Revenue of one month (function dbo.fn_MonthlyRevenue), one bar of the dashboard chart (RevenueChart)
struct MonthlyRevenue {
    int month = 0;
    qint64 revenue = 0;
};
