#include "application/services/PlacementService.h"

PlacementService::PlacementService(IPlacementRepository& repository) : m_repository(repository) {}

Result<TableData> PlacementService::search(const QString& keyword, const QString& studentId) {
    return m_repository.search(keyword.trimmed(), studentId);
}

Result<PlacementResult> PlacementService::add(const PlacementTest& test, const QDate& today) {
    PlacementTest t = test;
    t.notes = t.notes.trimmed();
    const QStringList errors = t.validate(today);
    if (!errors.isEmpty())
        return Result<PlacementResult>::failure(errors.join(QLatin1Char('\n')));
    return m_repository.add(t);
}

Result<QList<LookupItem>> PlacementService::graderOptions() {
    return m_repository.graderOptions();
}
