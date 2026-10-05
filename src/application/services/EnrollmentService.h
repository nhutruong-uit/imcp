#pragma once

#include "application/ports/IEnrollmentRepository.h"

#include <QCoreApplication>

// Enrollment use case: enroll a student, transfer them to another class of the same course and branch, put an
// enrollment on hold, resume it or end it. The database checks the entry requirement, the seats, the schedule
// clash and the promotion (usp_Enrollment_*); this service checks the input and offers the right choices
// (open classes, transfer targets, valid promotions). Used by EnrollmentPage and the Students page.
class EnrollmentService {
    Q_DECLARE_TR_FUNCTIONS(EnrollmentService)
public:
    explicit EnrollmentService(IEnrollmentRepository& repository);

    Result<TableData> search(const EnrollmentFilter& filter);
    Result<QString> enroll(const EnrollmentRequest& request, const QDate& today); // the new EnrollmentId
    VoidResult transfer(const QString& enrollmentId, const QString& currentClassId,
                        const QString& newClassId);
    VoidResult putOnHold(const QString& enrollmentId);
    VoidResult resume(const QString& enrollmentId);
    VoidResult leave(const QString& enrollmentId);
    Result<QList<ClassOption>> openClasses();
    // Classes a student of currentClassId may move to: open, same course and branch, not the class itself
    Result<QList<ClassOption>> transferTargets(const QString& currentClassId);
    Result<QList<LookupItem>> promotionOptions(const QDate& date);

private:
    VoidResult changeStatus(const QString& enrollmentId, const QString& status);
    IEnrollmentRepository& m_repository;
};
