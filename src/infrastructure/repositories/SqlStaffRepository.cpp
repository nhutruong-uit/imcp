#include "infrastructure/repositories/SqlStaffRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlStaffRepository::SqlStaffRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlStaffRepository::employees() {
    return queryTable(
        m_db,
        QStringLiteral("SELECT em.EmployeeId, em.FullName, em.Gender, em.DateOfBirth, em.Phone, em.Email, "
                       "em.Position, br.BranchName, em.HireDate, em.BaseSalary, ac.Username, em.Status "
                       "FROM dbo.EMPLOYEE em JOIN dbo.BRANCH br ON br.BranchId = em.BranchId "
                       "LEFT JOIN dbo.ACCOUNT ac ON ac.EmployeeId = em.EmployeeId "
                       "ORDER BY em.EmployeeId"),
        {});
}

Result<Employee> SqlStaffRepository::employee(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT EmployeeId, FullName, DateOfBirth, Gender, Phone, Email, Address, "
                           "Position, BranchId, HireDate, BaseSalary, Status FROM dbo.EMPLOYEE "
                           "WHERE EmployeeId = ?"),
            {id}))
        return Result<Employee>::failure(errorOf(q));
    if (!q.next())
        return Result<Employee>::failure(tr("Employee %1 was not found.").arg(id));
    Employee e;
    e.id = field(q, "EmployeeId").toString();
    e.fullName = field(q, "FullName").toString();
    e.dateOfBirth = field(q, "DateOfBirth").toDate();
    e.gender = field(q, "Gender").toString();
    e.phone = field(q, "Phone").toString();
    e.email = field(q, "Email").toString();
    e.address = field(q, "Address").toString();
    e.position = field(q, "Position").toString();
    e.branchId = field(q, "BranchId").toString();
    e.hireDate = field(q, "HireDate").toDate();
    e.baseSalary = field(q, "BaseSalary").toLongLong();
    e.status = field(q, "Status").toString();
    return Result<Employee>::success(e);
}

Result<QString> SqlStaffRepository::addEmployee(const Employee& e) {
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Employee_Add @FullName = ?, @DateOfBirth = ?, @Gender = ?, @Phone = ?, @Email = ?, "
        "@Address = ?, @Position = ?, @BranchId = ?, @HireDate = ?, @BaseSalary = ?, @EmployeeId = @NewId "
        "OUTPUT; "
        "SELECT @NewId;");
    if (!execPrepared(q, m_db, sql,
                      {e.fullName, e.dateOfBirth, e.gender, e.phone, stringOrNull(e.email),
                       stringOrNull(e.address), e.position, e.branchId, dateOrNull(e.hireDate),
                       e.baseSalary}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new employee ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlStaffRepository::updateEmployee(const Employee& e) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Employee_Update @EmployeeId = ?, @FullName = ?, @DateOfBirth = ?, "
                       "@Gender = ?, @Phone = ?, @Email = ?, @Address = ?, @Position = ?, @BranchId = ?, "
                       "@HireDate = ?, @BaseSalary = ?, @Status = ?"),
        {e.id, e.fullName, e.dateOfBirth, e.gender, e.phone, stringOrNull(e.email), stringOrNull(e.address),
         e.position, e.branchId, e.hireDate, e.baseSalary, e.status});
}

Result<TableData> SqlStaffRepository::teachers() {
    // Only columns of the column-level GRANT on TEACHER for academic staff (no phone, email or hourly rate);
    // the number of active classes comes from vw_ClassDetails, which academic staff may read
    return queryTable(
        m_db,
        QStringLiteral("SELECT te.TeacherId, te.FullName, te.TeacherType, te.Nationality, te.Degree, "
                       "br.BranchName, (SELECT COUNT(*) FROM dbo.vw_ClassDetails cd "
                       "WHERE cd.TeacherId = te.TeacherId AND cd.Status IN (N'Enrolling', "
                       "N'In progress')) AS ActiveClassCount, te.Status FROM dbo.TEACHER te "
                       "JOIN dbo.BRANCH br ON br.BranchId = te.BranchId ORDER BY te.TeacherId"),
        {});
}

Result<Teacher> SqlStaffRepository::teacher(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT TeacherId, FullName, DateOfBirth, Gender, Nationality, Phone, Email, "
                           "Degree, TeacherType, HourlyRate, BranchId, HireDate, "
                           "CAST(ProfileXml AS NVARCHAR(MAX)) AS ProfileXml, Status FROM dbo.TEACHER WHERE "
                           "TeacherId = ?"),
            {id}))
        return Result<Teacher>::failure(errorOf(q));
    if (!q.next())
        return Result<Teacher>::failure(tr("Teacher %1 was not found.").arg(id));
    Teacher t;
    t.id = field(q, "TeacherId").toString();
    t.fullName = field(q, "FullName").toString();
    t.dateOfBirth = field(q, "DateOfBirth").toDate();
    t.gender = field(q, "Gender").toString();
    t.nationality = field(q, "Nationality").toString();
    t.phone = field(q, "Phone").toString();
    t.email = field(q, "Email").toString();
    t.degree = field(q, "Degree").toString();
    t.teacherType = field(q, "TeacherType").toString();
    t.hourlyRate = field(q, "HourlyRate").toLongLong();
    t.branchId = field(q, "BranchId").toString();
    t.hireDate = field(q, "HireDate").toDate();
    t.profileXml = field(q, "NULL").toString();
    t.status = field(q, "Status").toString();
    return Result<Teacher>::success(t);
}

Result<QString> SqlStaffRepository::addTeacher(const Teacher& t) {
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral("SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
                                       "EXEC dbo.usp_Teacher_Add @FullName = ?, @DateOfBirth = ?, @Gender = "
                                       "?, @Nationality = ?, @Phone = ?, "
                                       "@Email = ?, @Degree = ?, @TeacherType = ?, @HourlyRate = ?, "
                                       "@BranchId = ?, @HireDate = ?, @ProfileXml = ?, "
                                       "@TeacherId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(q, m_db, sql,
                      {t.fullName, t.dateOfBirth, t.gender, t.nationality, t.phone, t.email, t.degree,
                       t.teacherType, t.hourlyRate, t.branchId, dateOrNull(t.hireDate),
                       stringOrNull(t.profileXml)}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new teacher ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlStaffRepository::updateTeacher(const Teacher& t) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Teacher_Update @TeacherId = ?, @FullName = ?, @DateOfBirth = ?, "
                       "@Gender = ?, @Nationality = ?, @Phone = ?, @Email = ?, @Degree = ?, "
                       "@TeacherType = ?, @HourlyRate = ?, @BranchId = ?, @HireDate = ?, @ProfileXml = ?, "
                       "@Status = ?"),
        {t.id, t.fullName, t.dateOfBirth, t.gender, t.nationality, t.phone, t.email, t.degree, t.teacherType,
         t.hourlyRate, t.branchId, t.hireDate, stringOrNull(t.profileXml), t.status});
}

Result<TableData> SqlStaffRepository::findTeachersByCertificate(const QString& type, double minScore) {
    // The procedure returns the specialties as an XML fragment; the batch keeps its rows in a table variable
    // and turns that fragment into "IELTS, Speaking" text with an XQuery FLWOR loop (as usp_Course_Syllabus
    // does)
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @Found TABLE (TeacherId VARCHAR(10), FullName NVARCHAR(100), "
        "TeacherType NVARCHAR(20), Score DECIMAL(4,1), YearsOfExperience INT, Specialties XML); "
        "INSERT INTO @Found EXEC dbo.usp_Teacher_FindByCertificate @CertificateType = ?, @MinScore = ?; "
        "SELECT TeacherId, FullName, TeacherType, Score, YearsOfExperience, "
        "STUFF(Specialties.query('for $s in /Specialty return concat(\", \", string($s))').value('.', "
        "'NVARCHAR(400)'), 1, 2, '') AS Specialties FROM @Found ORDER BY Score DESC;");
    return queryTable(m_db, sql, {type, minScore});
}
