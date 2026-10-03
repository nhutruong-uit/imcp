#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ServerConfig.h"

#include <QCoreApplication>
#include <QSqlDatabase>
#include <QStringList>

// Manages the ODBC connection to SQL Server.
// Tries every ODBC driver that may exist on the machine (Driver 18 -> 17 -> the legacy "SQL Server" driver of
// Windows), so the application also runs on machines without a recent driver.
// There is ONE connection per session, opened at login with the user's own SQL Server account: every query of
// every Sql*Repository then runs with that user's permissions (the database, not the application, decides
// what they may read or change). ODBC = the standard driver interface the OS uses to reach a database.
// Order of the drivers per OS and the FreeTDS Unicode workaround: docs/ARCHITECTURE.md section 6.
class DatabaseManager {
    Q_DECLARE_TR_FUNCTIONS(DatabaseManager)
public:
    DatabaseManager() = default;
    ~DatabaseManager(); // closes the connection when the application ends
    // "= delete": copying is forbidden - there is exactly one connection manager (owned by AppContainer)
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    // Connects with the first driver that works; a wrong password, a rejected certificate or a timeout stops
    // at once (see the .cpp)
    VoidResult open(const ServerConfig& config, const QString& username, const QString& password);
    void close();
    QSqlDatabase db() const; // the open connection, passed to SqlHelpers::makeQuery by the repositories
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
