#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/ClassInfo.h"
#include "domain/entities/Enrollment.h"

#include <QList>

// Port of the Enrollments module: implemented by SqlEnrollmentRepository (usp_Enrollment_*), faked in
// tst_application.cpp, used by EnrollmentService.
class IEnrollmentRepository {
public:
    virtual ~IEnrollmentRepository() = default;
    virtual Result<TableData> search(const EnrollmentFilter& filter) = 0; // usp_Enrollment_Search
    virtual Result<QString> enroll(const EnrollmentRequest& request) = 0; // usp_Enrollment_Create
    virtual VoidResult transfer(const QString& enrollmentId, const QString& newClassId) = 0;
    virtual VoidResult changeStatus(const QString& enrollmentId, const QString& status) = 0;
    // Classes that accept enrollments (Enrolling / In progress) and promotions valid on a date
    virtual Result<QList<ClassOption>> openClasses() = 0;
    virtual Result<QList<LookupItem>> promotionOptions(const QDate& date) = 0;
};
