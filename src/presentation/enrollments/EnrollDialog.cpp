#include "presentation/enrollments/EnrollDialog.h"

#include "application/services/EnrollmentService.h"
#include "application/services/StudentService.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Fields.h"
#include "presentation/common/Format.h"

#include <QComboBox>
#include <QDateEdit>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>

EnrollDialog::EnrollDialog(EnrollmentService& enrollments, StudentService& students, const QString& studentId,
                           const QString& classId, QWidget* parent)
    : FormDialog(tr("New enrollment"), parent), m_enrollments(enrollments), m_students(students) {
    setMinimumWidth(560);
    // Student: type a part of the ID, name or phone, then pick one of the matches
    auto* searchRow = new QHBoxLayout;
    m_studentSearch = Fields::text(this, 100, studentId);
    m_studentSearch->setObjectName(QStringLiteral("studentSearchEdit"));
    m_studentSearch->setPlaceholderText(tr("Student ID, name or phone..."));
    auto* findButton = new QPushButton(tr("Find"), this);
    searchRow->addWidget(m_studentSearch, 1);
    searchRow->addWidget(findButton);
    m_student = new QComboBox(this);
    m_student->setObjectName(QStringLiteral("studentCombo"));

    m_class = new QComboBox(this);
    m_class->setObjectName(QStringLiteral("classCombo"));
    m_classInfo = new QLabel(this);
    m_classInfo->setObjectName(QStringLiteral("Muted"));
    m_classInfo->setWordWrap(true);
    const auto classes = m_enrollments.openClasses();
    if (classes.ok())
        m_classes = classes.value();
    for (const ClassOption& c : m_classes)
        m_class->addItem(QStringLiteral("%1 - %2 (%3)").arg(c.id, c.name, c.branchName), c.id);
    if (!classId.isEmpty())
        Fields::select(m_class, classId);

    m_enrolledOn = Fields::date(this, QDate::currentDate());
    m_promotion = new QComboBox(this);
    m_promotion->setObjectName(QStringLiteral("promotionCombo"));

    form()->addRow(tr("Find student"), searchRow);
    form()->addRow(tr("Student"), m_student);
    form()->addRow(tr("Class"), m_class);
    form()->addRow(QString(), m_classInfo);
    form()->addRow(tr("Enrollment date"), m_enrolledOn);
    form()->addRow(tr("Promotion"), m_promotion);
    setSaveText(tr("Enroll"));

    connect(findButton, &QPushButton::clicked, this, &EnrollDialog::searchStudents);
    setSearchField(m_studentSearch, [this] { searchStudents(); });
    connect(m_class, &QComboBox::currentIndexChanged, this, &EnrollDialog::showClassInfo);
    connect(m_enrolledOn, &QDateEdit::dateChanged, this, &EnrollDialog::loadPromotions);
    if (!studentId.isEmpty())
        searchStudents();
    showClassInfo();
    loadPromotions();
    if (!classes.ok())
        showError(classes.error());
}

void EnrollDialog::searchStudents() {
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
    if (m_student->count() == 0)
        showError(tr("No student matches \"%1\".").arg(filter.keyword));
    else
        showError(QString());
}

// Promotions valid on the enrollment date (usp_Enrollment_Create refuses an expired code, 50025)
void EnrollDialog::loadPromotions() {
    const QString current = Fields::value(m_promotion);
    const auto promotions = m_enrollments.promotionOptions(m_enrolledOn->date());
    Fields::fillLookup(m_promotion, promotions.ok() ? promotions.value() : QList<LookupItem>(),
                       tr("No promotion"));
    if (!promotions.ok())
        showError(promotions.error()); // "No promotion" alone would hide a valid code
    if (m_promotion->findData(current) >= 0)
        Fields::select(m_promotion, current);
}

void EnrollDialog::showClassInfo() {
    const QString id = Fields::value(m_class);
    for (const ClassOption& c : m_classes) {
        if (c.id != id)
            continue;
        m_classInfo->setText(tr("%1 - %2, tuition %3, %4 seats left")
                                 .arg(c.courseName, DbValues::label(c.status), Format::money(c.tuition))
                                 .arg(c.seatsLeft));
        return;
    }
    m_classInfo->clear();
}

bool EnrollDialog::save() {
    EnrollmentRequest request;
    request.studentId = Fields::value(m_student);
    request.classId = Fields::value(m_class);
    request.promotionId = Fields::value(m_promotion);
    request.enrolledOn = m_enrolledOn->date();
    const auto result = m_enrollments.enroll(request);
    if (!result.ok()) {
        showError(result.error());
        return false;
    }
    m_enrollmentId = result.value();
    return true;
}
