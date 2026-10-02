#pragma once

#include <QCoreApplication>
#include <QSqlError>
#include <QString>

// Turns ODBC/SQL Server errors into user-friendly messages (in the UI language).
// - Business errors raised by THROW/RAISERROR in procedures/triggers: written in English by the database,
//   translated through the DbMessages catalog
// - System errors (wrong password, lost connection, missing permission, constraint violation): translated
class SqlErrorMapper {
    Q_DECLARE_TR_FUNCTIONS(SqlErrorMapper)
public:
    static QString message(const QSqlError& error);
    static QString cleanMessage(const QString& rawMessage); // strips [Microsoft][ODBC ...] prefixes
    static QString constraintMessage(const QString& constraintName);
};
