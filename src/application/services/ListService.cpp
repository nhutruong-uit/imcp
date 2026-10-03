#include "application/services/ListService.h"

#include <optional>

namespace {
// Which database list a menu feature shows. std::nullopt ("no value") = the feature has its own page.
std::optional<ListKind> listFor(Feature feature) {
    switch (feature) {
    case Feature::Classes:
        return ListKind::Classes;
    case Feature::WeeklySchedule:
        return ListKind::WeeklySchedule;
    case Feature::LearningResults:
        return ListKind::LearningResults;
    case Feature::OutstandingTuition:
        return ListKind::OutstandingTuition;
    case Feature::Revenue:
        return ListKind::MonthlyRevenue;
    case Feature::Payroll:
        return ListKind::Payroll;
    case Feature::Accounts:
        return ListKind::Accounts;
    case Feature::MyClasses:
        return ListKind::MyClasses;
    case Feature::MyTeachingSchedule:
        return ListKind::MyTeachingSchedule;
    case Feature::MyPay:
        return ListKind::MyPay;
    case Feature::Dashboard:
    case Feature::Students:
        break;
    }
    return std::nullopt;
}
} // namespace

ListService::ListService(IListRepository& repository, const AuthService& auth)
    : m_repository(repository), m_auth(auth) {}

bool ListService::hasList(Feature feature) {
    return listFor(feature).has_value();
}

Result<TableData> ListService::fetch(Feature feature) {
    if (!Permissions::isAllowed(m_auth.role(), feature))
        return Result<TableData>::failure(tr("You are not allowed to view this feature."));
    const auto kind = listFor(feature);
    if (!kind)
        return Result<TableData>::failure(tr("This feature has no lookup list."));
    return m_repository.fetch(*kind);
}
