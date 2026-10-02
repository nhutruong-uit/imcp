#pragma once

#include "infrastructure/db/SqlErrorMapper.h"

#include <QDate>
#include <QMetaType>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QVariant>

namespace SqlHelpers {

// Empty string => NULL of type NVARCHAR (ODBC needs to know the type of a NULL parameter)
inline QVariant stringOrNull(const QString& s) {
    return s.trimmed().isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(s);
}

inline QVariant dateOrNull(const QDate& d) {
    return d.isValid() ? QVariant(d) : QVariant(QMetaType::fromType<QDate>());
}

// Pre-configured query: decimals returned as double, forward-only reading
inline QSqlQuery makeQuery(const QSqlDatabase& db) {
    QSqlQuery q(db);
    q.setForwardOnly(true);
    q.setNumericalPrecisionPolicy(QSql::LowPrecisionDouble);
    return q;
}

inline QString errorOf(const QSqlQuery& q) {
    return SqlErrorMapper::message(q.lastError());
}

} // namespace SqlHelpers
