#include "application/services/Permissions.h"

QList<Feature> Permissions::allowedFeatures(Role role) {
    switch (role) {
    case Role::Manager:
        return {Feature::Dashboard,      Feature::Students,        Feature::Classes,
                Feature::WeeklySchedule, Feature::LearningResults, Feature::OutstandingTuition,
                Feature::Revenue,        Feature::Payroll,         Feature::Accounts};
    case Role::AcademicStaff:
        return {Feature::Dashboard,      Feature::Students,        Feature::Classes,
                Feature::WeeklySchedule, Feature::LearningResults, Feature::OutstandingTuition};
    case Role::Accountant:
        return {Feature::Dashboard, Feature::Students, Feature::OutstandingTuition, Feature::Revenue,
                Feature::Payroll};
    case Role::Teacher:
        return {Feature::MyClasses, Feature::MyTeachingSchedule, Feature::MyPay};
    case Role::Unknown:
        break;
    }
    return {};
}

bool Permissions::isAllowed(Role role, Feature feature) {
    return allowedFeatures(role).contains(feature);
}

bool Permissions::canEditStudents(Role role) {
    return role == Role::Manager || role == Role::AcademicStaff;
}
