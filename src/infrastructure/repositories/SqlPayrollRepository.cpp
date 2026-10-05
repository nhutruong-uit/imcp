#include "infrastructure/repositories/SqlPayrollRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlPayrollRepository::SqlPayrollRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlPayrollRepository::list(const PayrollFilter& filter) {
    // 0 = no filter on the year / month (sent as NULL)
    const QVariant year = intOrNull(filter.year, filter.year > 0);
    const QVariant month = intOrNull(filter.month, filter.month > 0);
    return queryTable(
        m_db,
        QStringLiteral("SELECT py.PayrollId, py.Year, py.Month, te.TeacherId, te.FullName AS TeacherName, "
                       "py.SessionCount, py.Hours, py.HourlyRate, py.Bonus, py.Deduction, py.TotalPay, "
                       "py.Status FROM dbo.PAYROLL py JOIN dbo.TEACHER te ON te.TeacherId = py.TeacherId "
                       "WHERE (? IS NULL OR py.Year = ?) AND (? IS NULL OR py.Month = ?) "
                       "ORDER BY py.Year DESC, py.Month DESC, te.FullName"),
        {year, year, month, month});
}

Result<TableData> SqlPayrollRepository::finalize(int month, int year) {
    // The cursor procedure returns the payroll of the month (TeacherId, TeacherName, SessionCount...)
    return queryTable(m_db, QStringLiteral("EXEC dbo.usp_Payroll_Finalize @Month = ?, @Year = ?"),
                      {month, year});
}

VoidResult SqlPayrollRepository::adjust(int payrollId, qint64 deduction) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Payroll_Adjust @PayrollId = ?, @Deduction = ?"),
                    {payrollId, deduction});
}

VoidResult SqlPayrollRepository::markPaid(int payrollId) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Payroll_MarkPaid @PayrollId = ?"), {payrollId});
}
