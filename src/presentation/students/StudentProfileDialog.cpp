#include "presentation/students/StudentProfileDialog.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/UiHelpers.h"

#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>

StudentProfileDialog::StudentProfileDialog(AppServices services, const QString& studentId, QWidget* parent)
    : QDialog(parent) {
    resize(980, 640);
    auto* v = new QVBoxLayout(this);

    // Identity: the search row of the student (the accountant may not read usp_Student_Details)
    StudentFilter filter;
    filter.keyword = studentId;
    const auto students = services.students.search(filter);
    const Student* student = nullptr;
    if (students.ok())
        for (const Student& s : students.value())
            if (s.id == studentId)
                student = &s;
    setWindowTitle(tr("Student profile %1").arg(studentId));
    auto* title =
        new QLabel(student ? QStringLiteral("%1 - %2").arg(studentId, student->fullName) : studentId, this);
    title->setObjectName(QStringLiteral("PageTitle"));
    v->addWidget(title);
    if (student) {
        auto* identity = new QLabel(
            tr("Born %1 · %2 · Phone %3 · %4 · Registered %5 · Status: %6")
                .arg(Format::date(student->dateOfBirth), DbValues::label(student->gender),
                     student->phone.isEmpty() ? student->guardianPhone : student->phone, student->branchName,
                     Format::date(student->registeredOn), DbValues::label(student->status)),
            this);
        identity->setObjectName(QStringLiteral("Muted"));
        identity->setWordWrap(true);
        v->addWidget(identity);
    } else if (!students.ok()) {
        auto* error = new QLabel(students.error(), this);
        error->setObjectName(QStringLiteral("ErrorText"));
        error->setWordWrap(true);
        v->addWidget(error);
    }

    auto* enrollmentsTitle = new QLabel(tr("Enrollments"), this);
    enrollmentsTitle->setObjectName(QStringLiteral("CardTitle"));
    v->addWidget(enrollmentsTitle);
    auto* enrollments = new DataTable(QStringLiteral("profileEnrollmentTable"), this);
    EnrollmentFilter enrollmentFilter;
    enrollmentFilter.studentId = studentId;
    const auto rows = services.enrollments.search(enrollmentFilter);
    enrollments->setData(rows.ok() ? rows.value() : TableData());
    enrollments->setHiddenColumns({QStringLiteral("StudentId"), QStringLiteral("StudentName")});
    v->addWidget(enrollments, 2);
    auto* totals = new QLabel(rows.ok() ? enrollments->totalsText() : rows.error(), this);
    totals->setObjectName(QStringLiteral("Muted"));
    v->addWidget(totals);

    if (Permissions::isAllowed(services.auth.role(), Feature::PlacementTests)) {
        auto* testsTitle = new QLabel(tr("Placement tests"), this);
        testsTitle->setObjectName(QStringLiteral("CardTitle"));
        v->addWidget(testsTitle);
        auto* tests = new DataTable(QStringLiteral("profileTestTable"), this);
        const auto testRows = services.placement.search(QString(), studentId);
        tests->setData(testRows.ok() ? testRows.value() : TableData());
        if (!testRows.ok())
            testsTitle->setText(testRows.error()); // not "no test": the list could not be read
        tests->setHiddenColumns({QStringLiteral("StudentId"), QStringLiteral("StudentName")});
        v->addWidget(tests, 1);
    }

    auto* closeButton = UiHelpers::primaryButton(tr("Close"), QString(), this);
    v->addWidget(closeButton, 0, Qt::AlignRight);
    connect(closeButton, &QPushButton::clicked, this, &QDialog::accept);
}
