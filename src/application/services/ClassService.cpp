#include "application/services/ClassService.h"

ClassService::ClassService(IClassRepository& repository) : m_repository(repository) {}

Result<TableData> ClassService::search(const ClassFilter& filter) {
    return m_repository.search(filter);
}

Result<ClassInfo> ClassService::details(const QString& id) {
    if (id.isEmpty())
        return Result<ClassInfo>::failure(tr("No class is selected."));
    return m_repository.findById(id);
}

Result<QString> ClassService::add(const ClassInfo& c) {
    ClassInfo cleaned = c;
    cleaned.name = cleaned.name.simplified();
    const QStringList errors = cleaned.validate();
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    return m_repository.add(cleaned);
}

VoidResult ClassService::update(const ClassInfo& c) {
    if (c.id.isEmpty())
        return VoidResult::failure(tr("No class is selected."));
    ClassInfo cleaned = c;
    cleaned.name = cleaned.name.simplified();
    const QStringList errors = cleaned.validate();
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.update(cleaned);
}

Result<QList<ScheduleSlot>> ClassService::schedule(const QString& classId) {
    if (classId.isEmpty())
        return Result<QList<ScheduleSlot>>::failure(tr("No class is selected."));
    return m_repository.schedule(classId);
}

VoidResult ClassService::saveSlot(const QString& classId, const ScheduleSlot& slot) {
    if (classId.isEmpty())
        return VoidResult::failure(tr("No class is selected."));
    const QStringList errors = slot.validate();
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.saveSlot(classId, slot);
}

VoidResult ClassService::removeSlot(const QString& classId, int weekday) {
    if (classId.isEmpty() || weekday < 1 || weekday > 7)
        return VoidResult::failure(tr("No time slot is selected."));
    return m_repository.removeSlot(classId, weekday);
}

Result<SessionsGenerated> ClassService::generateSessions(const QString& classId) {
    if (classId.isEmpty())
        return Result<SessionsGenerated>::failure(tr("No class is selected."));
    return m_repository.generateSessions(classId);
}

VoidResult ClassService::start(const QString& classId) {
    if (classId.isEmpty())
        return VoidResult::failure(tr("No class is selected."));
    return m_repository.changeStatus(classId, ClassValues::inProgress());
}

VoidResult ClassService::cancel(const QString& classId) {
    if (classId.isEmpty())
        return VoidResult::failure(tr("No class is selected."));
    return m_repository.changeStatus(classId, ClassValues::cancelled());
}

Result<EvaluationResult> ClassService::evaluate(const QString& classId) {
    if (classId.isEmpty())
        return Result<EvaluationResult>::failure(tr("No class is selected."));
    return m_repository.evaluate(classId);
}

Result<TableData> ClassService::students(const QString& classId, bool mineOnly) {
    if (classId.isEmpty())
        return Result<TableData>::failure(tr("No class is selected."));
    return m_repository.students(classId, mineOnly);
}

Result<TableData> ClassService::results(const QString& classId) {
    if (classId.isEmpty())
        return Result<TableData>::failure(tr("No class is selected."));
    return m_repository.results(classId);
}

Result<QList<LookupItem>> ClassService::courseOptions() {
    return m_repository.courseOptions();
}

Result<QList<LookupItem>> ClassService::teacherOptions() {
    return m_repository.teacherOptions();
}

Result<QList<LookupItem>> ClassService::roomOptions(const QString& branchId) {
    if (branchId.isEmpty())
        return Result<QList<LookupItem>>::success({});
    return m_repository.roomOptions(branchId);
}

Result<qint64> ClassService::courseTuition(const QString& courseId) {
    if (courseId.isEmpty())
        return Result<qint64>::success(0);
    return m_repository.courseTuition(courseId);
}
