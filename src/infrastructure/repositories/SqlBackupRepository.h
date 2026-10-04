#pragma once

#include "application/ports/IBackupRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IBackupRepository with SQL Server: usp_Backup (WITH EXECUTE AS OWNER, so the manager needs no BACKUP
// DATABASE permission). SQL Server writes the file on its own machine (in Docker: inside the container).
class SqlBackupRepository : public IBackupRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlBackupRepository)
public:
    explicit SqlBackupRepository(DatabaseManager& db);
    Result<QString> backup(const QString& type, const QString& folder) override;

private:
    DatabaseManager& m_db;
};
