#pragma once

#include "domain/entities/Role.h"

#include <QString>

// The logged-in user (read from view dbo.vw_CurrentAccount after SQL Server has authenticated them).
// Built by SqlAuthGateway::login and kept by AuthService for the whole session; the main window reads the
// role to build the menu (Permissions) and the full name for the header and the PDF reports.
struct Account {
    QString username;
    // Unknown = no valid role code in ACCOUNT.Role => AuthService refuses the login
    Role role = Role::Unknown;
    QString fullName;
    QString employeeId; // office staff
    QString teacherId;  // teachers
    QString branchId;
    bool active = true; // false = the account is locked (ACCOUNT.Status)
    // A database owner (sa / db_owner) without an ACCOUNT row, let in as Manager; fullName is then the login
    // name, and the UI adds "(database administrator)" in its own language (Labels::accountName)
    bool databaseOwner = false;
};
