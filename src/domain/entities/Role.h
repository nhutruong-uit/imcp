#pragma once

#include <QString>

// User role - matches the database roles in SQL Server (rl_Manager, rl_AcademicStaff, ...).
// The display name of a role (in the UI language) lives in the presentation layer: Labels::role.
enum class Role { Manager, AcademicStaff, Accountant, Teacher, Unknown };

// "MANAGER" -> Role::Manager (code stored in column ACCOUNT.Role)
Role roleFromCode(const QString& code);
QString roleCode(Role role);
