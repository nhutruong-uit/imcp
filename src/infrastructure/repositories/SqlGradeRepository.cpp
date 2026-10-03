#include "infrastructure/repositories/SqlGradeRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlGradeRepository::SqlGradeRepository(DatabaseManager& db) : m_db(db) {}

Result<QList<ClassOption>> SqlGradeRepository::classes(bool mineOnly) {
    // The classes that have (or had) students to grade: not the cancelled ones; classes in progress first
    const QString sql =
        mineOnly
            ? QStringLiteral("SELECT ClassId, ClassName, CourseId, CourseName, N'' AS BranchId, BranchName, "
                             "Status FROM dbo.vw_Teacher_MyClasses WHERE Status <> N'Cancelled' "
                             "ORDER BY CASE Status WHEN N'In progress' THEN 0 ELSE 1 END, StartDate DESC")
            : QStringLiteral("SELECT ClassId, ClassName, CourseId, CourseName, BranchId, BranchName, Status "
                             "FROM dbo.vw_ClassDetails WHERE Status <> N'Cancelled' "
                             "ORDER BY CASE Status WHEN N'In progress' THEN 0 ELSE 1 END, StartDate DESC");
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, sql, {}))
        return Result<QList<ClassOption>>::failure(errorOf(q));
    QList<ClassOption> classes;
    while (q.next()) {
        ClassOption c;
        c.id = q.value(0).toString();
        c.name = q.value(1).toString();
        c.courseId = q.value(2).toString();
        c.courseName = q.value(3).toString();
        c.branchId = q.value(4).toString();
        c.branchName = q.value(5).toString();
        c.status = q.value(6).toString();
        classes.append(c);
    }
    return Result<QList<ClassOption>>::success(classes);
}

Result<QList<GradeCell>> SqlGradeRepository::cells(const QString& classId, bool mineOnly) {
    // Same columns from both sources: EnrollmentId, ClassId, StudentId, StudentName, ComponentId,
    // ComponentName, Weight, Score (NULL = not entered yet)
    const QString sql =
        mineOnly ? QStringLiteral("SELECT EnrollmentId, ClassId, StudentId, StudentName, ComponentId, "
                                  "ComponentName, Weight, Score FROM dbo.vw_Teacher_MyGrades "
                                  "WHERE ClassId = ? ORDER BY StudentName, EnrollmentId, ComponentId")
                 : QStringLiteral("EXEC dbo.usp_Grade_ByClass @ClassId = ?");
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, sql, {classId}))
        return Result<QList<GradeCell>>::failure(errorOf(q));
    QList<GradeCell> cells;
    while (q.next()) {
        GradeCell c;
        c.enrollmentId = q.value(0).toString();
        c.studentId = q.value(2).toString();
        c.studentName = q.value(3).toString();
        c.componentId = q.value(4).toInt();
        c.componentName = q.value(5).toString();
        c.weight = q.value(6).toDouble();
        if (!q.value(7).isNull())
            c.score = q.value(7).toDouble();
        cells.append(c);
    }
    return Result<QList<GradeCell>>::success(cells);
}

// One usp_Grade_Save call per changed score, in one transaction (all saved, or none)
VoidResult SqlGradeRepository::save(const QList<GradeEntry>& entries) {
    QSqlDatabase db = m_db.db();
    if (!db.transaction())
        return VoidResult::failure(SqlErrorMapper::message(db.lastError()));
    for (const GradeEntry& e : entries) {
        QSqlQuery q = makeQuery(db);
        if (!execPrepared(
                q, m_db,
                QStringLiteral("EXEC dbo.usp_Grade_Save @EnrollmentId = ?, @ComponentId = ?, @Score = ?"),
                {e.enrollmentId, e.componentId, e.score})) {
            const QString error = errorOf(q);
            db.rollback();
            return VoidResult::failure(error);
        }
    }
    if (!db.commit())
        return VoidResult::failure(SqlErrorMapper::message(db.lastError()));
    return VoidResult::success();
}
