#pragma once

#include "application/ports/IPlacementRepository.h"

#include <QCoreApplication>

// Placement test use case: list the tests and record a new one (the database computes the overall score and
// recommends a course). Used by PlacementPage and the Students page.
class PlacementService {
    Q_DECLARE_TR_FUNCTIONS(PlacementService)
public:
    explicit PlacementService(IPlacementRepository& repository);

    Result<TableData> search(const QString& keyword, const QString& studentId = QString());
    Result<PlacementResult> add(const PlacementTest& test, const QDate& today);
    Result<QList<LookupItem>> graderOptions();

private:
    IPlacementRepository& m_repository;
};
