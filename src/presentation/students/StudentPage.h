#pragma once

#include "domain/entities/ChiNhanh.h"
#include "domain/entities/HocVien.h"
#include "presentation/main/AppServices.h"

#include <QWidget>

class HocVienTableModel;
class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QSortFilterProxyModel;
class QTableView;
class QTimer;

// Module mẫu (reference implementation) - các module khác làm theo cấu trúc này:
//   Page (giao diện) -> Service (use case) -> Repository interface -> Sql...Repository -> thủ tục SQL
class HocVienPage : public QWidget {
    Q_OBJECT
public:
    explicit HocVienPage(AppServices services, QWidget* parent = nullptr);

private slots:
    void timKiem();
    void them();
    void sua();
    void xoa();

private:
    const HocVien* hocVienDangChon() const;
    void chonLaiTheoMa(const QString& maHV);

    AppServices m_services;
    QList<ChiNhanh> m_chiNhanh;
    bool m_duocSua = false;
    QLineEdit* m_tuKhoa = nullptr;
    QComboBox* m_locChiNhanh = nullptr;
    QComboBox* m_locTrangThai = nullptr;
    QPushButton* m_nutSua = nullptr;
    QPushButton* m_nutXoa = nullptr;
    QTableView* m_bang = nullptr;
    HocVienTableModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QLabel* m_dem = nullptr;
    QTimer* m_hoan = nullptr;
};
