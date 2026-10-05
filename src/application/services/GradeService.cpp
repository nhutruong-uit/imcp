#include "application/services/GradeService.h"

GradeService::GradeService(IGradeRepository& repository) : m_repository(repository) {}

Result<QList<ClassOption>> GradeService::classes(bool mineOnly) {
    return m_repository.classes(mineOnly);
}

Result<GradeBook> GradeService::book(const QString& classId, bool mineOnly) {
    if (classId.isEmpty())
        return Result<GradeBook>::failure(tr("No class is selected."));
    const auto cells = m_repository.cells(classId, mineOnly);
    if (!cells.ok())
        return Result<GradeBook>::failure(cells.error());
    return Result<GradeBook>::success(GradeBook::fromCells(cells.value()));
}

VoidResult GradeService::save(const QList<GradeEntry>& entries) {
    for (const GradeEntry& e : entries) {
        if (e.enrollmentId.isEmpty() || e.componentId <= 0)
            return VoidResult::failure(tr("A score has no student or grade component."));
        if (e.score < GradeLimits::minScore || e.score > GradeLimits::maxScore)
            return VoidResult::failure(tr("Grades must be between 0 and 10."));
    }
    if (entries.isEmpty())
        return VoidResult::success(); // nothing changed
    return m_repository.save(entries);
}
