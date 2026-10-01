#pragma once

#include "application/services/PhanQuyen.h"
#include "presentation/main/AppServices.h"

#include <QWidget>

class QLabel;
class QLineEdit;
class QSortFilterProxyModel;
class QTableView;
class TableDataModel;

// Trang tra cứu dùng chung cho các danh sách chỉ đọc (lớp học, công nợ, lịch dạy...):
// lọc nhanh, sắp xếp, dòng tổng cho cột tiền, xuất Excel/PDF.
class DanhSachPage : public QWidget {
    Q_OBJECT
public:
    DanhSachPage(AppServices services, ChucNang chucNang, QWidget* parent = nullptr);

public slots:
    void taiLai();

private:
    void capNhatTong();

    AppServices m_services;
    ChucNang m_chucNang;
    QLineEdit* m_loc = nullptr;
    QTableView* m_bang = nullptr;
    TableDataModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QLabel* m_tong = nullptr;
};
