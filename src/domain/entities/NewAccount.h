#pragma once

#include "domain/entities/Role.h"

#include <QCoreApplication>
#include <QString>
#include <QStringList>

// A sign-in account to create with usp_Account_Create: a contained database user with a password plus its
// ACCOUNT row. personId is an EmployeeId for the office roles and a TeacherId for the role TEACHER
// (CK_ACCOUNT_Owner). The password never leaves this struct except as a procedure parameter.
struct NewAccount {
    QString username;
    QString password;
    QString confirmation;
    Role role = Role::Unknown;
    QString personId;

    // The checks of usp_Account_Create (50060, 50061) plus the confirmation, before the database is asked
    QStringList validate() const;
    static bool isValidUsername(const QString& username);

    Q_DECLARE_TR_FUNCTIONS(NewAccount)
};

// Password rule shared by account creation and password reset (usp_Account_* refuse a shorter one, 50061)
namespace AccountLimits {
inline constexpr int minPasswordLength = 8;
inline constexpr int maxUsernameLength = 50;
} // namespace AccountLimits
