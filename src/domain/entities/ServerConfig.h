#pragma once

#include <QString>

// The SQL Server instance the application connects to. Edited under "Server settings" on the login screen,
// saved on the user's machine by QSettingsStore and turned into an ODBC connection string by DatabaseManager.
struct ServerConfig {
    QString host = QStringLiteral("localhost,1433"); // host,port or host\instance
    QString database = QStringLiteral("QLTTTA");
    bool trustServerCertificate = true; // TrustServerCertificate (self-signed server certificate)
};
