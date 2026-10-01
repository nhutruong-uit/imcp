#pragma once

#include "presentation/main/AppServices.h"

#include <QWidget>

class QLabel;
class RevenueChart;

// Trang Tổng quan: các chỉ số chính + biểu đồ doanh thu năm hiện tại
class DashboardPage : public QWidget {
    Q_OBJECT
public:
    explicit DashboardPage(AppServices services, QWidget* parent = nullptr);

public slots:
    void taiLai();

private:
    QWidget* taoThe(const QString& tieuDe, const QString& icon, QLabel** giaTri);

    AppServices m_services;
    QLabel* m_hocVien = nullptr;
    QLabel* m_lopDangHoc = nullptr;
    QLabel* m_lopTuyenSinh = nullptr;
    QLabel* m_doanhThu = nullptr;
    QLabel* m_congNo = nullptr;
    QLabel* m_buoiHoc = nullptr;
    QLabel* m_loi = nullptr;
    RevenueChart* m_bieuDo = nullptr;
};
