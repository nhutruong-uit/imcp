#pragma once

#include <QDialog>

class AuthService;
class QLabel;
class QLineEdit;

// "Change password" dialog of the main window header. The checks and the change itself are done by
// AuthService::changePassword (-> usp_Account_ChangePassword); errors are shown inside the dialog.
// "class AuthService;" above is a forward declaration: it is enough for a reference member.
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
