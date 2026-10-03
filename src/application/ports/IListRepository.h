#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"

// Read-only lookup lists (each kind maps to one view/procedure in the database)
enum class ListKind {
    Classes,            // vw_ClassDetails
    WeeklySchedule,     // vw_SessionDetails (current week)
    OutstandingTuition, // vw_OutstandingTuition
    LearningResults,    // vw_LearningResults
    MonthlyRevenue,     // vw_MonthlyRevenue
    Payroll,            // PAYROLL
    Accounts,           // usp_Account_List
    MyClasses,          // vw_Teacher_MyClasses
    MyTeachingSchedule, // vw_Teacher_MySchedule
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
