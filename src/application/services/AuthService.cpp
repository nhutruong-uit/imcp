#include "application/services/AuthService.h"

AuthService::AuthService(IAuthGateway& gateway, ISettingsStore& settings)
    : m_gateway(gateway), m_settings(settings) {}

ServerConfig AuthService::serverConfig() const {
    return m_settings.serverConfig();
}

void AuthService::saveServerConfig(const ServerConfig& config) {
    m_settings.saveServerConfig(config);
}

QString AuthService::lastUsername() const {
    return m_settings.lastUsername();
}

Result<Account> AuthService::login(const QString& username, const QString& password) {
    const QString name = username.trimmed();
    if (name.isEmpty() || password.isEmpty())
        return Result<Account>::failure(tr("Please enter your username and password."));

    const ServerConfig config = m_settings.serverConfig();
    if (config.host.trimmed().isEmpty() || config.database.trimmed().isEmpty())
        return Result<Account>::failure(tr("The database server is not configured."));

    auto result = m_gateway.login(config, name, password);
    if (!result.ok())
        return result;

    // SQL Server accepted the password; the application still refuses locked accounts and accounts without a
    // role
    if (!result.value().active) {
        m_gateway.logout();
        return Result<Account>::failure(tr("The account is locked."));
    }
    if (result.value().role == Role::Unknown) {
        m_gateway.logout();
        return Result<Account>::failure(
            tr("Valid SQL Server account, but no role is assigned to it in the system."));
    }

    m_settings.saveLastUsername(name);
    m_account = result.value();
    return result;
}

void AuthService::logout() {
    m_gateway.logout();
    m_account.reset();
}

VoidResult AuthService::changePassword(const QString& oldPassword, const QString& newPassword,
                                       const QString& confirmation) {
    if (!isLoggedIn())
        return VoidResult::failure(tr("You are not logged in."));
    if (newPassword.size() < 8)
        return VoidResult::failure(tr("The new password must be at least 8 characters long."));
    if (newPassword != confirmation)
        return VoidResult::failure(tr("The password confirmation does not match."));
    if (newPassword == oldPassword)
        return VoidResult::failure(tr("The new password must differ from the old one."));
    return m_gateway.changePassword(oldPassword, newPassword);
}
