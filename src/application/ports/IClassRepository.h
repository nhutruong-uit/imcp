#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/ClassInfo.h"

#include <QList>

// Port of the Classes module (see IStudentRepository.h for what a port is): implemented by SqlClassRepository
// (vw_ClassDetails and the usp_Class_* / usp_ClassSchedule_* procedures), faked in tst_application.cpp, used
// by ClassService.
class IClassRepository {
public:
    virtual ~IClassRepository() = default;
    virtual Result<TableData> search(const ClassFilter& filter) = 0; // vw_ClassDetails
    virtual Result<ClassInfo> findById(const QString& id) = 0;
    virtual Result<QString> add(const ClassInfo& c) = 0; // usp_Class_Create, returns the new ClassId
    virtual VoidResult update(const ClassInfo& c) = 0;   // usp_Class_Update
    virtual Result<QList<ScheduleSlot>> schedule(const QString& classId) = 0;
    virtual VoidResult saveSlot(const QString& classId,
                                const ScheduleSlot& slot) = 0; // usp_ClassSchedule_Add
    virtual VoidResult removeSlot(const QString& classId, int weekday) = 0;
    virtual Result<SessionsGenerated> generateSessions(const QString& classId) = 0;
    virtual VoidResult changeStatus(const QString& classId, const QString& status) = 0;
    virtual Result<EvaluationResult> evaluate(const QString& classId) = 0;
    // The students of a class: usp_Enrollment_ByClass, or vw_Teacher_MyStudents for the signed-in teacher
    virtual Result<TableData> students(const QString& classId, bool mineOnly) = 0;
    virtual Result<TableData> results(const QString& classId) = 0; // usp_Report_ClassResults
    // Choices of the class form: open courses, teachers still teaching, rooms of a branch
    virtual Result<QList<LookupItem>> courseOptions() = 0;
    virtual Result<QList<LookupItem>> teacherOptions() = 0;
    virtual Result<QList<LookupItem>> roomOptions(const QString& branchId) = 0;
    virtual Result<qint64> courseTuition(const QString& courseId) = 0;
};
