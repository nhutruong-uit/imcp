#pragma once

#include "application/ports/IAuthGateway.h"
#include "application/ports/ISettingsStore.h"

#include <QCoreApplication>
#include <optional>

// Use case: log in / log out / change password; keeps the current session
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
    const Account& account() const { return *m_account; }
    Role role() const { return m_account ? m_account->role : Role::Unknown; }

private:
    IAuthGateway& m_gateway;
    ISettingsStore& m_settings;
    std::optional<Account> m_account;
};
