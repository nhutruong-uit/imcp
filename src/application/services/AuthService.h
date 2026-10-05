#pragma once

#include "application/ports/IAuthGateway.h"
#include "application/ports/ISettingsStore.h"

#include <QCoreApplication>
#include <optional>

// Use case: log in / log out / change password; keeps the current session.
// Used by LoginDialog, MainWindow (role, name, log out), ChangePasswordDialog and main.cpp
// (--check-connection). The members are references (&) to objects created once by AppContainer: the service
// does not own them and does not know whether they talk to SQL Server or are fakes (tests).
class AuthService {
    Q_DECLARE_TR_FUNCTIONS(AuthService)
public:
    AuthService(IAuthGateway& gateway, ISettingsStore& settings);

    ServerConfig serverConfig() const;
    void saveServerConfig(const ServerConfig& config);
    QString lastUsername() const;

    Result<Account> login(const QString& username, const QString& password);
    void logout();
    VoidResult changePassword(const QString& oldPassword, const QString& newPassword,
                              const QString& confirmation);

    bool isLoggedIn() const { return m_account.has_value(); }
    const Account& account() const { return *m_account; } // only valid while isLoggedIn()
    Role role() const { return m_account ? m_account->role : Role::Unknown; }

private:
    IAuthGateway& m_gateway;
    ISettingsStore& m_settings;
    std::optional<Account> m_account; // empty = nobody is logged in
};
