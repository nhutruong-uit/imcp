#include "presentation/enrollments/EnrollmentPage.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/enrollments/EnrollDialog.h"

#include <QComboBox>
#include <QFormLayout>
#include <QLabel>

EnrollmentPage::EnrollmentPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Enrollments, parent) {
    m_statusFilter = new QComboBox(this);
    m_statusFilter->addItem(tr("All statuses"), QString());
    for (const QString& status : EnrollmentValues::statuses())
        m_statusFilter->addItem(DbValues::label(status), status);
    addFilter(m_statusFilter);

    if (canEdit()) {
        addAction(tr("New enrollment"), QStringLiteral("user-plus"), QStringLiteral("addButton"), false,
                  [this] { enroll(); });
        addAction(tr("Transfer class"), QStringLiteral("transfer"), QStringLiteral("transferButton"), true,
                  [this] { transfer(); });
        addAction(tr("Put on hold"), QStringLiteral("pause"), QStringLiteral("holdButton"), true,
                  [this] { changeStatus(EnrollmentValues::onHold()); });
        addAction(tr("Resume"), QStringLiteral("play"), QStringLiteral("resumeButton"), true,
                  [this] { changeStatus(EnrollmentValues::studying()); });
        addAction(tr("Leave"), QStringLiteral("x-circle"), QStringLiteral("leaveButton"), true,
                  [this] { changeStatus(EnrollmentValues::left()); });
    }
    connect(m_statusFilter, &QComboBox::currentIndexChanged, this, &EnrollmentPage::reload);
    reload();
}

Result<TableData> EnrollmentPage::fetch() {
    EnrollmentFilter filter;
    filter.status = m_statusFilter->currentData().toString();
    return m_services.enrollments.search(filter);
}

void EnrollmentPage::enroll() {
    EnrollDialog dialog(m_services.enrollments, m_services.students, QString(), QString(), this);
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("EnrollmentId"), dialog.enrollmentId());
}

// Transfer: only to an open class of the same course and branch (the rule of usp_Enrollment_TransferClass)
void EnrollmentPage::transfer() {
    const QString enrollmentId = selected(QStringLiteral("EnrollmentId")).toString();
    const QString classId = selected(QStringLiteral("ClassId")).toString();
    const auto targets = m_services.enrollments.transferTargets(classId);
    if (!targets.ok()) {
        UiHelpers::showError(this, targets.error());
        return;
    }
    if (targets.value().isEmpty()) {
        UiHelpers::showError(this, tr("There is no other open class of the same course and branch."));
        return;
    }
    FormDialog dialog(
        tr("Transfer %1 to another class").arg(selected(QStringLiteral("StudentName")).toString()), this);
    auto* current = new QLabel(
        QStringLiteral("%1 - %2").arg(classId, selected(QStringLiteral("ClassName")).toString()), &dialog);
    auto* target = new QComboBox(&dialog);
    target->setObjectName(QStringLiteral("targetClassCombo"));
    for (const ClassOption& c : targets.value())
        target->addItem(tr("%1 - %2 (%3 seats left)").arg(c.id, c.name).arg(c.seatsLeft), c.id);
    dialog.form()->addRow(tr("Current class"), current);
    dialog.form()->addRow(tr("New class"), target);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("The payments stay with the enrollment; the tuition of the new "
                                        "class applies and the attendance starts again."),
                                     &dialog));
    dialog.setSaveText(tr("Transfer"));
    dialog.setSaveAction(
        [&] { return m_services.enrollments.transfer(enrollmentId, classId, Fields::value(target)); });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("EnrollmentId"), enrollmentId);
}

void EnrollmentPage::changeStatus(const QString& status) {
    const QString enrollmentId = selected(QStringLiteral("EnrollmentId")).toString();
    const QString student = selected(QStringLiteral("StudentName")).toString();
    const QString className = selected(QStringLiteral("ClassName")).toString();
    QString question;
    if (status == EnrollmentValues::onHold())
        question = tr("Put the enrollment of %1 in %2 on hold?").arg(student, className);
    else if (status == EnrollmentValues::studying())
        question = tr("Resume the enrollment of %1 in %2?").arg(student, className);
    else
        question =
            tr("End the enrollment of %1 in %2 (the student leaves the class)?").arg(student, className);
    if (!UiHelpers::confirm(this, question))
        return;
    VoidResult result = VoidResult::success();
    if (status == EnrollmentValues::onHold())
        result = m_services.enrollments.putOnHold(enrollmentId);
    else if (status == EnrollmentValues::studying())
        result = m_services.enrollments.resume(enrollmentId);
    else
        result = m_services.enrollments.leave(enrollmentId);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("EnrollmentId"), enrollmentId);
}
