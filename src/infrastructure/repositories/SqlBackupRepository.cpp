#include "infrastructure/repositories/SqlBackupRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlBackupRepository::SqlBackupRepository(DatabaseManager& db) : m_db(db) {}

Result<QString> SqlBackupRepository::backup(const QString& type, const QString& folder) {
    // The procedure returns the file path through @FilePath and as a one-row result (BackupFile), read here
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql =
        QStringLiteral("SET NOCOUNT ON; DECLARE @Path NVARCHAR(400); "
                       "EXEC dbo.usp_Backup @Type = ?, @Folder = ?, @FilePath = @Path OUTPUT;");
    if (!execPrepared(q, m_db, sql, {type, stringOrNull(folder)}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The backup file name was not returned."));
    return Result<QString>::success(q.value(0).toString());
}
