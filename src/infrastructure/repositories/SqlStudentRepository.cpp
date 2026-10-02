#include "infrastructure/repositories/SqlStudentRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlStudentRepository::SqlStudentRepository(DatabaseManager& db) : m_db(db) {}

Result<QList<Student>> SqlStudentRepository::search(const StudentFilter& filter) {
    QSqlQuery q = makeQuery(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_Student_Search @Keyword = ?, @BranchId = ?, @Status = ?"));
    q.addBindValue(stringOrNull(filter.keyword));
    q.addBindValue(stringOrNull(filter.branchId));
    q.addBindValue(stringOrNull(filter.status));
    if (!q.exec())
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
    q.prepare(QStringLiteral("EXEC dbo.usp_Student_Details @StudentId = ?"));
    q.addBindValue(id);
    if (!q.exec())
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
    q.prepare(QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Student_Add @FullName = ?, @DateOfBirth = ?, @Gender = ?, @Phone = ?, @Email = ?, "
        "@Address = ?, @Occupation = ?, @GuardianName = ?, @GuardianPhone = ?, @BranchId = ?, @Notes = ?, "
        "@StudentId = @NewId OUTPUT; SELECT @NewId;"));
    q.addBindValue(s.fullName);
    q.addBindValue(s.dateOfBirth);
    q.addBindValue(s.gender);
    q.addBindValue(stringOrNull(s.phone));
    q.addBindValue(stringOrNull(s.email));
    q.addBindValue(stringOrNull(s.address));
    q.addBindValue(stringOrNull(s.occupation));
    q.addBindValue(stringOrNull(s.guardianName));
    q.addBindValue(stringOrNull(s.guardianPhone));
    q.addBindValue(s.branchId);
    q.addBindValue(stringOrNull(s.notes));
    if (!q.exec())
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new student ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlStudentRepository::update(const Student& s) {
    QSqlQuery q = makeQuery(m_db.db());
    q.prepare(QStringLiteral(
        "EXEC dbo.usp_Student_Update @StudentId = ?, @FullName = ?, @DateOfBirth = ?, @Gender = ?, "
        "@Phone = ?, @Email = ?, @Address = ?, @Occupation = ?, @GuardianName = ?, @GuardianPhone = ?, "
        "@BranchId = ?, @Status = ?, @Notes = ?"));
    q.addBindValue(s.id);
    q.addBindValue(s.fullName);
    q.addBindValue(s.dateOfBirth);
    q.addBindValue(s.gender);
    q.addBindValue(stringOrNull(s.phone));
    q.addBindValue(stringOrNull(s.email));
    q.addBindValue(stringOrNull(s.address));
    q.addBindValue(stringOrNull(s.occupation));
    q.addBindValue(stringOrNull(s.guardianName));
    q.addBindValue(stringOrNull(s.guardianPhone));
    q.addBindValue(s.branchId);
    q.addBindValue(s.status);
    q.addBindValue(stringOrNull(s.notes));
    if (!q.exec())
        return VoidResult::failure(errorOf(q));
    return VoidResult::success();
}

VoidResult SqlStudentRepository::remove(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_Student_Delete @StudentId = ?"));
    q.addBindValue(id);
    if (!q.exec())
        return VoidResult::failure(errorOf(q));
    return VoidResult::success();
}
