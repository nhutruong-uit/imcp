#pragma once

#include "domain/common/Result.h"
#include "domain/entities/CauHinhMayChu.h"

#include <QSqlDatabase>
#include <QStringList>

// Quản lý kết nối ODBC tới SQL Server.
// Tự thử lần lượt các ODBC driver có thể có trên máy (Driver 18 -> 17 -> driver "SQL Server" có sẵn
// của Windows), nên ứng dụng chạy được cả trên máy chưa cài driver mới.
class DatabaseManager {
public:
    DatabaseManager() = default;
    ~DatabaseManager();
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    VoidResult moKetNoi(const CauHinhMayChu& cauHinh, const QString& tenDangNhap, const QString& matKhau);
    void dongKetNoi();
    bool daKetNoi() const;
    QSqlDatabase db() const;
    QString driverDangDung() const { return m_driver; }

    // Dùng cho kiểm thử/chẩn đoán: chuỗi kết nối với mật khẩu đã được che
    static QString chuoiKetNoi(const QString& driver, const CauHinhMayChu& cauHinh, const QString& tenDangNhap,
                               const QString& matKhau);
    static QStringList danhSachDriver();

private:
    QString m_driver;
};
