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
        s.id = field(q, "StudentId").toString();
        s.fullName = field(q, "FullName").toString();
        s.dateOfBirth = field(q, "DateOfBirth").toDate();
        s.gender = field(q, "Gender").toString();
        s.phone = field(q, "Phone").toString();
        s.email = field(q, "Email").toString();
        s.guardianName = field(q, "GuardianName").toString();
        s.guardianPhone = field(q, "GuardianPhone").toString();
        s.branchId = field(q, "BranchId").toString();
        s.branchName = field(q, "BranchName").toString();
        s.registeredOn = field(q, "RegisteredOn").toDate();
        s.status = field(q, "Status").toString();
        s.activeClassCount = field(q, "ActiveClassCount").toInt();
        s.outstandingBalance = field(q, "TotalBalance").toLongLong();
        students.append(s);
    }
    return afterRead(q, students);
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
    s.id = field(q, "StudentId").toString();
    s.fullName = field(q, "FullName").toString();
    s.dateOfBirth = field(q, "DateOfBirth").toDate();
    s.gender = field(q, "Gender").toString();
    s.phone = field(q, "Phone").toString();
    s.email = field(q, "Email").toString();
    s.address = field(q, "Address").toString();
    s.occupation = field(q, "Occupation").toString();
    s.guardianName = field(q, "GuardianName").toString();
    s.guardianPhone = field(q, "GuardianPhone").toString();
    s.branchId = field(q, "BranchId").toString();
    s.registeredOn = field(q, "RegisteredOn").toDate();
    s.status = field(q, "Status").toString();
    s.notes = field(q, "Notes").toString();
    return Result<Student>::success(s);
}

Result<QString> SqlStudentRepository::add(const Student& s) {
    // Procedure with an OUTPUT parameter: call it in a batch that SELECTs the value (most reliable with ODBC)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Student_Add @FullName = ?, @DateOfBirth = ?, @Gender = ?, @Phone = ?, @Email = ?, "
        "@Address = ?, @Occupation = ?, @GuardianName = ?, @GuardianPhone = ?, @BranchId = ?, @Notes = ?, "
        "@RegisteredOn = ?, @StudentId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(q, m_db, sql,
                      {s.fullName, s.dateOfBirth, s.gender, stringOrNull(s.phone), stringOrNull(s.email),
                       stringOrNull(s.address), stringOrNull(s.occupation), stringOrNull(s.guardianName),
                       stringOrNull(s.guardianPhone), s.branchId, stringOrNull(s.notes),
                       dateOrNull(s.registeredOn)}))
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

Result<QString> SqlStudentRepository::exportXml(const QString& branchId) {
    // The procedure returns one value of type xml; the batch keeps it in a table variable and returns it as
    // text, which every ODBC driver can read
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral("SET NOCOUNT ON; DECLARE @Export TABLE (XmlData XML); "
                                       "INSERT INTO @Export EXEC dbo.usp_Student_ExportXml @BranchId = ?; "
                                       "SELECT CAST(XmlData AS NVARCHAR(MAX)) FROM @Export;");
    if (!execPrepared(q, m_db, sql, {stringOrNull(branchId)}))
        return Result<QString>::failure(errorOf(q));
    return Result<QString>::success(q.next() ? q.value(0).toString() : QString());
}

Result<ImportResult> SqlStudentRepository::importXml(const QString& xml, const QString& branchId) {
    // The text becomes the XML parameter @Data; the procedure shreds it with .nodes() and returns
    // ImportedRows, SkippedRows
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Student_ImportXml @Data = ?, @BranchId = ?"),
                      {xml, branchId}))
        return Result<ImportResult>::failure(errorOf(q));
    ImportResult r;
    if (q.next()) {
        r.imported = field(q, "ImportedRows").toInt();
        r.skipped = field(q, "SkippedRows").toInt();
    }
    return Result<ImportResult>::success(r);
}
