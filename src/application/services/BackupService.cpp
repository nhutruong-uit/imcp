#include "application/services/BackupService.h"

BackupService::BackupService(IBackupRepository& repository) : m_repository(repository) {}

QStringList BackupService::types() {
    return {QStringLiteral("FULL"), QStringLiteral("DIFF"), QStringLiteral("LOG")};
}

Result<QString> BackupService::backup(const QString& type, const QString& folder) {
    if (!types().contains(type))
        return Result<QString>::failure(tr("The backup type must be FULL, DIFF or LOG."));
    return m_repository.backup(type, folder.trimmed());
}
