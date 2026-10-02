#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Account.h"
#include "domain/entities/ServerConfig.h"

// Authentication gateway: implemented in the infrastructure layer by opening a SQL Server connection with the
// user's own username/password (the DBMS performs the authentication).
class IAuthGateway {
public:
    virtual ~IAuthGateway() = default;
    virtual Result<Account> login(const ServerConfig& config, const QString& username,
                                  const QString& password) = 0;
    virtual void logout() = 0;
    virtual VoidResult changePassword(const QString& oldPassword, const QString& newPassword) = 0;
};
