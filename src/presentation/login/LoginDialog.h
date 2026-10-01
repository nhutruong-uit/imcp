#pragma once

#include <QDialog>

class AuthService;
class QCheckBox;
class QGroupBox;
class QLabel;
class QLineEdit;
class QPushButton;

// Màn hình đăng nhập: xác thực bằng tài khoản SQL Server (contained user) + cấu hình máy chủ
class LoginDialog : public QDialog {
    Q_OBJECT
public:
    explicit LoginDialog(AuthService& auth, QWidget* parent = nullptr);

private slots:
    void dangNhap();
    void anHienCauHinh();

private:
    QWidget* taoPanelThuongHieu();
    QWidget* taoPanelForm();

    AuthService& m_auth;
    QLineEdit* m_tenDangNhap = nullptr;
    QLineEdit* m_matKhau = nullptr;
    QLineEdit* m_mayChu = nullptr;
    QLineEdit* m_csdl = nullptr;
    QCheckBox* m_tinCay = nullptr;
    QGroupBox* m_nhomCauHinh = nullptr;
    QPushButton* m_nutCauHinh = nullptr;
    QPushButton* m_nutDangNhap = nullptr;
    QLabel* m_loi = nullptr;
};
