#include "infrastructure/repositories/SqlPlacementRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlPlacementRepository::SqlPlacementRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlPlacementRepository::search(const QString& keyword, const QString& studentId) {
    return queryTable(m_db, QStringLiteral("EXEC dbo.usp_PlacementTest_Search @Keyword = ?, @StudentId = ?"),
                      {stringOrNull(keyword), stringOrNull(studentId)});
}

Result<PlacementResult> SqlPlacementRepository::add(const PlacementTest& test) {
    // The procedure returns the new TestId through its OUTPUT parameter AND one row with the overall score
    // and the course recommended by the trigger; that row is read here (it holds the ID too)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_PlacementTest_Add @StudentId = ?, @ListeningScore = ?, @SpeakingScore = ?, "
        "@ReadingScore = ?, @WritingScore = ?, @TeacherId = ?, @Notes = ?, @TestDate = ?, @TestId = @NewId "
        "OUTPUT;");
    if (!execPrepared(q, m_db, sql,
                      {test.studentId, test.listening, test.speaking, test.reading, test.writing,
                       stringOrNull(test.teacherId), stringOrNull(test.notes), dateOrNull(test.testDate)}))
        return Result<PlacementResult>::failure(errorOf(q));
    if (!q.next())
        return Result<PlacementResult>::failure(tr("The new placement test was not returned."));
    PlacementResult r;
    r.testId = q.value(0).toString();
    r.overallScore = q.value(1).toDouble();
    r.recommendedCourseId = q.value(2).toString();
    r.recommendedCourse = q.value(3).toString();
    return Result<PlacementResult>::success(r);
}

Result<QList<LookupItem>> SqlPlacementRepository::graderOptions() {
    // Only columns of the column-level GRANT on TEACHER for academic staff
    return queryLookup(m_db,
                       QStringLiteral("SELECT TeacherId, TeacherId + N' - ' + FullName FROM dbo.TEACHER "
                                      "WHERE Status <> N'Left' ORDER BY FullName"),
                       {});
}
