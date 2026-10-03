#pragma once

#include "application/ports/IAuthGateway.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// Login = open a SQL Server connection with the user's account (contained database user),
// then read the role through dbo.usp_Account_RecordLogin.
// Implements the port IAuthGateway; the connection itself belongs to DatabaseManager (shared by every
// repository, which is why m_db is a reference).
class SqlAuthGateway : public IAuthGateway {
    Q_DECLARE_TR_FUNCTIONS(SqlAuthGateway)
public:
    explicit SqlAuthGateway(DatabaseManager& db);
    Result<Account> login(const ServerConfig& config, const QString& username,
                          const QString& password) override;
    void logout() override;
    VoidResult changePassword(const QString& oldPassword, const QString& newPassword) override;

private:
    DatabaseManager& m_db;
};
