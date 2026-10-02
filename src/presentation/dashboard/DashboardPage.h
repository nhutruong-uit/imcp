#pragma once

#include "presentation/main/AppServices.h"

#include <QWidget>

class QLabel;
class RevenueChart;

// Overview page: key figures + revenue chart of the current year
class DashboardPage : public QWidget {
    Q_OBJECT
public:
    explicit DashboardPage(AppServices services, QWidget* parent = nullptr);

public slots:
    void reload();

private:
    QWidget* buildCard(const QString& title, const QString& icon, QLabel** value);

    AppServices m_services;
    QLabel* m_activeStudents = nullptr;
    QLabel* m_activeClasses = nullptr;
    QLabel* m_enrollingClasses = nullptr;
    QLabel* m_revenue = nullptr;
    QLabel* m_outstanding = nullptr;
    QLabel* m_sessionsToday = nullptr;
    QLabel* m_error = nullptr;
    RevenueChart* m_chart = nullptr;
};
