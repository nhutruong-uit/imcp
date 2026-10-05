#pragma once

#include "application/ports/IStudentRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IStudentRepository implemented with the usp_Student_* procedures of SQL Server.
// Reference repository: each function = one procedure call. Values always travel as '?' parameters through
// SqlHelpers::execPrepared (never pasted into the SQL text); an empty optional field is sent as NULL
// (stringOrNull); a failed call returns Result::failure with the message of SqlErrorMapper.
class SqlStudentRepository : public IStudentRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlStudentRepository)
public:
    explicit SqlStudentRepository(DatabaseManager& db);
    Result<QList<Student>> search(const StudentFilter& filter) override;
    Result<Student> findById(const QString& id) override;
    Result<QString> add(const Student& student) override;
    VoidResult update(const Student& student) override;
    VoidResult remove(const QString& id) override;
    Result<QString> exportXml(const QString& branchId) override;
    Result<ImportResult> importXml(const QString& xml, const QString& branchId) override;

private:
    DatabaseManager& m_db;
};
