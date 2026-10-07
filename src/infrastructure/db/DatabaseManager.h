#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ServerConfig.h"

#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlError>
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
    // at once (see the .cpp). With "Trust server certificate" off only the drivers that can check the
    // certificate are tried (canVerifyCertificate): the option is never ignored silently.
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
    // True when the driver checks the server's certificate if "Trust server certificate" is off: the
    // Microsoft ODBC drivers 17/18 do. FreeTDS (it accepts a self-signed certificate even with a CA file
    // configured) and the legacy Windows "SQL Server" driver (no TLS keywords at all) do not, so open() never
    // uses them when the option is off.
    static bool canVerifyCertificate(const QString& driver);
    // The drivers open() may use: all the candidates when the certificate is trusted, otherwise only those
    // that can check it (so the option is never ignored silently)
    static QStringList driversToTry(const QStringList& candidates, bool trustServerCertificate);
    // Message of a failed connection through driver: SqlErrorMapper's text, plus "install ODBC Driver 18"
    // when the legacy Windows driver could not connect (it cannot sign in to SQL Server 2025 on Windows 11)
    static QString connectionFailure(const QSqlError& error, const QString& driver);

    // Installer check (QLTTTA --self-test, run by the packaging scripts and release.yml): the Qt ODBC plugin
    // is deployed, and the first candidate driver the ODBC driver manager can load - the one open() starts
    // with. A driver is probed by connecting to a closed port of this computer, so no server is needed:
    // "driver not found" = missing, any other error = the driver loaded and tried to connect. Empty = none
    // installed.
    static bool odbcPluginAvailable();
    static QString firstInstalledDriver();

private:
    QString m_driver;
};
