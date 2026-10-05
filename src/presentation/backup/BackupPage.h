#pragma once

#include "presentation/main/AppServices.h"

#include <QWidget>

class QComboBox;
class QLabel;
class QLineEdit;
class QListWidget;

// Backup page (manager only): run a FULL, DIFF(erential) or LOG backup of the database with usp_Backup (WITH
// EXECUTE AS OWNER, so the manager needs no BACKUP DATABASE permission). SQL Server writes the file on its
// own machine; the page lists the files made in this session. Restoring stays a task for SSMS
// (09_backup_restore.sql).
class BackupPage : public QWidget {
    Q_OBJECT
public:
    explicit BackupPage(AppServices services, QWidget* parent = nullptr);

private:
    void runBackup();

    AppServices m_services;
    QComboBox* m_type = nullptr;
    QLineEdit* m_folder = nullptr;
    QLabel* m_result = nullptr;
    QListWidget* m_history = nullptr;
};
