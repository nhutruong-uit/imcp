#include "application/services/StudentService.h"

#include "domain/common/Validation.h"

namespace {
// Normalizes user input: trims extra whitespace, lower-cases the email.
// simplified() also turns inner runs of spaces into one ("Nguyen   An" -> "Nguyen An"), so the same name
// typed twice is stored the same way, and phone/email reach the uniqueness checks without stray spaces.
Student normalized(Student s) {
    s.fullName = s.fullName.simplified();
    s.phone = s.phone.trimmed();
    s.email = s.email.trimmed().toLower();
    s.address = s.address.trimmed();
    s.occupation = s.occupation.trimmed();
    s.guardianName = s.guardianName.simplified();
    s.guardianPhone = s.guardianPhone.trimmed();
    s.notes = s.notes.trimmed();
    return s;
}
} // namespace

StudentService::StudentService(IStudentRepository& repository, ICatalogRepository& catalog)
    : m_repository(repository), m_catalog(catalog) {}

Result<QList<Student>> StudentService::search(const StudentFilter& filter) {
    StudentFilter f = filter;
    f.keyword = f.keyword.trimmed();
    return m_repository.search(f);
}

Result<Student> StudentService::details(const QString& id) {
    if (id.isEmpty())
        return Result<Student>::failure(tr("No student is selected."));
    return m_repository.findById(id);
}

// add/update: normalize -> validate (domain rules) -> only then call the repository (the database checks the
// same rules again). All errors are joined with line breaks so the form shows them together.
Result<QString> StudentService::add(const Student& student, const QDate& today) {
    const Student s = normalized(student);
    const QStringList errors = s.validate(today);
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    return m_repository.add(s);
}

VoidResult StudentService::update(const Student& student, const QDate& today) {
    if (student.id.isEmpty())
        return VoidResult::failure(tr("The student ID is missing."));
    const Student s = normalized(student);
    const QStringList errors = s.validate(today);
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.update(s);
}

VoidResult StudentService::remove(const QString& id) {
    if (id.isEmpty())
        return VoidResult::failure(tr("No student is selected."));
    return m_repository.remove(id);
}

Result<QList<Branch>> StudentService::branches() {
    return m_catalog.branches();
}

Result<QString> StudentService::exportXml(const QString& branchId) {
    return m_repository.exportXml(branchId);
}

Result<ImportResult> StudentService::importXml(const QString& xml, const QString& branchId) {
    if (branchId.isEmpty())
        return Result<ImportResult>::failure(tr("Please choose the branch of the imported students."));
    if (!xml.contains(QLatin1String("<Students")))
        return Result<ImportResult>::failure(
            tr("The file is not a student export: it has no <Students> element."));
    return m_repository.importXml(Validation::withoutXmlDeclaration(xml), branchId);
}
