#pragma once

#include "application/ports/IAccountRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IAccountRepository with SQL Server (manager only): usp_Account_List / _Create / _Lock / _ResetPassword (the
// last three run WITH EXECUTE AS OWNER), and the employees / teachers without an account (the manager reads
// every table through db_datareader).
class SqlAccountRepository : public IAccountRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlAccountRepository)
public:
    explicit SqlAccountRepository(DatabaseManager& db);
    Result<TableData> list() override;
    VoidResult create(const NewAccount& account) override;
    VoidResult setLocked(const QString& username, bool locked) override;
    VoidResult resetPassword(const QString& username, const QString& newPassword) override;
    Result<QList<LookupItem>> peopleWithoutAccount(Role role) override;

private:
    DatabaseManager& m_db;
};
