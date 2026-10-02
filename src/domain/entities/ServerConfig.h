#pragma once

#include <QString>

// The SQL Server instance the application connects to
struct ServerConfig {
    QString host = QStringLiteral("localhost,1433"); // host,port or host\instance
    QString database = QStringLiteral("QLTTTA");
    bool trustServerCertificate = true; // TrustServerCertificate (self-signed server certificate)
};
