#pragma once

#include "application/ports/IPayrollRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IPayrollRepository with SQL Server: PAYROLL joined with TEACHER (the accountant has a column-level GRANT on
// TEACHER that includes TeacherId and FullName), usp_Payroll_Finalize / _Adjust / _MarkPaid.
class SqlPayrollRepository : public IPayrollRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlPayrollRepository)
public:
    explicit SqlPayrollRepository(DatabaseManager& db);
    Result<TableData> list(const PayrollFilter& filter) override;
    Result<TableData> finalize(int month, int year) override;
    VoidResult adjust(int payrollId, qint64 deduction) override;
    VoidResult markPaid(int payrollId) override;

private:
    DatabaseManager& m_db;
};
