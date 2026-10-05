#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"

// Read-only lookup lists (each kind maps to one view in the database). The screens that also change data have
// their own service and repository (ClassService, TuitionService...).
enum class ListKind {
    OutstandingTuition, // vw_OutstandingTuition
    LearningResults,    // vw_LearningResults
    MonthlyRevenue,     // vw_MonthlyRevenue
    MyClasses,          // vw_Teacher_MyClasses
    MyPay               // vw_Teacher_MyPay
};

// Port (interface, see IStudentRepository.h) of the read-only lists: implemented by SqlListRepository (one
// query per ListKind), used by ListService. A new list = a new ListKind value + its query + a Feature mapped
// to it in ListService.cpp (recipe: docs/ARCHITECTURE.md, "Read-only list screens need no new page").
class IListRepository {
public:
    virtual ~IListRepository() = default;
    virtual Result<TableData> fetch(ListKind kind) = 0;
};
