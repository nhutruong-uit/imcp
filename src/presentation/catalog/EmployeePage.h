#pragma once

#include "presentation/common/DataPage.h"

// Employees page (manager only): the office staff with their position, branch, salary and sign-in account;
// add an employee (usp_Employee_Add, ID from a SEQUENCE) or change one (usp_Employee_Update; someone with an
// active account cannot be set to Left, 50098).
class EmployeePage : public DataPage {
    Q_OBJECT
public:
    explicit EmployeePage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void editEmployee(bool isNew);
};
