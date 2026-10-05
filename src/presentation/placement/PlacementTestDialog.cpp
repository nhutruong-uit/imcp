#include "presentation/placement/PlacementTestDialog.h"

#include "application/services/PlacementService.h"
#include "application/services/StudentService.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Fields.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QLocale>
#include <QPlainTextEdit>
#include <QPushButton>

PlacementTestDialog::PlacementTestDialog(PlacementService& placement, StudentService& students,
                                         const QString& studentId, QWidget* parent)
    : FormDialog(tr("New placement test"), parent), m_placement(placement), m_students(students) {
    auto* searchRow = new QHBoxLayout;
    m_studentSearch = Fields::text(this, 100, studentId);
    m_studentSearch->setPlaceholderText(tr("Student ID, name or phone..."));
    auto* findButton = new QPushButton(tr("Find"), this);
    searchRow->addWidget(m_studentSearch, 1);
    searchRow->addWidget(findButton);
    m_student = new QComboBox(this);
    m_student->setObjectName(QStringLiteral("studentCombo"));

    // Scores in steps of 0.25 (DECIMAL(4,2) columns, 0-10)
    auto score = [this] {
        QDoubleSpinBox* spin = Fields::decimal(this, 0, 10, 2, 5);
        spin->setSingleStep(0.25);
        connect(spin, &QDoubleSpinBox::valueChanged, this, &PlacementTestDialog::updateOverall);
        return spin;
    };
    m_listening = score();
    m_speaking = score();
    m_reading = score();
    m_writing = score();
    m_overall = new QLabel(this);
    m_overall->setObjectName(QStringLiteral("CardTitle"));
    const auto graders = m_placement.graderOptions();
    m_grader = Fields::lookup(this, graders.ok() ? graders.value() : QList<LookupItem>(), QString(),
                              tr("Not recorded"));
    if (!graders.ok())
        showError(graders.error()); // otherwise every test would be saved as "Not recorded" without a word
    m_testDate = Fields::date(this, QDate::currentDate());
    m_testDate->setMaximumDate(QDate::currentDate());
    m_notes = new QPlainTextEdit(this);
    m_notes->setMaximumHeight(70);

    form()->addRow(tr("Find student"), searchRow);
    form()->addRow(tr("Student"), m_student);
    form()->addRow(tr("Listening"), m_listening);
    form()->addRow(tr("Speaking"), m_speaking);
    form()->addRow(tr("Reading"), m_reading);
    form()->addRow(tr("Writing"), m_writing);
    form()->addRow(tr("Overall score"), m_overall);
    form()->addRow(tr("Graded by"), m_grader);
    form()->addRow(tr("Test date"), m_testDate);
    form()->addRow(tr("Notes"), m_notes);

    connect(findButton, &QPushButton::clicked, this, &PlacementTestDialog::searchStudents);
    setSearchField(m_studentSearch, [this] { searchStudents(); });
    if (!studentId.isEmpty())
        searchStudents();
    updateOverall();
}

void PlacementTestDialog::searchStudents() {
    StudentFilter filter;
    filter.keyword = m_studentSearch->text();
    const auto result = m_students.search(filter);
    m_student->clear();
    if (!result.ok()) {
        showError(result.error());
        return;
    }
    for (const Student& s : result.value())
        m_student->addItem(QStringLiteral("%1 - %2 (%3)").arg(s.id, s.fullName, DbValues::label(s.status)),
                           s.id);
    showError(m_student->count() == 0 ? tr("No student matches \"%1\".").arg(filter.keyword) : QString());
}

// The same average the database stores (computed column OverallScore)
void PlacementTestDialog::updateOverall() {
    PlacementTest t;
    t.listening = m_listening->value();
    t.speaking = m_speaking->value();
    t.reading = m_reading->value();
    t.writing = m_writing->value();
    m_overall->setText(QLocale().toString(t.overall(), 'f', 2));
}

bool PlacementTestDialog::save() {
    PlacementTest t;
    t.studentId = Fields::value(m_student);
    t.listening = m_listening->value();
    t.speaking = m_speaking->value();
    t.reading = m_reading->value();
    t.writing = m_writing->value();
    t.teacherId = Fields::value(m_grader);
    t.testDate = m_testDate->date();
    t.notes = m_notes->toPlainText();
    const auto result = m_placement.add(t, QDate::currentDate());
    if (!result.ok()) {
        showError(result.error());
        return false;
    }
    m_result = result.value();
    return true;
}
