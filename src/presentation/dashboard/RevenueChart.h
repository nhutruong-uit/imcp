#pragma once

#include "domain/entities/ThongKe.h"

#include <QWidget>

// Biểu đồ cột doanh thu 12 tháng, tự vẽ bằng QPainter (không cần thêm thư viện biểu đồ)
class RevenueChart : public QWidget {
    Q_OBJECT
public:
    explicit RevenueChart(QWidget* parent = nullptr);
    void setDuLieu(const QList<DoanhThuThang>& duLieu);
    void setThongBao(const QString& thongBao);

protected:
    void paintEvent(QPaintEvent* event) override;

private:
    QList<DoanhThuThang> m_duLieu;
    QString m_thongBao;
};
