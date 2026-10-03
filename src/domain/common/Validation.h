#pragma once

#include <QDate>
#include <QString>

// Format checks shared by the entities (Student, Employee, Teacher, Branch...). Each one mirrors a CHECK
// constraint of database/01_tables.sql, so a form can show a clear message before the database rejects the
// row.
namespace Validation {
// 9-11 digits, like CK_STUDENT_Phone / CK_EMPLOYEE_Phone (NOT LIKE '%[^0-9]%' AND LEN BETWEEN 9 AND 11)
bool isPhone(const QString& phone);
// something@something.something, close to CK_..._Email (LIKE '%_@_%._%'); ASCII only, because the email
// columns are VARCHAR (a letter such as "ê" would be stored as "?")
bool isEmail(const QString& email);
// A code chosen by the user (BR01, D1-101, IE-FND): letters without diacritics, digits, dash and underscore,
// at most maxLength characters - the rule of the catalog procedures (THROW 50092)
bool isCode(const QString& code, int maxLength = 10);
// XML text without its leading <?xml ...?> declaration: SQL Server cannot store a declaration that names an
// encoding (encoding="utf-8") from Unicode text, and the declaration carries nothing the database needs
QString withoutXmlDeclaration(const QString& xml);
// Full years between the two dates, one less when the birthday has not come yet that year (0 if a date is
// missing)
int age(const QDate& dateOfBirth, const QDate& asOf);
} // namespace Validation
