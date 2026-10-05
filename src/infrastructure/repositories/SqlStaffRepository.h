#pragma once

#include "application/ports/IStaffRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IStaffRepository with SQL Server: EMPLOYEE and TEACHER (the teacher list names only the columns of the
// column-level GRANT to academic staff), usp_Employee_Add / _Update, usp_Teacher_Add / _Update and the XQuery
// search usp_Teacher_FindByCertificate.
class SqlStaffRepository : public IStaffRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlStaffRepository)
public:
    explicit SqlStaffRepository(DatabaseManager& db);
    Result<TableData> employees() override;
    Result<Employee> employee(const QString& id) override;
    Result<QString> addEmployee(const Employee& e) override;
    VoidResult updateEmployee(const Employee& e) override;
    Result<TableData> teachers() override;
    Result<Teacher> teacher(const QString& id) override;
    Result<QString> addTeacher(const Teacher& t) override;
    VoidResult updateTeacher(const Teacher& t) override;
    Result<TableData> findTeachersByCertificate(const QString& type, double minScore) override;

private:
    DatabaseManager& m_db;
};
