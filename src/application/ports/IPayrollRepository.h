#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Payroll.h"

// Port of the Teacher payroll screen: implemented by SqlPayrollRepository (PAYROLL, usp_Payroll_*), used by
// PayrollService.
class IPayrollRepository {
public:
    virtual ~IPayrollRepository() = default;
    virtual Result<TableData> list(const PayrollFilter& filter) = 0;
    virtual Result<TableData> finalize(int month, int year) = 0;    // usp_Payroll_Finalize returns the month
    virtual VoidResult adjust(int payrollId, qint64 deduction) = 0; // usp_Payroll_Adjust
    virtual VoidResult markPaid(int payrollId) = 0;                 // usp_Payroll_MarkPaid
};
