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
    void save();

private:
    AuthService& m_auth;
    QLineEdit* m_current = nullptr;
    QLineEdit* m_new = nullptr;
    QLineEdit* m_confirmation = nullptr;
    QLabel* m_error = nullptr;
};
