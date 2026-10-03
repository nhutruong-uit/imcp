#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Staff.h"

// Port of the Employees and Teachers screens: implemented by SqlStaffRepository (EMPLOYEE, TEACHER,
// usp_Employee_*, usp_Teacher_*, usp_Teacher_FindByCertificate), used by StaffService.
class IStaffRepository {
public:
    virtual ~IStaffRepository() = default;
    virtual Result<TableData> employees() = 0;
    virtual Result<Employee> employee(const QString& id) = 0;
    virtual Result<QString> addEmployee(const Employee& e) = 0; // returns the new EmployeeId
    virtual VoidResult updateEmployee(const Employee& e) = 0;

    // The teacher list names only the columns academic staff may read (column-level GRANT on TEACHER)
    virtual Result<TableData> teachers() = 0;
    virtual Result<Teacher> teacher(const QString& id) = 0; // every column: manager only
    virtual Result<QString> addTeacher(const Teacher& t) = 0;
    virtual VoidResult updateTeacher(const Teacher& t) = 0;
    virtual Result<TableData> findTeachersByCertificate(const QString& type, double minScore) = 0;
};
