#pragma once

#include "application/ports/IClassRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IClassRepository with SQL Server: reads vw_ClassDetails and the catalogs granted to academic staff, writes
// through usp_Class_Create / _Update / _UpdateStatus / _GenerateSessions / _EvaluateResults and
// usp_ClassSchedule_Add / _Remove (template: SqlStudentRepository).
class SqlClassRepository : public IClassRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlClassRepository)
public:
    explicit SqlClassRepository(DatabaseManager& db);
    Result<TableData> search(const ClassFilter& filter) override;
    Result<ClassInfo> findById(const QString& id) override;
    Result<QString> add(const ClassInfo& c) override;
    VoidResult update(const ClassInfo& c) override;
    Result<QList<ScheduleSlot>> schedule(const QString& classId) override;
    VoidResult saveSlot(const QString& classId, const ScheduleSlot& slot) override;
    VoidResult removeSlot(const QString& classId, int weekday) override;
    Result<SessionsGenerated> generateSessions(const QString& classId) override;
    VoidResult changeStatus(const QString& classId, const QString& status) override;
    Result<EvaluationResult> evaluate(const QString& classId) override;
    Result<TableData> students(const QString& classId, bool mineOnly) override;
    Result<TableData> results(const QString& classId) override;
    Result<QList<LookupItem>> courseOptions() override;
    Result<QList<LookupItem>> teacherOptions() override;
    Result<QList<LookupItem>> roomOptions(const QString& branchId) override;
    Result<qint64> courseTuition(const QString& courseId) override;

private:
    DatabaseManager& m_db;
};
