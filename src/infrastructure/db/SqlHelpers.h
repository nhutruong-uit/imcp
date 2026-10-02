#pragma once

#include "infrastructure/db/DatabaseManager.h"
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

// SQL text with '?' markers and the values for them, in order
struct BoundStatement {
    QString sql;
    QVariantList values;
};

// FreeTDS workaround: Qt's ODBC plugin turns Unicode off for FreeTDS, so a QString parameter reaches SQL
// Server as VARCHAR and is converted through the database code page (Vietnamese_CI_AS = 1258): accents get
// decomposed and other characters become '?'. Every text value with a non-ASCII character is therefore sent
// as its UTF-16LE bytes and turned back into NVARCHAR on the server, in a variable that replaces its marker:
//   DECLARE @UnicodeText1 NVARCHAR(MAX) = CAST(CAST(? AS VARBINARY(MAX)) AS NVARCHAR(MAX));
//   EXEC dbo.usp_X @A = @UnicodeText1
// The value is still a parameter (never pasted into the SQL text). Other values and NULLs are left unchanged;
// markers inside string literals, quoted identifiers and comments are ignored.
BoundStatement withUnicodeText(const QString& sql, const QVariantList& values);

// Prepares sql, binds values and executes it (through withUnicodeText when the connection uses FreeTDS)
bool execPrepared(QSqlQuery& q, const DatabaseManager& db, const QString& sql, const QVariantList& values);

} // namespace SqlHelpers
