#include "infrastructure/repositories/SqlCourseRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlCourseRepository::SqlCourseRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlCourseRepository::list() {
    // TotalWeight: the sum of the grade weights (must be 100 before a class of the course is evaluated);
    // HasSyllabus: 1 when the XML syllabus exists
    return queryTable(
        m_db,
        QStringLiteral("SELECT co.CourseId, co.CourseName, pg.ProgramName, co.Level, co.SessionCount, "
                       "co.SessionMinutes, co.Tuition, co.MinPlacementScore, co.PrerequisiteCourseId, "
                       "(SELECT ISNULL(SUM(gc.Weight), 0) FROM dbo.GRADE_COMPONENT gc "
                       "WHERE gc.CourseId = co.CourseId) AS TotalWeight, "
                       "CASE WHEN co.SyllabusXml IS NULL THEN 0 ELSE 1 END AS HasSyllabus, co.Status "
                       "FROM dbo.COURSE co JOIN dbo.PROGRAM pg ON pg.ProgramId = co.ProgramId "
                       "ORDER BY co.ProgramId, co.CourseId"),
        {});
}

Result<QList<LookupItem>> SqlCourseRepository::options() {
    return queryLookup(m_db,
                       QStringLiteral("SELECT CourseId, CourseId + N' - ' + CourseName FROM dbo.COURSE "
                                      "ORDER BY ProgramId, CourseId"),
                       {});
}

Result<Course> SqlCourseRepository::findById(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT CourseId, ProgramId, CourseName, Level, SessionCount, SessionMinutes, "
                           "Tuition, MinPlacementScore, PrerequisiteCourseId, Status FROM dbo.COURSE "
                           "WHERE CourseId = ?"),
            {id}))
        return Result<Course>::failure(errorOf(q));
    if (!q.next())
        return Result<Course>::failure(tr("Course %1 was not found.").arg(id));
    Course c;
    c.id = q.value(0).toString();
    c.programId = q.value(1).toString();
    c.name = q.value(2).toString();
    c.level = q.value(3).toString();
    c.sessionCount = q.value(4).toInt();
    c.sessionMinutes = q.value(5).toInt();
    c.tuition = q.value(6).toLongLong();
    if (!q.value(7).isNull())
        c.minPlacementScore = q.value(7).toDouble();
    c.prerequisiteId = q.value(8).toString();
    c.status = q.value(9).toString();
    return Result<Course>::success(c);
}

VoidResult SqlCourseRepository::add(const Course& c) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Course_Add @CourseId = ?, @ProgramId = ?, @CourseName = ?, @Level = ?, "
                       "@SessionCount = ?, @SessionMinutes = ?, @Tuition = ?, @MinPlacementScore = ?, "
                       "@PrerequisiteCourseId = ?"),
        {c.id, c.programId, c.name, c.level, c.sessionCount, c.sessionMinutes, c.tuition,
         doubleOrNull(c.minPlacementScore.value_or(0), c.minPlacementScore.has_value()),
         stringOrNull(c.prerequisiteId)});
}

VoidResult SqlCourseRepository::update(const Course& c) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Course_Update @CourseId = ?, @ProgramId = ?, @CourseName = ?, "
                       "@Level = ?, @SessionCount = ?, @SessionMinutes = ?, @Tuition = ?, "
                       "@MinPlacementScore = ?, @PrerequisiteCourseId = ?, @Status = ?"),
        {c.id, c.programId, c.name, c.level, c.sessionCount, c.sessionMinutes, c.tuition,
         doubleOrNull(c.minPlacementScore.value_or(0), c.minPlacementScore.has_value()),
         stringOrNull(c.prerequisiteId), c.status});
}

Result<TableData> SqlCourseRepository::syllabus(const QString& courseId) {
    return queryTable(m_db, QStringLiteral("EXEC dbo.usp_Course_Syllabus @CourseId = ?"), {courseId});
}

Result<QString> SqlCourseRepository::syllabusXml(const QString& courseId) {
    // xml is returned as text (CAST), which every ODBC driver can read
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT CAST(SyllabusXml AS NVARCHAR(MAX)) FROM dbo.COURSE WHERE CourseId = ?"),
            {courseId}))
        return Result<QString>::failure(errorOf(q));
    return Result<QString>::success(q.next() ? q.value(0).toString() : QString());
}

VoidResult SqlCourseRepository::setSyllabus(const QString& courseId, const QString& xml) {
    // The text becomes the XML parameter; SQL Server parses it and validates it against xsc_CourseSyllabus
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Course_SetSyllabus @CourseId = ?, @SyllabusXml = ?"),
                    {courseId, stringOrNull(xml)});
}

Result<TableData> SqlCourseRepository::findBySkill(const QString& skill) {
    return queryTable(m_db, QStringLiteral("EXEC dbo.usp_Course_FindBySkill @Skill = ?"), {skill});
}

Result<TableData> SqlCourseRepository::components(const QString& courseId) {
    return queryTable(m_db,
                      QStringLiteral("SELECT ComponentId, ComponentName, Weight FROM dbo.GRADE_COMPONENT "
                                     "WHERE CourseId = ? ORDER BY ComponentId"),
                      {courseId});
}

VoidResult SqlCourseRepository::saveComponent(const GradeComponent& c) {
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_GradeComponent_Save @ComponentId = ?, @CourseId = ?, "
                                   "@ComponentName = ?, @Weight = ?"),
                    {intOrNull(c.id, c.id > 0), c.courseId, c.name, c.weight});
}

VoidResult SqlCourseRepository::removeComponent(int componentId) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_GradeComponent_Delete @ComponentId = ?"),
                    {componentId});
}
