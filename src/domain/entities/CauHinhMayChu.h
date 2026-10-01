#pragma once

#include <QString>

// Thông tin máy chủ SQL Server mà ứng dụng kết nối tới
struct CauHinhMayChu {
    QString mayChu = QStringLiteral("localhost,1433");   // host,port hoặc host\instance
    QString csdl = QStringLiteral("QLTTTA");
    bool tinCayChungChi = true;                          // TrustServerCertificate (máy chủ dùng chứng chỉ tự ký)
};
