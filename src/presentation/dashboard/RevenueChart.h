#pragma once

#include "domain/entities/DashboardStats.h"

#include <QWidget>

// Bar chart of the revenue of 12 months, painted with QPainter (no chart library needed)
class RevenueChart : public QWidget {
    Q_OBJECT
public:
    explicit RevenueChart(QWidget* parent = nullptr);
    void setData(const QList<MonthlyRevenue>& data);
    void setMessage(const QString& message);

protected:
    void paintEvent(QPaintEvent* event) override;

private:
    QList<MonthlyRevenue> m_data;
    QString m_message;
};
