#include "application/services/PayrollService.h"

PayrollService::PayrollService(IPayrollRepository& repository) : m_repository(repository) {}

Result<TableData> PayrollService::list(const PayrollFilter& filter) {
    return m_repository.list(filter);
}

Result<TableData> PayrollService::finalize(int month, int year, const QDate& today) {
    if (month < 1 || month > 12 || year < 2020)
        return Result<TableData>::failure(tr("Invalid month."));
    if (QDate(year, month, 1) > today)
        return Result<TableData>::failure(tr("Payroll cannot be finalized for a future month."));
    return m_repository.finalize(month, year);
}

VoidResult PayrollService::adjust(int payrollId, qint64 deduction) {
    if (payrollId <= 0)
        return VoidResult::failure(tr("No payroll row is selected."));
    if (deduction < 0)
        return VoidResult::failure(tr("The deduction cannot be negative."));
    return m_repository.adjust(payrollId, deduction);
}

VoidResult PayrollService::markPaid(int payrollId) {
    if (payrollId <= 0)
        return VoidResult::failure(tr("No payroll row is selected."));
    return m_repository.markPaid(payrollId);
}
