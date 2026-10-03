#pragma once

#include "application/ports/IBackupRepository.h"

#include <QCoreApplication>
#include <QStringList>

// Backup use case (manager only): run a FULL, DIFF(erential) or LOG backup with usp_Backup. Used by
// BackupPage.
class BackupService {
    Q_DECLARE_TR_FUNCTIONS(BackupService)
public:
    explicit BackupService(IBackupRepository& repository);

    static QStringList types(); // FULL, DIFF, LOG - the values usp_Backup accepts (50070 otherwise)
    Result<QString> backup(const QString& type, const QString& folder); // the file written on the server

private:
    IBackupRepository& m_repository;
};
