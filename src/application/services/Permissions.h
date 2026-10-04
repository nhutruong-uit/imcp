#pragma once

#include "domain/entities/Role.h"

#include <QList>

// Application features (menu entries). The display name, icon and menu group of each feature
// (in the UI language) are decided by the presentation layer: Labels::feature.
// Keep MyPay the last value: tests walk the features from Dashboard to MyPay.
enum class Feature {
    Dashboard,
    Students,
    PlacementTests,
    Classes,
    Enrollments,
    WeeklySchedule,
    Grades,
    LearningResults,
    Tuition,
    OutstandingTuition,
    Revenue,
    Payroll,
    Courses,
    Teachers,
    Employees,
    Branches,
    Promotions,
    Accounts,
    Backup,
    MyClasses,
    MyTeachingSchedule,
    MyGrades,
    MyPay
};

// Application-side permission matrix: decides which menu entries and which buttons are SHOWN.
// Real access control is still enforced by SQL Server through GRANT/DENY on the roles (06_security.sql);
// if the application shows something by mistake, the database still refuses the access.
// Keep both in line: the end-to-end test everyRole_opensEveryFeature_withData signs in with every role and
// opens every feature listed here, so a feature whose view/procedure is not granted to the role fails it.
class Permissions {
public:
    static QList<Feature> allowedFeatures(Role role); // in menu order
    static bool isAllowed(Role role, Feature feature);
    // May the role change data on the page of this feature (Add/Edit/Save... buttons)? The procedures behind
    // the buttons are GRANTed to the same roles in 06_security.sql (the manager may run every procedure).
    static bool canEdit(Role role, Feature feature);
    // Add/Edit/Delete buttons of the student page (= canEdit(role, Feature::Students))
    static bool canEditStudents(Role role);
};
