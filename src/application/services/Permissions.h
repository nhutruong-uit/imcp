#pragma once

#include "domain/entities/Role.h"

#include <QList>

// Application features (menu entries). The display name, icon and menu group of each feature
// (in the UI language) are decided by the presentation layer: Labels::feature.
enum class Feature {
    Dashboard,
    Students,
    Classes,
    WeeklySchedule,
    LearningResults,
    OutstandingTuition,
    Revenue,
    Payroll,
    Accounts,
    MyClasses,
    MyTeachingSchedule,
    MyPay
};

// Application-side permission matrix: decides which menu entries are SHOWN.
// Real access control is still enforced by SQL Server through GRANT/DENY on the roles (06_security.sql);
// if the application shows something by mistake, the database still refuses the access.
class Permissions {
public:
    static QList<Feature> allowedFeatures(Role role);
    static bool isAllowed(Role role, Feature feature);
    static bool canEditStudents(Role role);
};
