#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>

// Stored values of ENROLLMENT.Status (CK_ENROLLMENT_Status). Completed is only set by
// usp_Class_EvaluateResults; usp_Enrollment_UpdateStatus moves an enrollment between the other three.
namespace EnrollmentValues {
QStringList statuses(); // Studying, On hold, Left, Completed
QString studying();
QString onHold();
QString left();
QString completed();
} // namespace EnrollmentValues

// A new enrollment: usp_Enrollment_Create checks the entry requirement, the schedule clash, the seats and the
// promotion; this struct only checks what is needed to call it.
struct EnrollmentRequest {
    QString studentId;
    QString classId;
    QString promotionId; // empty = no promotion
    QDate enrolledOn;    // empty = today (the procedure's default)

    QStringList validate() const;

    Q_DECLARE_TR_FUNCTIONS(EnrollmentRequest)
};

// Filter of usp_Enrollment_Search (empty field = no filter)
struct EnrollmentFilter {
    QString keyword;
    QString classId;
    QString studentId;
    QString status;
};
