#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Account.h"
#include "domain/entities/ServerConfig.h"

// Authentication gateway: implemented in the infrastructure layer by opening a SQL Server connection with the
// user's own username/password (the DBMS performs the authentication).
// Port (interface, see IStudentRepository.h): implemented by SqlAuthGateway, faked in tst_application.cpp,
// used only by AuthService. The application never stores or checks passwords itself.
class IAuthGateway {
public:
    virtual ~IAuthGateway() = default;
    // Connects as this user and returns their account row; a failure means SQL Server refused the login or
    // could not be reached. The connection stays open for the session when it succeeds.
    virtual Result<Account> login(const ServerConfig& config, const QString& username,
                                  const QString& password) = 0;
    virtual void logout() = 0; // closes the connection
    // Changes the password of the logged-in user (usp_Account_ChangePassword checks the old one)
    virtual VoidResult changePassword(const QString& oldPassword, const QString& newPassword) = 0;
};
