#pragma once

#include "domain/entities/Role.h"

#include <QString>

// The logged-in user (read from view dbo.vw_CurrentAccount after SQL Server has authenticated them)
struct Account {
    QString username;
    Role role = Role::Unknown;
    QString fullName;
    QString employeeId; // office staff
    QString teacherId;  // teachers
    QString branchId;
    bool active = true; // false = the account is locked (ACCOUNT.Status)
};
