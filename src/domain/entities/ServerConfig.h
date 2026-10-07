#pragma once

#include <QString>

// The SQL Server instance the application connects to. Edited under "Server settings" on the login screen,
// saved on the user's machine by QSettingsStore and turned into an ODBC connection string by DatabaseManager.
struct ServerConfig {
    QString host = QStringLiteral("localhost,1433"); // host,port or host\instance
    QString database = QStringLiteral("QLTTTA");
    // TrustServerCertificate: accept the server's certificate without checking it. The default `true` belongs
    // to the default host (localhost); for another host the default is isLocalHost(host), see QSettingsStore
    bool trustServerCertificate = true;

    // True when `host` names this computer: "localhost", "127.0.0.1", "::1", "." or "(local)", with an
    // optional "tcp:" prefix, ",port" or "\instance". A local SQL Server or Docker container presents a
    // self-signed certificate, so trusting it is normal there; on any other host the certificate should be
    // checked.
    static bool isLocalHost(const QString& host);
};
