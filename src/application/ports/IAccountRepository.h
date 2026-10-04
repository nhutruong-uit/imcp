#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/NewAccount.h"

#include <QList>

// Port of the Accounts screen (manager only): implemented by SqlAccountRepository (usp_Account_List, _Create,
// _Lock, _ResetPassword), used by AccountService.
class IAccountRepository {
public:
    virtual ~IAccountRepository() = default;
    virtual Result<TableData> list() = 0;
    virtual VoidResult create(const NewAccount& account) = 0;
    virtual VoidResult setLocked(const QString& username, bool locked) = 0;
    virtual VoidResult resetPassword(const QString& username, const QString& newPassword) = 0;
    // People who may get an account of that role and have none yet (employees, or teachers for TEACHER)
    virtual Result<QList<LookupItem>> peopleWithoutAccount(Role role) = 0;
};
