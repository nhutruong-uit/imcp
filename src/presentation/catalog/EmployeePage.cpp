#include "presentation/catalog/EmployeePage.h"

#include "domain/entities/Student.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLineEdit>

EmployeePage::EmployeePage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Employees, parent) {
    if (canEdit()) {
        addAction(tr("New employee"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { editEmployee(true); });
        addAction(tr("Edit"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editEmployee(false); });
        connect(table(), &DataTable::activated, this, [this] { editEmployee(false); });
    }
    reload();
}

Result<TableData> EmployeePage::fetch() {
    return m_services.staff.employees();
}

void EmployeePage::editEmployee(bool isNew) {
    Employee e;
    if (!isNew) {
        const auto current = m_services.staff.employee(selected(QStringLiteral("EmployeeId")).toString());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        e = current.value();
    }
    QString branchError;
    const QList<LookupItem> branchItems =
        Fields::branchItems(m_services.catalog.activeBranches(), &branchError);

    FormDialog dialog(isNew ? tr("New employee") : tr("Edit employee %1").arg(e.id), this);
    auto* name = Fields::text(&dialog, StaffLimits::fullName, e.fullName);
    auto* birth =
        Fields::date(&dialog, e.dateOfBirth.isValid() ? e.dateOfBirth : QDate::currentDate().addYears(-25));
    auto* gender = Fields::values(&dialog, StudentValues::genders(), e.gender);
    auto* phone = Fields::digits(&dialog, 11, e.phone);
    auto* email = Fields::text(&dialog, StaffLimits::email, e.email);
    auto* address = Fields::text(&dialog, StaffLimits::address, e.address);
    auto* position = Fields::values(&dialog, StaffValues::positions(), e.position);
    auto* branch = Fields::lookup(&dialog, branchItems, e.branchId);
    auto* hired = Fields::date(&dialog, e.hireDate);
    auto* salary = Fields::money(&dialog, e.baseSalary);
    auto* status = Fields::values(&dialog, StaffValues::employeeStatuses(), e.status);
    status->setEnabled(!isNew);
    dialog.form()->addRow(tr("Full name"), name);
    dialog.form()->addRow(tr("Date of birth"), birth);
    dialog.form()->addRow(tr("Gender"), gender);
    dialog.form()->addRow(tr("Phone"), phone);
    dialog.form()->addRow(tr("Email"), email);
    dialog.form()->addRow(tr("Address"), address);
    dialog.form()->addRow(tr("Position"), position);
    dialog.form()->addRow(tr("Branch"), branch);
    dialog.form()->addRow(tr("Hire date"), hired);
    dialog.form()->addRow(tr("Base salary"), salary);
    dialog.form()->addRow(tr("Status"), status);
    QString savedId = e.id;
    dialog.setSaveAction([&]() -> VoidResult {
        Employee c = e;
        c.fullName = name->text();
        c.dateOfBirth = birth->date();
        c.gender = Fields::value(gender);
        c.phone = phone->text();
        c.email = email->text();
        c.address = address->text();
        c.position = Fields::value(position);
        c.branchId = Fields::value(branch);
        c.hireDate = hired->date();
        c.baseSalary = Fields::moneyValue(salary);
        c.status = Fields::value(status);
        const auto result = m_services.staff.saveEmployee(c, QDate::currentDate());
        if (!result.ok())
            return VoidResult::failure(result.error());
        savedId = result.value();
        return VoidResult::success();
    });
    dialog.showError(branchError); // empty: no error line
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("EmployeeId"), savedId);
}
