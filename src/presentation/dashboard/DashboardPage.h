#pragma once

#include "presentation/main/AppServices.h"

#include <QWidget>

class QComboBox;
class QLabel;
class RevenueChart;

// Overview page: key figures + revenue chart of the current year, for the whole center or one branch
// Data: StatisticsService -> usp_Dashboard_Stats (cards) and fn_MonthlyRevenue (chart). A role that may not
// see revenue (academic staff) gets "No permission" on that card - the procedure returns NULL for it - and a
// message instead of the chart, because SQL Server refuses fn_MonthlyRevenue to that role.
class DashboardPage : public QWidget {
    Q_OBJECT
public:
    explicit DashboardPage(AppServices services, QWidget* parent = nullptr);

public slots:
    void reload();

private:
    // One figure card; the new value label is stored in *value, and reload() fills it later
    QWidget* buildCard(const QString& title, const QString& icon, QLabel** value);

    AppServices m_services;
    QComboBox* m_branch = nullptr;
    QLabel* m_activeStudents = nullptr;
    QLabel* m_activeClasses = nullptr;
    QLabel* m_enrollingClasses = nullptr;
    QLabel* m_revenue = nullptr;
    QLabel* m_outstanding = nullptr;
    QLabel* m_sessionsToday = nullptr;
    QLabel* m_error = nullptr;
    RevenueChart* m_chart = nullptr;
};
