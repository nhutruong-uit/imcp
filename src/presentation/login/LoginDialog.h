#pragma once

#include <QDialog>

class AuthService;
class LanguageService;
class QCheckBox;
class QComboBox;
class QGroupBox;
class QLabel;
class QLineEdit;
class QPushButton;

// Login screen: authenticates with a SQL Server account (contained user) + server settings + language
// Shown by main.cpp with exec(): a modal dialog that blocks until it closes and returns how it closed
// (Accepted = logged in, Rejected = window closed, LanguageChanged = rebuild it in the new language).
class LoginDialog : public QDialog {
    Q_OBJECT
public:
    // exec() result when the user switched language: the caller rebuilds the dialog in the new language
    enum Outcome { LanguageChanged = 2 };

    LoginDialog(AuthService& auth, LanguageService& language, QWidget* parent = nullptr);

private slots:
    void login();
    void toggleServerSettings();
    void changeLanguage();

private:
    QWidget* buildBrandPanel();
    QWidget* buildFormPanel();

    AuthService& m_auth;
    LanguageService& m_language;
    QLineEdit* m_username = nullptr;
    QLineEdit* m_password = nullptr;
    QLineEdit* m_server = nullptr;
    QLineEdit* m_database = nullptr;
    QCheckBox* m_trustCertificate = nullptr;
    QGroupBox* m_serverGroup = nullptr;
    QPushButton* m_serverToggle = nullptr;
    QPushButton* m_loginButton = nullptr;
    QComboBox* m_languageCombo = nullptr;
    QLabel* m_error = nullptr;
};
