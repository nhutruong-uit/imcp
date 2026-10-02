#pragma once

#include <QList>
#include <optional>

// Key figures of the dashboard (procedure dbo.usp_Dashboard_Stats)
struct DashboardStats {
    int activeStudents = 0;
    int activeClasses = 0;
    int enrollingClasses = 0;
    std::optional<qint64> revenueThisMonth; // empty = the user's role may not see revenue
    qint64 outstandingTuition = 0;
    int sessionsToday = 0;
};

// Revenue of one month (function dbo.fn_MonthlyRevenue)
struct MonthlyRevenue {
    int month = 0;
    qint64 revenue = 0;
};
