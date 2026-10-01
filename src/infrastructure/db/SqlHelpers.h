#pragma once

#include "infrastructure/db/SqlErrorMapper.h"

#include <QDate>
#include <QMetaType>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QVariant>

namespace SqlHelpers {

// Chuỗi rỗng => NULL kiểu NVARCHAR (ODBC cần biết kiểu dữ liệu của NULL)
inline QVariant chuoiHoacNull(const QString& s) {
    return s.trimmed().isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(s);
}

inline QVariant ngayHoacNull(const QDate& d) {
    return d.isValid() ? QVariant(d) : QVariant(QMetaType::fromType<QDate>());
}

// Tạo câu lệnh đã cấu hình sẵn: số thập phân trả về dạng double, chỉ đọc tiến
inline QSqlQuery taoCauLenh(const QSqlDatabase& db) {
    QSqlQuery q(db);
    q.setForwardOnly(true);
    q.setNumericalPrecisionPolicy(QSql::LowPrecisionDouble);
    return q;
}

inline QString loiCua(const QSqlQuery& q) {
    return SqlErrorMapper::thongBao(q.lastError());
}

} // namespace SqlHelpers
