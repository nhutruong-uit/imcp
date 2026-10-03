#include "application/services/EnrollmentService.h"

EnrollmentService::EnrollmentService(IEnrollmentRepository& repository) : m_repository(repository) {}

Result<TableData> EnrollmentService::search(const EnrollmentFilter& filter) {
    EnrollmentFilter f = filter;
    f.keyword = f.keyword.trimmed();
    return m_repository.search(f);
}

Result<QString> EnrollmentService::enroll(const EnrollmentRequest& request) {
    const QStringList errors = request.validate();
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    return m_repository.enroll(request);
}

VoidResult EnrollmentService::transfer(const QString& enrollmentId, const QString& currentClassId,
                                       const QString& newClassId) {
    if (enrollmentId.isEmpty())
        return VoidResult::failure(tr("No enrollment is selected."));
    if (newClassId.isEmpty())
        return VoidResult::failure(tr("Please choose the new class."));
    if (newClassId == currentClassId)
        return VoidResult::failure(tr("The student is already in this class."));
    return m_repository.transfer(enrollmentId, newClassId);
}

VoidResult EnrollmentService::putOnHold(const QString& enrollmentId) {
    return changeStatus(enrollmentId, EnrollmentValues::onHold());
}

VoidResult EnrollmentService::resume(const QString& enrollmentId) {
    return changeStatus(enrollmentId, EnrollmentValues::studying());
}

VoidResult EnrollmentService::leave(const QString& enrollmentId) {
    return changeStatus(enrollmentId, EnrollmentValues::left());
}

VoidResult EnrollmentService::changeStatus(const QString& enrollmentId, const QString& status) {
    if (enrollmentId.isEmpty())
        return VoidResult::failure(tr("No enrollment is selected."));
    return m_repository.changeStatus(enrollmentId, status);
}

Result<QList<ClassOption>> EnrollmentService::openClasses() {
    return m_repository.openClasses();
}

Result<QList<ClassOption>> EnrollmentService::transferTargets(const QString& currentClassId) {
    const auto classes = m_repository.openClasses();
    if (!classes.ok())
        return classes;
    // The current class gives the course and the branch (the same rule as usp_Enrollment_TransferClass,
    // 50027)
    const ClassOption* current = nullptr;
    for (const ClassOption& c : classes.value())
        if (c.id == currentClassId)
            current = &c;
    QList<ClassOption> targets;
    if (current)
        for (const ClassOption& c : classes.value())
            if (c.id != current->id && c.courseId == current->courseId && c.branchId == current->branchId)
                targets.append(c);
    return Result<QList<ClassOption>>::success(targets);
}

Result<QList<LookupItem>> EnrollmentService::promotionOptions(const QDate& date) {
    return m_repository.promotionOptions(date);
}
