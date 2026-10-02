#include "domain/entities/Language.h"
#include "domain/entities/Role.h"
#include "domain/entities/Student.h"

#include <QtTest>

class TestDomain : public QObject {
    Q_OBJECT

private:
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

    void age_beforeBirthday() {
        Student s;
        s.dateOfBirth = QDate(2008, 12, 31);
        QCOMPARE(s.age(QDate(2026, 10, 1)), 17);
        QCOMPARE(s.age(QDate(2026, 12, 31)), 18);
    }

    void under18_requiresGuardian() {
        Student s = validStudent();
        s.dateOfBirth = QDate(2015, 1, 1);
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
        s.guardianName = QStringLiteral("Nguyễn Văn Hòa");
        s.guardianPhone = QStringLiteral("0912000001");
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    void phone_digitsOnly() {
        Student s = validStudent();
        s.phone = QStringLiteral("09-123");
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    void email_format() {
        Student s = validStudent();
        s.email = QStringLiteral("not-an-email");
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
        s.email = QStringLiteral("an.nv@gmail.com");
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    void atLeastOneContactNumber() {
        Student s = validStudent();
        s.phone.clear();
        QVERIFY(!s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    void role_codeMapping() {
        QCOMPARE(roleFromCode(QStringLiteral("MANAGER")), Role::Manager);
        QCOMPARE(roleFromCode(QStringLiteral("teacher")), Role::Teacher);
        QCOMPARE(roleFromCode(QStringLiteral("ACADEMIC_STAFF")), Role::AcademicStaff);
        QCOMPARE(roleFromCode(QStringLiteral("abc")), Role::Unknown);
        QCOMPARE(roleCode(Role::Accountant), QStringLiteral("ACCOUNTANT"));
    }

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
