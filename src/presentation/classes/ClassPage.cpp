#include "presentation/classes/ClassPage.h"

#include "presentation/classes/ClassFormDialog.h"
#include "presentation/classes/ScheduleDialog.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QMessageBox>

ClassPage::ClassPage(AppServices services, QWidget* parent) : DataPage(services, Feature::Classes, parent) {
    m_branchFilter = new QComboBox(this);
    m_branchFilter->addItem(tr("All branches"), QString());
    const auto branches = m_services.catalog.activeBranches();
    if (branches.ok()) {
        m_branches = branches.value();
        for (const Branch& b : m_branches)
            m_branchFilter->addItem(b.name, b.id);
    }
    m_statusFilter = new QComboBox(this);
    m_statusFilter->addItem(tr("All statuses"), QString());
    for (const QString& status : ClassValues::statuses())
        m_statusFilter->addItem(DbValues::label(status), status);
    addFilter(m_branchFilter);
    addFilter(m_statusFilter);

    if (canEdit()) {
        addAction(tr("New class"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { addClass(); });
        addAction(tr("Edit"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editClass(); });
        addAction(tr("Weekly schedule"), QStringLiteral("clock"), QStringLiteral("scheduleButton"), true,
                  [this] { editSchedule(); });
        addAction(tr("Generate sessions"), QStringLiteral("calendar"), QStringLiteral("generateButton"), true,
                  [this] { generateSessions(selectedClassId(), true); });
        addAction(tr("Start"), QStringLiteral("play"), QStringLiteral("startButton"), true,
                  [this] { startClass(); });
        addAction(tr("Cancel class"), QStringLiteral("x-circle"), QStringLiteral("cancelButton"), true,
                  [this] { cancelClass(); });
        addAction(tr("Evaluate results"), QStringLiteral("award"), QStringLiteral("evaluateButton"), true,
                  [this] { evaluateResults(); });
    } else {
        addAction(tr("Weekly schedule"), QStringLiteral("clock"), QStringLiteral("scheduleButton"), true,
                  [this] { editSchedule(); });
    }
    addAction(tr("Students"), QStringLiteral("users"), QStringLiteral("studentsButton"), true,
              [this] { showStudents(); });
    addAction(tr("Results"), QStringLiteral("list"), QStringLiteral("resultsButton"), true,
              [this] { showResults(); });

    connect(m_branchFilter, &QComboBox::currentIndexChanged, this, &ClassPage::reload);
    connect(m_statusFilter, &QComboBox::currentIndexChanged, this, &ClassPage::reload);
    connect(table(), &DataTable::activated, this, [this] {
        if (canEdit())
            editClass();
    });
    reload();
}

Result<TableData> ClassPage::fetch() {
    ClassFilter filter;
    filter.branchId = m_branchFilter->currentData().toString();
    filter.status = m_statusFilter->currentData().toString();
    return m_services.classes.search(filter);
}

QString ClassPage::selectedClassId() const {
    return selected(QStringLiteral("ClassId")).toString();
}

QString ClassPage::selectedClassName() const {
    return selected(QStringLiteral("ClassName")).toString();
}

void ClassPage::addClass() {
    ClassInfo c;
    c.branchId = m_branchFilter->currentData().toString();
    ClassFormDialog dialog(m_services.classes, m_branches, c, this);
    if (dialog.exec() != QDialog::Accepted)
        return;
    reloadAndSelect(QStringLiteral("ClassId"), dialog.savedClassId());
    QMessageBox::information(
        this, tr("Class created"),
        tr("Class %1 was created. Next, set its weekly schedule, then generate its sessions.")
            .arg(dialog.savedClassId()));
}

void ClassPage::editClass() {
    const auto details = m_services.classes.details(selectedClassId());
    if (!details.ok()) {
        UiHelpers::showError(this, details.error());
        return;
    }
    ClassFormDialog dialog(m_services.classes, m_branches, details.value(), this);
    if (dialog.exec() != QDialog::Accepted)
        return;
    // A new start date removed the old sessions (usp_Class_Update): build them again from that date
    if (dialog.startDateChanged())
        generateSessions(dialog.savedClassId(), false);
    reloadAndSelect(QStringLiteral("ClassId"), dialog.savedClassId());
}

void ClassPage::editSchedule() {
    const QString id = selectedClassId();
    ScheduleDialog dialog(m_services.classes, id, selectedClassName(), canEdit(), this);
    dialog.exec();
    if (dialog.changed())
        reloadAndSelect(QStringLiteral("ClassId"), id);
}

void ClassPage::generateSessions(const QString& classId, bool askFirst) {
    if (askFirst &&
        !UiHelpers::confirm(this, tr("Generate the sessions of class %1 from its weekly schedule? "
                                     "Sessions generated before are replaced.")
                                      .arg(classId)))
        return;
    const auto result = m_services.classes.generateSessions(classId);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    QMessageBox::information(this, tr("Sessions generated"),
                             tr("%1 sessions were created; the last one is on %2.")
                                 .arg(result.value().count)
                                 .arg(Format::date(result.value().endDate)));
    reloadAndSelect(QStringLiteral("ClassId"), classId);
}

void ClassPage::startClass() {
    const QString id = selectedClassId();
    if (!UiHelpers::confirm(this, tr("Start class %1 - %2?").arg(id, selectedClassName())))
        return;
    const auto result = m_services.classes.start(id);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("ClassId"), id);
}

void ClassPage::cancelClass() {
    const QString id = selectedClassId();
    if (!UiHelpers::confirm(
            this,
            tr("Cancel class %1 - %2? Its open enrollments end (status Left).").arg(id, selectedClassName())))
        return;
    const auto result = m_services.classes.cancel(id);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("ClassId"), id);
}

void ClassPage::showStudents() {
    const QString id = selectedClassId();
    const auto students = m_services.classes.students(id, false);
    if (!students.ok()) {
        UiHelpers::showError(this, students.error());
        return;
    }
    TableDialog dialog(tr("Students of class %1 - %2").arg(id, selectedClassName()),
                       Labels::accountName(m_services.auth.account()), this);
    dialog.setData(students.value());
    dialog.exec();
}

void ClassPage::evaluateResults() {
    const QString id = selectedClassId();
    if (!UiHelpers::confirm(this,
                            tr("Close class %1 with its results? Every student gets the final grade and "
                               "Passed or Failed, the students who passed get a certificate and the class "
                               "becomes Finished: its grades and attendance can no longer change.")
                                .arg(id)))
        return;
    const auto result = m_services.classes.evaluate(id);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    QMessageBox::information(
        this, tr("Results evaluated"),
        tr("%1 students passed, %2 failed.").arg(result.value().passed).arg(result.value().failed));
    reloadAndSelect(QStringLiteral("ClassId"), id);
    showResults();
}

void ClassPage::showResults() {
    const QString id = selectedClassId();
    const auto results = m_services.classes.results(id);
    if (!results.ok()) {
        UiHelpers::showError(this, results.error());
        return;
    }
    TableDialog dialog(tr("Results of class %1 - %2").arg(id, selectedClassName()),
                       Labels::accountName(m_services.auth.account()), this);
    dialog.setSubtitle(
        tr("Final grade, classification, attendance and certificate number of every student (the "
           "final grade stays empty while a score is missing)."));
    dialog.setData(results.value());
    dialog.exec();
}
