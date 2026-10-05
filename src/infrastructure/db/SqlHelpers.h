#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/db/SqlErrorMapper.h"

#include <QDate>
#include <QMetaType>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QVariant>

// Small tools shared by every Sql*Repository. The rule they enforce: a value never becomes part of the SQL
// text; it is sent separately as a parameter for a '?' marker, so input such as "x'; DROP TABLE ..."
// stays plain data (no SQL injection) and Vietnamese text keeps its accents.
namespace SqlHelpers {

// Empty string => NULL of type NVARCHAR (ODBC needs to know the type of a NULL parameter)
inline QVariant stringOrNull(const QString& s) {
    return s.trimmed().isEmpty() ? QVariant(QMetaType::fromType<QString>()) : QVariant(s);
}

// Invalid (empty) date => NULL of type DATE
inline QVariant dateOrNull(const QDate& d) {
    return d.isValid() ? QVariant(d) : QVariant(QMetaType::fromType<QDate>());
}

// Optional numbers: no value => NULL of the parameter type
inline QVariant intOrNull(int value, bool present) {
    return present ? QVariant(value) : QVariant(QMetaType::fromType<int>());
}
inline QVariant doubleOrNull(double value, bool present) {
    return present ? QVariant(value) : QVariant(QMetaType::fromType<double>());
}

// Pre-configured query: decimals returned as double, forward-only reading
// (forward-only = rows are read once from first to last, which is faster and is all the lists need; money
// columns are DECIMAL in the database and would otherwise arrive as text)
inline QSqlQuery makeQuery(const QSqlDatabase& db) {
    QSqlQuery q(db);
    q.setForwardOnly(true);
    q.setNumericalPrecisionPolicy(QSql::LowPrecisionDouble);
    return q;
}

// The user-facing message of the last error of q (see SqlErrorMapper::message)
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

/// The value of a column of the current row, found by its NAME (the column name or AS alias of the SQL),
/// never by
// its position: a procedure that gets a new column or another column order cannot shift the values. An
// unknown name is a programming error - it stops a Debug build (the tests) and gives an empty value in a
// Release build.
QVariant field(const QSqlQuery& q, const char* column);

// The rows of the current result of q as TableData: the column names (or AS aliases) become the column keys,
// so the SQL holds no display text (the presentation layer finds the titles in its column catalog, Columns)
TableData readTable(QSqlQuery& q);

// Shortcuts for the three shapes of call the repositories make (each one goes through execPrepared):
// a call without result (most write procedures), a list for a table, and a list of choices for a combo box
// (column 0 = the key, column 1 = the text shown, an optional column 2 = a stored value for
// LookupItem::detail)
VoidResult execCall(const DatabaseManager& db, const QString& sql, const QVariantList& values);
Result<TableData> queryTable(const DatabaseManager& db, const QString& sql, const QVariantList& values);
Result<QList<LookupItem>> queryLookup(const DatabaseManager& db, const QString& sql,
                                      const QVariantList& values);

} // namespace SqlHelpers
