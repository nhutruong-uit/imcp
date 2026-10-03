// Unit tests of the domain layer: the validation rules of Student (the same rules as the CHECK constraints
// of table STUDENT, checked again in the application for fast feedback) and the code <-> enum mappings of
// Role and Language. Plain functions: no database and no fakes are needed.
// Run only this suite:
//   ctest --preset macos-debug -R tst_domain --output-on-failure
#include "domain/entities/Language.h"
#include "domain/entities/Role.h"
#include "domain/entities/Student.h"

#include <QtTest>

class TestDomain : public QObject {
    Q_OBJECT

private:
    // A student that breaks no rule; each test below changes one field to break exactly one rule
    static Student validStudent() {
        Student s;
        s.fullName = QStringLiteral("Nguyễn Văn An");
        s.dateOfBirth = QDate(2000, 5, 10);
        s.gender = QStringLiteral("Male");
        s.phone = QStringLiteral("0901234567");
        s.branchId = QStringLiteral("BR01");
        return s;
    }

private slots:
    void validStudent_hasNoErrors() { QVERIFY(validStudent().validate(QDate(2026, 10, 1)).isEmpty()); }

    // age() counts one year less until the birthday of that year has come
    void age_beforeBirthday() {
        Student s;
        s.dateOfBirth = QDate(2008, 12, 31);
        QCOMPARE(s.age(QDate(2026, 10, 1)), 17);
        QCOMPARE(s.age(QDate(2026, 12, 31)), 18);
    }

    // Same rule as CK_STUDENT_Guardian: under 18 needs a guardian name and phone
    void under18_requiresGuardian() {
        Student s = validStudent();
        s.dateOfBirth = QDate(2015, 1, 1);
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
        s.guardianName = QStringLiteral("Nguyễn Văn Hòa");
        s.guardianPhone = QStringLiteral("0912000001");
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    // Same rule as CK_STUDENT_Phone: 9-11 digits and nothing else
    void phone_digitsOnly() {
        Student s = validStudent();
        s.phone = QStringLiteral("09-123");
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    // Close to CK_STUDENT_Email: something@something.something
    void email_format() {
        Student s = validStudent();
        s.email = QStringLiteral("not-an-email");
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
        s.email = QStringLiteral("an.nv@gmail.com");
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    // Same rule as CK_STUDENT_Contact: the phone of the student or of the guardian
    void atLeastOneContactNumber() {
        Student s = validStudent();
        s.phone.clear();
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    // A text longer than its column would be cut silently by the procedure parameters, so it is refused
    void validate_textLongerThanColumn_isRejected() {
        Student s = validStudent();
        s.address = QString(StudentLimits::address, QLatin1Char('a'));
        s.notes = QString(StudentLimits::notes, QLatin1Char('n'));
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty()); // exactly the column size is fine
        s.address += QLatin1Char('a');
        s.notes += QLatin1Char('n');
        s.occupation = QString(StudentLimits::occupation + 1, QLatin1Char('o'));
        s.guardianName = QString(StudentLimits::guardianName + 1, QLatin1Char('g'));
        QCOMPARE(s.validate(QDate(2026, 10, 1)).size(), 4);
    }

    // Email is a VARCHAR column: a letter with diacritics would be stored as "?", so it is refused
    void validate_emailWithDiacritics_isRejected() {
        Student s = validStudent();
        s.email = QStringLiteral("an.nguyễn@gmail.com");
        QCOMPARE(s.validate(QDate(2026, 10, 1)).size(), 1);
        s.email = QStringLiteral("an@nv@gmail.com");
        QCOMPARE(s.validate(QDate(2026, 10, 1)).size(), 1);
    }

    // Role codes stored in ACCOUNT.Role <-> Role; case-insensitive, an unknown code gives Role::Unknown
    void role_codeMapping() {
        QCOMPARE(roleFromCode(QStringLiteral("MANAGER")), Role::Manager);
        QCOMPARE(roleFromCode(QStringLiteral("teacher")), Role::Teacher);
        QCOMPARE(roleFromCode(QStringLiteral("ACADEMIC_STAFF")), Role::AcademicStaff);
        QCOMPARE(roleFromCode(QStringLiteral("abc")), Role::Unknown);
        QCOMPARE(roleCode(Role::Accountant), QStringLiteral("ACCOUNTANT"));
    }

    // Language codes saved in the settings (vi / en); an unsupported code falls back to Vietnamese
    void language_codeMapping() {
        QCOMPARE(languageCode(Language::Vietnamese), QStringLiteral("vi"));
        QCOMPARE(languageCode(Language::English), QStringLiteral("en"));
        QCOMPARE(languageFromCode(QStringLiteral("en")), Language::English);
        QCOMPARE(languageFromCode(QStringLiteral("en_GB")), Language::English);
        QCOMPARE(languageFromCode(QStringLiteral("fr")), Language::Vietnamese); // unsupported => default
        QCOMPARE(supportedLanguages().first(), Language::Vietnamese);
    }
};

QTEST_APPLESS_MAIN(TestDomain)
#include "tst_domain.moc"
