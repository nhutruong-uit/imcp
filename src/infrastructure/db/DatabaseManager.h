#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ServerConfig.h"

#include <QCoreApplication>
#include <QSqlDatabase>
#include <QStringList>

// Manages the ODBC connection to SQL Server.
// Tries every ODBC driver that may exist on the machine (Driver 18 -> 17 -> the legacy "SQL Server" driver of
// Windows), so the application also runs on machines without a recent driver.
class DatabaseManager {
    Q_DECLARE_TR_FUNCTIONS(DatabaseManager)
public:
    DatabaseManager() = default;
    ~DatabaseManager();
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    VoidResult open(const ServerConfig& config, const QString& username, const QString& password);
    void close();
    bool isOpen() const;
    QSqlDatabase db() const;
    QString activeDriver() const { return m_driver; }
    // FreeTDS: Qt's ODBC plugin turns Unicode off for this driver, see SqlHelpers::execPrepared
    bool usesFreeTds() const { return isFreeTds(m_driver); }

    // Exposed for tests and diagnostics
    static QString connectionString(const QString& driver, const ServerConfig& config,
                                    const QString& username, const QString& password);
    static QStringList candidateDrivers();
    static bool isFreeTds(const QString& driver);

private:
    QString m_driver;
};
