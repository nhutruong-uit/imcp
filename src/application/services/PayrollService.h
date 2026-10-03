#pragma once

#include "application/ports/IPayrollRepository.h"

#include <QCoreApplication>
#include <QDate>

// Teacher payroll use case: list the payroll, finalize a month (cursor procedure usp_Payroll_Finalize), set a
// deduction, mark a row paid. Used by PayrollPage (manager, accountant).
class PayrollService {
    Q_DECLARE_TR_FUNCTIONS(PayrollService)
public:
    explicit PayrollService(IPayrollRepository& repository);

    Result<TableData> list(const PayrollFilter& filter);
    // A future month is refused here and by the procedure (50050)
    Result<TableData> finalize(int month, int year, const QDate& today);
    VoidResult adjust(int payrollId, qint64 deduction);
    VoidResult markPaid(int payrollId);

private:
    IPayrollRepository& m_repository;
};
