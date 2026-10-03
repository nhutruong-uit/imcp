#pragma once

#include <QString>

// User role - matches the database roles in SQL Server (rl_Manager, rl_AcademicStaff, ...).
// The display name of a role (in the UI language) lives in the presentation layer: Labels::role.
// The role decides which menu entries the application SHOWS (Permissions); what the user may really read or
// change is decided by SQL Server through the GRANT/DENY of the matching database role (06_security.sql).
enum class Role { Manager, AcademicStaff, Accountant, Teacher, Unknown };

// "MANAGER" -> Role::Manager (code stored in column ACCOUNT.Role); an unknown code -> Role::Unknown
Role roleFromCode(const QString& code);
QString roleCode(Role role); // the reverse: Role::Manager -> "MANAGER"; Role::Unknown -> empty text
