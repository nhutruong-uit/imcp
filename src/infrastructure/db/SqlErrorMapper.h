#pragma once

#include <QCoreApplication>
#include <QSqlError>
#include <QString>

// Turns ODBC/SQL Server errors into user-friendly messages (in the UI language).
// - Business errors raised by THROW/RAISERROR in procedures/triggers: written in English by the database,
//   translated through the DbMessages catalog
// - System errors (wrong password, lost connection, missing permission, constraint violation): translated
// Every repository turns a failed query into Result::failure(SqlHelpers::errorOf(q)), which calls message(),
// so the user never sees raw driver text such as "[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]...".
class SqlErrorMapper {
    Q_DECLARE_TR_FUNCTIONS(SqlErrorMapper)
public:
    static QString message(const QSqlError& error);
    static QString cleanMessage(const QString& rawMessage); // strips [Microsoft][ODBC ...] prefixes
    // Message for a violated constraint/unique index by its name (CK_..., UQ_..., UX_..., FK_...)
    static QString constraintMessage(const QString& constraintName);
};
