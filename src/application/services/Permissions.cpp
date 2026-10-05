#include "application/services/Permissions.h"

QList<Feature> Permissions::allowedFeatures(Role role) {
    switch (role) {
    case Role::Manager:
        return {Feature::Dashboard,      Feature::Students,
                Feature::PlacementTests, Feature::Classes,
                Feature::Enrollments,    Feature::WeeklySchedule,
                Feature::Grades,         Feature::LearningResults,
                Feature::Tuition,        Feature::OutstandingTuition,
                Feature::Revenue,        Feature::Payroll,
                Feature::Courses,        Feature::Teachers,
                Feature::Employees,      Feature::Branches,
                Feature::Promotions,     Feature::Accounts,
                Feature::Backup};
    case Role::AcademicStaff:
        return {Feature::Dashboard, Feature::Students,        Feature::PlacementTests,
                Feature::Classes,   Feature::Enrollments,     Feature::WeeklySchedule,
                Feature::Grades,    Feature::LearningResults, Feature::OutstandingTuition,
                Feature::Courses,   Feature::Teachers};
    case Role::Accountant:
        return {Feature::Dashboard,          Feature::Students, Feature::Tuition,
                Feature::OutstandingTuition, Feature::Revenue,  Feature::Payroll};
    case Role::Teacher:
        return {Feature::MyClasses, Feature::MyTeachingSchedule, Feature::MyGrades, Feature::MyPay};
    case Role::Unknown:
        break;
    }
    return {};
}

bool Permissions::isAllowed(Role role, Feature feature) {
    return allowedFeatures(role).contains(feature);
}

bool Permissions::canEdit(Role role, Feature feature) {
    if (!isAllowed(role, feature))
        return false;
    const bool manager = role == Role::Manager;
    switch (feature) {
    case Feature::Students:
    case Feature::PlacementTests:
    case Feature::Classes:
    case Feature::Enrollments:
    case Feature::WeeklySchedule:
    case Feature::Grades:
        return manager || role == Role::AcademicStaff;
    case Feature::Tuition:
    case Feature::Payroll:
        return manager || role == Role::Accountant;
    case Feature::Courses:
    case Feature::Teachers:
    case Feature::Employees:
    case Feature::Branches:
    case Feature::Promotions:
    case Feature::Accounts:
    case Feature::Backup:
        return manager;
    case Feature::MyTeachingSchedule:
    case Feature::MyGrades:
        return role == Role::Teacher;
    case Feature::Dashboard:
    case Feature::LearningResults:
    case Feature::OutstandingTuition:
    case Feature::Revenue:
    case Feature::MyClasses:
    case Feature::MyPay:
        break;
    }
    return false;
}

bool Permissions::canEditStudents(Role role) {
    return canEdit(role, Feature::Students);
}
