// Unit tests of the domain layer: the validation rules of Student, ClassInfo, ScheduleSlot, the catalogs, the
// staff and the accounts (the same rules as the CHECK constraints and procedures, checked again in the
// application for fast feedback), the grade book pivot and final grade, and the code <-> enum mappings of
// Role and Language. Plain functions: no database and no fakes are needed. Run only this suite:
//   ctest --preset macos-debug -R tst_domain --output-on-failure
#include "domain/common/Validation.h"
#include "domain/entities/Catalog.h"
#include "domain/entities/ClassInfo.h"
#include "domain/entities/GradeBook.h"
#include "domain/entities/Language.h"
#include "domain/entities/NewAccount.h"
#include "domain/entities/Receipt.h"
#include "domain/entities/Role.h"
#include "domain/entities/Session.h"
#include "domain/entities/Staff.h"
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
        s.email = QStringLiteral("an.nv@example.com");
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

    // A student cannot be registered in the future (usp_Student_Add takes a registration date since this
    // change)
    void validate_registrationInFuture_isRejected() {
        Student s = validStudent();
        s.registeredOn = QDate(2026, 10, 2);
        QCOMPARE(s.validate(QDate(2026, 10, 1)).size(), 1);
        s.registeredOn = QDate(2026, 9, 1);
        QVERIFY(s.validate(QDate(2026, 10, 1)).isEmpty());
    }

    // Codes chosen by the user: letters, digits, dash and underscore, at most 10 characters (THROW 50092)
    void validation_code() {
        QVERIFY(Validation::isCode(QStringLiteral("D1-101")));
        QVERIFY(Validation::isCode(QStringLiteral("PR_OPEN")));
        QVERIFY(!Validation::isCode(QStringLiteral("D1 101")));
        QVERIFY(!Validation::isCode(QStringLiteral("CHI-NHÁNH")));
        QVERIFY(!Validation::isCode(QStringLiteral("ABCDEFGHIJK"))); // 11 characters
        QCOMPARE(
            Validation::withoutXmlDeclaration(QStringLiteral("<?xml version='1.0' encoding='utf-8'?>\n<a/>")),
            QStringLiteral("<a/>"));
    }

    // ClassInfo mirrors CK_CLASS_MaxStudents (1-50) and the references a class needs
    void classInfo_validate() {
        ClassInfo c;
        c.name = QStringLiteral("IELTS 6.5 - evening");
        c.courseId = QStringLiteral("IE-65");
        c.branchId = QStringLiteral("BR01");
        c.teacherId = QStringLiteral("TE0001");
        c.roomId = QStringLiteral("D1-201");
        c.startDate = QDate(2026, 11, 2);
        QVERIFY(c.validate().isEmpty());
        c.maxStudents = 51;
        QCOMPARE(c.validate().size(), 1);
        c.maxStudents = 20;
        c.roomId.clear();
        c.name.clear();
        QCOMPARE(c.validate().size(), 2);
    }

    // CK_CLASS_SCHEDULE_Weekday and CK_CLASS_SCHEDULE_Time: 1-7, ends after it starts, within 07:00-22:00
    void scheduleSlot_validate() {
        ScheduleSlot slot{2, QTime(18, 0), QTime(20, 0)};
        QVERIFY(slot.validate().isEmpty());
        slot.end = QTime(17, 0);
        QCOMPARE(slot.validate().size(), 1);
        slot = {7, QTime(6, 30), QTime(8, 0)};
        QCOMPARE(slot.validate().size(), 1);
        slot = {8, QTime(9, 0), QTime(10, 0)};
        QCOMPARE(slot.validate().size(), 1);
    }

    // The database returns one row per student and component; the grade book has one row per student and
    // computes the final grade like dbo.fn_FinalGrade (NULL while a score is missing, rounded once to 2
    // decimals)
    void gradeBook_pivotAndFinalGrade() {
        const QString an = QStringLiteral("An");
        const QString binh = QStringLiteral("Bình");
        const QList<GradeCell> cells = {
            {QStringLiteral("EN1"), QStringLiteral("ST1"), an, 7, QStringLiteral("Homework"), 20, 8.0},
            {QStringLiteral("EN1"), QStringLiteral("ST1"), an, 8, QStringLiteral("Midterm"), 30, 6.5},
            {QStringLiteral("EN1"), QStringLiteral("ST1"), an, 9, QStringLiteral("Final"), 50, 7.25},
            {QStringLiteral("EN2"), QStringLiteral("ST2"), binh, 7, QStringLiteral("Homework"), 20, 9.0},
            {QStringLiteral("EN2"), QStringLiteral("ST2"), binh, 8, QStringLiteral("Midterm"), 30,
             std::nullopt},
            {QStringLiteral("EN2"), QStringLiteral("ST2"), binh, 9, QStringLiteral("Final"), 50,
             std::nullopt},
        };
        const GradeBook book = GradeBook::fromCells(cells);
        QCOMPARE(book.components.size(), 3);
        QCOMPARE(book.rows.size(), 2);
        QCOMPARE(book.totalWeight(), 100.0);
        // (8 x 20 + 6.5 x 30 + 7.25 x 50) / 100 = (160 + 195 + 362.5) / 100 = 7.175 -> 7.18
        QCOMPARE(*book.finalGrade(0), 7.18);
        QVERIFY(!book.finalGrade(1).has_value()); // scores missing
        QVERIFY(!book.finalGrade(5).has_value()); // no such row
    }

    // The payment form: an amount above what is still owed is refused before the triggers would refuse it
    void receipt_validate() {
        ReceiptRequest r;
        r.enrollmentId = QStringLiteral("EN000001");
        r.amount = 2000000;
        QVERIFY(r.validate(2000000).isEmpty());
        QCOMPARE(r.validate(1500000).size(), 1);
        r.amount = 0;
        QCOMPARE(r.validate(-1).size(), 1);
        r.amount = 100;
        r.paymentMethod = QStringLiteral("Cheque");
        QCOMPARE(r.validate(-1).size(), 1);
    }

    // A session is taught on or after its date (trg_CLASS_SESSION_LockTaught)
    void sessionUpdate_taughtInFuture_isRejected() {
        SessionUpdate u{12, QDate(2026, 10, 5), QStringLiteral("Taught"), QString()};
        QCOMPARE(u.validate(QDate(2026, 10, 4)).size(), 1);
        QVERIFY(u.validate(QDate(2026, 10, 5)).isEmpty());
        u.status = QStringLiteral("Cancelled");
        QVERIFY(u.validate(QDate(2026, 10, 4)).isEmpty());
    }

    // The catalog rules: code format for a new row only, percentages at most 50, end not before start, the
    // prerequisite is not the course itself, a weight above 0
    void catalog_validate() {
        Branch b;
        b.id = QStringLiteral("BR 03");
        b.name = QStringLiteral("New branch");
        b.address = QStringLiteral("1 Street");
        QCOMPARE(b.validate(true).size(), 1); // a space in a new code
        QVERIFY(b.validate(false).isEmpty()); // the code of an existing branch is not checked again
        Promotion p;
        p.id = QStringLiteral("PR-X");
        p.name = QStringLiteral("Promo");
        p.discountValue = 60;
        p.startDate = QDate(2026, 10, 1);
        p.endDate = QDate(2026, 9, 1);
        QCOMPARE(p.validate(true).size(), 2); // 60% and the dates
        Course c;
        c.id = QStringLiteral("IE-55");
        c.programId = QStringLiteral("IELTS");
        c.name = QStringLiteral("IELTS 5.5");
        c.prerequisiteId = QStringLiteral("IE-55");
        QCOMPARE(c.validate(false).size(), 1);
        GradeComponent g;
        g.courseId = QStringLiteral("IE-55");
        g.name = QStringLiteral("Quiz");
        QCOMPARE(g.validate().size(), 1);
    }

    // Staff: at least 18 on the hire date (CK_TEACHER_Age), a native speaker is not Vietnamese
    // (CK_TEACHER_Native)
    void teacher_validate() {
        Teacher t;
        t.fullName = QStringLiteral("Anna Lee");
        t.dateOfBirth = QDate(1995, 1, 1);
        t.phone = QStringLiteral("0909000999");
        t.email = QStringLiteral("anna@example.com");
        t.teacherType = QStringLiteral("Native");
        t.nationality = QStringLiteral("Vietnam");
        t.hourlyRate = 400000;
        t.branchId = QStringLiteral("BR01");
        t.hireDate = QDate(2026, 10, 1);
        QCOMPARE(t.validate(QDate(2026, 10, 1)).size(), 1);
        t.nationality = QStringLiteral("Canada");
        QVERIFY(t.validate(QDate(2026, 10, 1)).isEmpty());
        t.dateOfBirth = QDate(2010, 1, 1);
        QCOMPARE(t.validate(QDate(2026, 10, 1)).size(), 1);
    }

    // The username pattern of usp_Account_Create (no diacritics), the password length and its confirmation
    void newAccount_validate() {
        NewAccount a;
        a.username = QStringLiteral("gvu_hoa");
        a.password = QStringLiteral("Secret@123");
        a.confirmation = QStringLiteral("Secret@123");
        a.role = Role::AcademicStaff;
        a.personId = QStringLiteral("EM0006");
        QVERIFY(a.validate().isEmpty());
        a.username = QStringLiteral("gvu_hòa");
        QCOMPARE(a.validate().size(), 1);
        a.username = QStringLiteral("gvu_hoa");
        a.confirmation = QStringLiteral("Other@123");
        QCOMPARE(a.validate().size(), 1);
        a.password = QStringLiteral("short");
        QCOMPARE(a.validate().size(), 1);
    }
};

QTEST_APPLESS_MAIN(TestDomain)
#include "tst_domain.moc"
