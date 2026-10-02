#include "domain/entities/Role.h"

Role roleFromCode(const QString& code) {
    const QString c = code.trimmed().toUpper();
    if (c == QLatin1String("MANAGER"))
        return Role::Manager;
    if (c == QLatin1String("ACADEMIC_STAFF"))
        return Role::AcademicStaff;
    if (c == QLatin1String("ACCOUNTANT"))
        return Role::Accountant;
    if (c == QLatin1String("TEACHER"))
        return Role::Teacher;
    return Role::Unknown;
}

QString roleCode(Role role) {
    switch (role) {
    case Role::Manager:
        return QStringLiteral("MANAGER");
    case Role::AcademicStaff:
        return QStringLiteral("ACADEMIC_STAFF");
    case Role::Accountant:
        return QStringLiteral("ACCOUNTANT");
    case Role::Teacher:
        return QStringLiteral("TEACHER");
    case Role::Unknown:
        break;
    }
    return QString();
}
