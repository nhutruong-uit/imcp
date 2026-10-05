#pragma once

#include "application/ports/IStaffRepository.h"

#include <QCoreApplication>

// Staff use case: employees (manager only) and teachers (the manager changes them, academic staff read the
// list and search teachers by certificate). "save" adds a person when the id is empty, else changes them.
// Used by EmployeePage and TeacherPage.
class StaffService {
    Q_DECLARE_TR_FUNCTIONS(StaffService)
public:
    explicit StaffService(IStaffRepository& repository);

    Result<TableData> employees();
    Result<Employee> employee(const QString& id);
    Result<QString> saveEmployee(const Employee& e, const QDate& today); // the EmployeeId
    Result<TableData> teachers();
    Result<Teacher> teacher(const QString& id);
    Result<QString> saveTeacher(const Teacher& t, const QDate& today); // the TeacherId
    Result<TableData> findTeachersByCertificate(const QString& type, double minScore);

private:
    IStaffRepository& m_repository;
};
