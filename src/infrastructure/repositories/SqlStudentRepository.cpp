#include "infrastructure/repositories/SqlStudentRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlStudentRepository::SqlStudentRepository(DatabaseManager& db) : m_db(db) {}

// "@Keyword = ?" names the procedure parameter; each '?' takes the next value of the list, in order
Result<QList<Student>> SqlStudentRepository::search(const StudentFilter& filter) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db, QStringLiteral("EXEC dbo.usp_Student_Search @Keyword = ?, @BranchId = ?, @Status = ?"),
            {stringOrNull(filter.keyword), stringOrNull(filter.branchId), stringOrNull(filter.status)}))
        return Result<QList<Student>>::failure(errorOf(q));

    // Columns: StudentId, FullName, DateOfBirth, Gender, Phone, Email, GuardianName, GuardianPhone,
    //          BranchId, BranchName, RegisteredOn, Status, ActiveClassCount, TotalBalance
    QList<Student> students;
    while (q.next()) {
        Student s;
        s.id = q.value(0).toString();
        s.fullName = q.value(1).toString();
        s.dateOfBirth = q.value(2).toDate();
        s.gender = q.value(3).toString();
        s.phone = q.value(4).toString();
        s.email = q.value(5).toString();
        s.guardianName = q.value(6).toString();
        s.guardianPhone = q.value(7).toString();
        s.branchId = q.value(8).toString();
        s.branchName = q.value(9).toString();
        s.registeredOn = q.value(10).toDate();
        s.status = q.value(11).toString();
        s.activeClassCount = q.value(12).toInt();
        s.outstandingBalance = q.value(13).toLongLong();
        students.append(s);
    }
    return Result<QList<Student>>::success(students);
}

Result<Student> SqlStudentRepository::findById(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Student_Details @StudentId = ?"), {id}))
        return Result<Student>::failure(errorOf(q));
    if (!q.next())
        return Result<Student>::failure(tr("Student %1 was not found.").arg(id));

    // Columns: StudentId, FullName, DateOfBirth, Gender, Phone, Email, Address, Occupation, GuardianName,
    //          GuardianPhone, BranchId, RegisteredOn, Status, Notes
    Student s;
    s.id = q.value(0).toString();
    s.fullName = q.value(1).toString();
    s.dateOfBirth = q.value(2).toDate();
    s.gender = q.value(3).toString();
    s.phone = q.value(4).toString();
    s.email = q.value(5).toString();
    s.address = q.value(6).toString();
    s.occupation = q.value(7).toString();
    s.guardianName = q.value(8).toString();
    s.guardianPhone = q.value(9).toString();
    s.branchId = q.value(10).toString();
    s.registeredOn = q.value(11).toDate();
    s.status = q.value(12).toString();
    s.notes = q.value(13).toString();
    return Result<Student>::success(s);
}

Result<QString> SqlStudentRepository::add(const Student& s) {
    // Procedure with an OUTPUT parameter: call it in a batch that SELECTs the value (most reliable with ODBC)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Student_Add @FullName = ?, @DateOfBirth = ?, @Gender = ?, @Phone = ?, @Email = ?, "
        "@Address = ?, @Occupation = ?, @GuardianName = ?, @GuardianPhone = ?, @BranchId = ?, @Notes = ?, "
        "@StudentId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(q, m_db, sql,
                      {s.fullName, s.dateOfBirth, s.gender, stringOrNull(s.phone), stringOrNull(s.email),
                       stringOrNull(s.address), stringOrNull(s.occupation), stringOrNull(s.guardianName),
                       stringOrNull(s.guardianPhone), s.branchId, stringOrNull(s.notes)}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new student ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlStudentRepository::update(const Student& s) {
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "EXEC dbo.usp_Student_Update @StudentId = ?, @FullName = ?, @DateOfBirth = ?, @Gender = ?, "
        "@Phone = ?, @Email = ?, @Address = ?, @Occupation = ?, @GuardianName = ?, @GuardianPhone = ?, "
        "@BranchId = ?, @Status = ?, @Notes = ?");
    if (!execPrepared(q, m_db, sql,
                      {s.id, s.fullName, s.dateOfBirth, s.gender, stringOrNull(s.phone),
                       stringOrNull(s.email), stringOrNull(s.address), stringOrNull(s.occupation),
                       stringOrNull(s.guardianName), stringOrNull(s.guardianPhone), s.branchId, s.status,
                       stringOrNull(s.notes)}))
        return VoidResult::failure(errorOf(q));
    return VoidResult::success();
}

VoidResult SqlStudentRepository::remove(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Student_Delete @StudentId = ?"), {id}))
        return VoidResult::failure(errorOf(q));
    return VoidResult::success();
}
