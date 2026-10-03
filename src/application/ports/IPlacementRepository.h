#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/PlacementTest.h"

#include <QList>

// Port of the Placement tests module: implemented by SqlPlacementRepository (usp_PlacementTest_*), used by
// PlacementService.
class IPlacementRepository {
public:
    virtual ~IPlacementRepository() = default;
    // usp_PlacementTest_Search: keyword in test/student ID or name; studentId empty = every student
    virtual Result<TableData> search(const QString& keyword, const QString& studentId) = 0;
    virtual Result<PlacementResult> add(const PlacementTest& test) = 0; // usp_PlacementTest_Add
    virtual Result<QList<LookupItem>> graderOptions() = 0;              // teachers who may grade a test
};
