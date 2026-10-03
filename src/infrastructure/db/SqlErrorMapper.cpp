#include "infrastructure/db/SqlErrorMapper.h"

#include "infrastructure/db/DbMessages.h"

#include <QHash>
#include <QRegularExpression>
#include <QStringList>

QString SqlErrorMapper::cleanMessage(const QString& rawMessage) {
    // One error may hold several diagnostic records; keep the first one that has content
    static const QRegularExpression prefix(QStringLiteral("^(\\s*\\[[^\\]]*\\])+\\s*"));
    static const QRegularExpression qodbcSuffix(QStringLiteral("\\s*QODBC[^:]*:.*$"));
    // QODBC (Qt 6) appends the SQLSTATE to the message: "The current password is incorrect., 37000"
    static const QRegularExpression sqlStateSuffix(
        QStringLiteral("\\s*,\\s*[0-9A-Z]{5}(;[0-9A-Z]{5})*\\s*$"));
    const QStringList lines =
        rawMessage.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (QString line : lines) {
        line.remove(prefix);
        line.remove(qodbcSuffix);
        line.remove(sqlStateSuffix);
        line = line.trimmed();
        if (!line.isEmpty() && !line.startsWith(QLatin1String("The statement has been terminated")))
            return line;
    }
    return rawMessage.trimmed();
}

QString SqlErrorMapper::constraintMessage(const QString& constraintName) {
    // Store the source text only (QT_TRANSLATE_NOOP marks it for lupdate) and translate on lookup:
    // a static table of already translated text would ignore later language changes.
    static const QHash<QString, const char*> messages = {
        {QStringLiteral("CK_STUDENT_Guardian"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Students under 18 need guardian information.")},
        {QStringLiteral("CK_STUDENT_Contact"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "At least one contact phone number is required.")},
        {QStringLiteral("CK_STUDENT_Phone"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Phone numbers contain 9-11 digits only.")},
        {QStringLiteral("CK_STUDENT_Email"), QT_TRANSLATE_NOOP("SqlErrorMapper", "Invalid email address.")},
        {QStringLiteral("CK_STUDENT_DateOfBirth"),
         QT_TRANSLATE_NOOP("SqlErrorMapper",
                           "Invalid date of birth (students must be at least 4 years old).")},
        {QStringLiteral("CK_ENROLLMENT_AmountPaid"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "The amount paid exceeds the tuition due.")},
        {QStringLiteral("CK_GRADE_Score"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Grades must be between 0 and 10.")},
        {QStringLiteral("UQ_ENROLLMENT_StudentId_ClassId"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "The student is already enrolled in this class.")},
        {QStringLiteral("UX_STUDENT_Phone"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This phone number is already used by another student.")},
        {QStringLiteral("UX_STUDENT_Email"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This email is already used by another student.")},
        {QStringLiteral("FK_ENROLLMENT_STUDENT"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "The student has enrollment records and cannot be deleted.")},
        // Catalog and staff forms (the domain validation catches most of these before the database)
        {QStringLiteral("UQ_BRANCH_BranchName"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Another branch already has this name.")},
        {QStringLiteral("UQ_ROOM_BranchId_RoomName"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This branch already has a room with this name.")},
        {QStringLiteral("UQ_PROGRAM_ProgramName"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Another program already has this name.")},
        {QStringLiteral("UQ_COURSE_CourseName"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Another course already has this name.")},
        {QStringLiteral("UQ_GRADE_COMPONENT_CourseId_ComponentName"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "The course already has a grade component with this name.")},
        {QStringLiteral("UQ_EMPLOYEE_Phone"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This phone number is already used by another employee.")},
        {QStringLiteral("UX_EMPLOYEE_Email"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This email is already used by another employee.")},
        {QStringLiteral("UQ_TEACHER_Phone"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This phone number is already used by another teacher.")},
        {QStringLiteral("UQ_TEACHER_Email"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This email is already used by another teacher.")},
        {QStringLiteral("CK_EMPLOYEE_Age"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Staff must be at least 18 years old on the hire date.")},
        {QStringLiteral("CK_TEACHER_Age"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "Staff must be at least 18 years old on the hire date.")},
        {QStringLiteral("CK_TEACHER_Native"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "A native-speaker teacher cannot have Vietnamese nationality.")},
        {QStringLiteral("CK_COURSE_Prerequisite"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "A course cannot be its own prerequisite.")},
        {QStringLiteral("CK_PROMOTION_DiscountValue"),
         QT_TRANSLATE_NOOP("SqlErrorMapper",
                           "The discount must be positive, and at most 50 for a percentage.")},
        {QStringLiteral("CK_PROMOTION_Dates"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "The end date cannot be before the start date.")},
        {QStringLiteral("CK_CLASS_SCHEDULE_Time"),
         QT_TRANSLATE_NOOP("SqlErrorMapper",
                           "A time slot must end after it starts and stay between 07:00 and 22:00.")},
        {QStringLiteral("UX_ACCOUNT_EmployeeId"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This person already has an account.")},
        {QStringLiteral("UX_ACCOUNT_TeacherId"),
         QT_TRANSLATE_NOOP("SqlErrorMapper", "This person already has an account.")},
    };
    if (const char* source = messages.value(constraintName, nullptr))
        return tr(source);
    return tr("The data violates an integrity constraint: %1").arg(constraintName);
}

// Checks run from the most specific to the most general. SQL Server error numbers used below:
//   18456 login failed, 4060 cannot open the database, 229/230/262/297 permission denied,
//   9400-9499 XML parsing, 2627 duplicate key (PRIMARY KEY/UNIQUE), 2601 duplicate key in a unique index,
//   547 CHECK/FOREIGN KEY
// Anything else is a business message of THROW/RAISERROR (English), translated by DbMessages.
QString SqlErrorMapper::message(const QSqlError& error) {
    if (!error.isValid())
        return QString();

    const QString raw = error.databaseText().isEmpty() ? error.text() : error.databaseText();
    const QString cleaned = cleanMessage(raw);
    const QStringList codes = error.nativeErrorCode().split(QLatin1Char(';'), Qt::SkipEmptyParts);
    auto hasCode = [&codes](const char* code) { return codes.contains(QLatin1String(code)); };

    if (hasCode("18456") || raw.contains(QLatin1String("Login failed"), Qt::CaseInsensitive))
        return tr("Wrong username or password, or the account is locked.");
    if (hasCode("4060") || raw.contains(QLatin1String("Cannot open database"), Qt::CaseInsensitive))
        return tr("Cannot open the database. Check the database name in the server settings.");
    if (raw.contains(QLatin1String("TCP Provider"), Qt::CaseInsensitive) ||
        raw.contains(QLatin1String("Login timeout expired"), Qt::CaseInsensitive) ||
        raw.contains(QLatin1String("server was not found"), Qt::CaseInsensitive) ||
        raw.contains(QLatin1String("Named Pipes"), Qt::CaseInsensitive) ||
        raw.contains(QLatin1String("Communication link failure"), Qt::CaseInsensitive))
        return tr("Cannot connect to SQL Server.\n"
                  "Check the server address, the port (1433 by default) and that the SQL Server service is "
                  "running.");
    if (raw.contains(QLatin1String("certificate"), Qt::CaseInsensitive) ||
        raw.contains(QLatin1String("SSL Provider"), Qt::CaseInsensitive))
        return tr("The server's security certificate was rejected. Turn on \"Trust server certificate\" "
                  "in the server settings.");
    if (hasCode("229") || hasCode("230") || hasCode("262") || hasCode("297") ||
        raw.contains(QLatin1String("permission was denied"), Qt::CaseInsensitive))
        return tr("You do not have permission to perform this action (denied by SQL Server).");

    // 9400-9499: XML parsing (text that is not well-formed XML, e.g. a syllabus or a teacher profile)
    for (const QString& code : codes)
        if (code.size() == 4 && code.startsWith(QLatin1String("94")))
            return tr("The text is not well-formed XML: %1").arg(cleaned);

    if (hasCode("2627") || hasCode("2601") || hasCode("547") || raw.contains(QLatin1String("constraint"))) {
        static const QRegularExpression constraintName(
            QStringLiteral("(?:constraint|index)\\s+['\"]([A-Za-z0-9_]+)['\"]"),
            QRegularExpression::CaseInsensitiveOption);
        const auto match = constraintName.match(raw);
        if (match.hasMatch())
            return constraintMessage(match.captured(1));
    }

    // Business errors from THROW/RAISERROR: written in English by the database, shown in the UI language
    return DbMessages::translate(cleaned);
}
