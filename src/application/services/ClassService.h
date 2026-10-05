#pragma once

#include "application/ports/IClassRepository.h"

#include <QCoreApplication>

// Classes use case: open and change classes, their weekly schedule and sessions, start / cancel them and
// close them with the results. Checks the input (ClassInfo::validate, ScheduleSlot::validate) before the
// repository; the database checks the rules across tables (room, clashes, life cycle) again. Used by
// ClassPage and its dialogs; tested in tests/tst_application.cpp with a fake repository.
class ClassService {
    Q_DECLARE_TR_FUNCTIONS(ClassService)
public:
    explicit ClassService(IClassRepository& repository);

    Result<TableData> search(const ClassFilter& filter);
    Result<ClassInfo> details(const QString& id);
    Result<QString> add(const ClassInfo& c); // the new ClassId
    VoidResult update(const ClassInfo& c);
    Result<QList<ScheduleSlot>> schedule(const QString& classId);
    VoidResult saveSlot(const QString& classId, const ScheduleSlot& slot);
    VoidResult removeSlot(const QString& classId, int weekday);
    Result<SessionsGenerated> generateSessions(const QString& classId);
    VoidResult start(const QString& classId);  // Enrolling -> In progress
    VoidResult cancel(const QString& classId); // Enrolling / In progress -> Cancelled
    Result<EvaluationResult> evaluate(const QString& classId);
    Result<TableData> students(const QString& classId, bool mineOnly);
    Result<TableData> results(const QString& classId);
    Result<QList<LookupItem>> courseOptions();
    Result<QList<LookupItem>> teacherOptions();
    Result<QList<LookupItem>> roomOptions(const QString& branchId);
    Result<qint64> courseTuition(const QString& courseId);

private:
    IClassRepository& m_repository;
};
