#include "presentation/catalog/TeacherPage.h"

#include "domain/entities/Student.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPlainTextEdit>

TeacherPage::TeacherPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Teachers, parent) {
    if (canEdit()) {
        addAction(tr("New teacher"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { editTeacher(true); });
        addAction(tr("Edit"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editTeacher(false); });
        connect(table(), &DataTable::activated, this, [this] { editTeacher(false); });
    }
    addAction(tr("Find by certificate"), QStringLiteral("search"), QStringLiteral("findByCertificateButton"),
              false, [this] { findByCertificate(); });
    reload();
}

Result<TableData> TeacherPage::fetch() {
    return m_services.staff.teachers();
}

void TeacherPage::editTeacher(bool isNew) {
    Teacher t;
    if (!isNew) {
        const auto current = m_services.staff.teacher(selected(QStringLiteral("TeacherId")).toString());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        t = current.value();
    }
    QString branchError;
    const QList<LookupItem> branchItems =
        Fields::branchItems(m_services.catalog.activeBranches(), &branchError);

    FormDialog dialog(isNew ? tr("New teacher") : tr("Edit teacher %1").arg(t.id), this);
    dialog.resize(600, 720);
    auto* name = Fields::text(&dialog, StaffLimits::fullName, t.fullName);
    auto* birth =
        Fields::date(&dialog, t.dateOfBirth.isValid() ? t.dateOfBirth : QDate::currentDate().addYears(-30));
    auto* gender = Fields::values(&dialog, StudentValues::genders(), t.gender);
    auto* nationality = Fields::text(&dialog, StaffLimits::nationality, t.nationality);
    auto* phone = Fields::digits(&dialog, 11, t.phone);
    auto* email = Fields::text(&dialog, StaffLimits::email, t.email);
    auto* degree = Fields::values(&dialog, StaffValues::degrees(), t.degree);
    auto* type = Fields::values(&dialog, StaffValues::teacherTypes(), t.teacherType);
    auto* rate = Fields::money(&dialog, t.hourlyRate);
    auto* branch = Fields::lookup(&dialog, branchItems, t.branchId);
    auto* hired = Fields::date(&dialog, t.hireDate);
    auto* status = Fields::values(&dialog, StaffValues::teacherStatuses(), t.status);
    status->setEnabled(!isNew);
    auto* profile = new QPlainTextEdit(t.profileXml, &dialog);
    profile->setPlaceholderText(
        QStringLiteral("<Profile><Certificate Type=\"IELTS\" Score=\"8.0\"/>"
                       "<Experience Years=\"5\"/><Specialty>Speaking</Specialty></Profile>"));
    profile->setMaximumHeight(110);
    dialog.form()->addRow(tr("Full name"), name);
    dialog.form()->addRow(tr("Date of birth"), birth);
    dialog.form()->addRow(tr("Gender"), gender);
    dialog.form()->addRow(tr("Nationality"), nationality);
    dialog.form()->addRow(tr("Phone"), phone);
    dialog.form()->addRow(tr("Email"), email);
    dialog.form()->addRow(tr("Degree"), degree);
    dialog.form()->addRow(tr("Teacher type"), type);
    dialog.form()->addRow(tr("Hourly rate"), rate);
    dialog.form()->addRow(tr("Branch"), branch);
    dialog.form()->addRow(tr("Hire date"), hired);
    dialog.form()->addRow(tr("Status"), status);
    dialog.form()->addRow(tr("Profile (XML)"), profile);
    QString savedId = t.id;
    dialog.setSaveAction([&]() -> VoidResult {
        Teacher c = t;
        c.fullName = name->text();
        c.dateOfBirth = birth->date();
        c.gender = Fields::value(gender);
        c.nationality = nationality->text();
        c.phone = phone->text();
        c.email = email->text();
        c.degree = Fields::value(degree);
        c.teacherType = Fields::value(type);
        c.hourlyRate = Fields::moneyValue(rate);
        c.branchId = Fields::value(branch);
        c.hireDate = hired->date();
        c.status = Fields::value(status);
        c.profileXml = profile->toPlainText();
        const auto result = m_services.staff.saveTeacher(c, QDate::currentDate());
        if (!result.ok())
            return VoidResult::failure(result.error());
        savedId = result.value();
        return VoidResult::success();
    });
    dialog.showError(branchError); // empty: no error line
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("TeacherId"), savedId);
}

// XQuery on the untyped XML profile: certificate type and minimum score (sql:variable)
void TeacherPage::findByCertificate() {
    FormDialog ask(tr("Find teachers by certificate"), this);
    auto* type = Fields::text(&ask, 20, QStringLiteral("IELTS"));
    auto* minimum = Fields::decimal(&ask, 0, 990, 1, 0);
    ask.form()->addRow(tr("Certificate"), type);
    ask.form()->addRow(tr("Minimum score"), minimum);
    ask.setSaveText(tr("Find"));
    TableData found;
    ask.setSaveAction([&]() -> VoidResult {
        const auto result = m_services.staff.findTeachersByCertificate(type->text(), minimum->value());
        if (!result.ok())
            return VoidResult::failure(result.error());
        found = result.value();
        return VoidResult::success();
    });
    if (ask.exec() != QDialog::Accepted)
        return;
    TableDialog dialog(
        tr("Teachers with %1 of at least %2").arg(type->text().trimmed()).arg(minimum->value()),
        Labels::accountName(m_services.auth.account()), this);
    dialog.setData(found);
    dialog.exec();
}
