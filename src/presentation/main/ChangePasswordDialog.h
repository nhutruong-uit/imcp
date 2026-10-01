#pragma once

#include <QDialog>

class AuthService;
class QLabel;
class QLineEdit;

class ChangePasswordDialog : public QDialog {
    Q_OBJECT
public:
    explicit ChangePasswordDialog(AuthService& auth, QWidget* parent = nullptr);

private slots:
    void luu();

private:
    AuthService& m_auth;
    QLineEdit* m_cu = nullptr;
    QLineEdit* m_moi = nullptr;
    QLineEdit* m_nhapLai = nullptr;
    QLabel* m_loi = nullptr;
};
