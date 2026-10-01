#pragma once

#include "application/services/PhanQuyen.h"
#include "presentation/main/AppServices.h"

#include <QHash>
#include <QMainWindow>

class QLabel;
class QListWidget;
class QStackedWidget;

// Cửa sổ chính: menu bên trái sinh theo vai trò (PhanQuyen), nội dung bên phải là các trang
class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(AppServices services, QWidget* parent = nullptr);

    const QList<ChucNang>& danhSachChucNang() const { return m_chucNang; }
    void moChucNang(ChucNang chucNang);   // dùng cho công cụ chụp màn hình/kiểm thử giao diện

signals:
    void yeuCauDangXuat();

private slots:
    void chonChucNang(int dong);
    void doiMatKhau();

private:
    QWidget* taoSidebar();
    QWidget* taoHeader();
    QWidget* trangCho(ChucNang chucNang);

    AppServices m_services;
    QList<ChucNang> m_chucNang;
    QHash<int, QWidget*> m_trang;   // key = (int)ChucNang, trang tạo khi mở lần đầu
    QListWidget* m_menu = nullptr;
    QStackedWidget* m_noiDung = nullptr;
    QLabel* m_tieuDe = nullptr;
};
