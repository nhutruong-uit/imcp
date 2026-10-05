#pragma once

#include "application/ports/IAccountRepository.h"

#include <QCoreApplication>

// Account administration use case (manager only): create sign-in accounts, lock / unlock them, reset a
// password. The database does the security work (contained users, DENY / GRANT CONNECT, EXECUTE AS OWNER);
// the service checks the input first so a typing mistake never reaches SQL Server. Used by AccountPage.
class AccountService {
    Q_DECLARE_TR_FUNCTIONS(AccountService)
public:
    explicit AccountService(IAccountRepository& repository);

    Result<TableData> list();
    VoidResult create(const NewAccount& account);
    VoidResult lock(const QString& username);
    VoidResult unlock(const QString& username);
    VoidResult resetPassword(const QString& username, const QString& newPassword,
                             const QString& confirmation);
    Result<QList<LookupItem>> peopleWithoutAccount(Role role);

private:
    IAccountRepository& m_repository;
};
