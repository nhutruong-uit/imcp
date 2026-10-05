#include "application/services/StaffService.h"

#include "domain/common/Validation.h"

StaffService::StaffService(IStaffRepository& repository) : m_repository(repository) {}

Result<TableData> StaffService::employees() {
    return m_repository.employees();
}

Result<Employee> StaffService::employee(const QString& id) {
    if (id.isEmpty())
        return Result<Employee>::failure(tr("No employee is selected."));
    return m_repository.employee(id);
}

Result<QString> StaffService::saveEmployee(const Employee& e, const QDate& today) {
    Employee c = e;
    c.fullName = c.fullName.simplified();
    c.phone = c.phone.trimmed();
    c.email = c.email.trimmed().toLower();
    c.address = c.address.trimmed();
    const QStringList errors = c.validate(today);
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    if (c.id.isEmpty())
        return m_repository.addEmployee(c);
    const VoidResult updated = m_repository.updateEmployee(c);
    return updated.ok() ? Result<QString>::success(c.id) : Result<QString>::failure(updated.error());
}

Result<TableData> StaffService::teachers() {
    return m_repository.teachers();
}

Result<Teacher> StaffService::teacher(const QString& id) {
    if (id.isEmpty())
        return Result<Teacher>::failure(tr("No teacher is selected."));
    return m_repository.teacher(id);
}

Result<QString> StaffService::saveTeacher(const Teacher& t, const QDate& today) {
    Teacher c = t;
    c.fullName = c.fullName.simplified();
    c.nationality = c.nationality.simplified();
    c.phone = c.phone.trimmed();
    c.email = c.email.trimmed().toLower();
    // Without the <?xml ... encoding=...?> declaration: SQL Server cannot store Unicode text that names an
    // encoding in an XML column (error 9402), the same as the syllabus and the student import
    c.profileXml = Validation::withoutXmlDeclaration(c.profileXml);
    const QStringList errors = c.validate(today);
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    if (c.id.isEmpty())
        return m_repository.addTeacher(c);
    const VoidResult updated = m_repository.updateTeacher(c);
    return updated.ok() ? Result<QString>::success(c.id) : Result<QString>::failure(updated.error());
}

Result<TableData> StaffService::findTeachersByCertificate(const QString& type, double minScore) {
    if (type.trimmed().isEmpty())
        return Result<TableData>::failure(tr("Please enter a certificate type, for example IELTS."));
    return m_repository.findTeachersByCertificate(type.trimmed(), minScore);
}
