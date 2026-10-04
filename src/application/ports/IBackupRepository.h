#pragma once

#include "domain/common/Result.h"

// Port of the Backup screen (manager only): implemented by SqlBackupRepository (usp_Backup), used by
// BackupService. The file is written by SQL Server on the server machine, not on the user's computer.
class IBackupRepository {
public:
    virtual ~IBackupRepository() = default;
    // type = FULL, DIFF or LOG; folder empty = the default backup folder of the server; returns the file path
    virtual Result<QString> backup(const QString& type, const QString& folder) = 0;
};
