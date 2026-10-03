// Unit tests of the application layer (the use cases): StudentService, AuthService, Permissions and
// LanguageService. No database is needed.
// The fake repository pattern: a use case only knows its ports (interfaces such as IStudentRepository or
// IAuthGateway), never SQL Server. So the test hands it small in-memory "fake" classes (written below)
// instead of the real Sql* classes, then checks what the service did - e.g. that an invalid student never
// reaches the repository (addCalls stays 0).
// Why not the real database: the tests run in milliseconds, on CI without SQL Server, need no seed data and
// fail only when the use case itself is wrong. The real repositories and the database rules are covered by
// tst_e2e_gui and database/12_tests.sql.
// Reference for new use cases: FakeStudentRepository (see .claude/rules/03-tests.md).
// Run only this suite:
//   ctest --preset macos-debug -R tst_application --output-on-failure
#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "application/services/Permissions.h"
#include "application/services/StudentService.h"

#include <QtTest>

// ===== Fakes that replace SQL Server =====
// The STUDENT table as a list in memory; addCalls counts the calls, so a test can prove whether the service
// reached the "database" at all. The generated IDs are fake (the real ones come from a SEQUENCE).
class FakeStudentRepository : public IStudentRepository {
public:
    QList<Student> data;
    int addCalls = 0;

    Result<QList<Student>> search(const StudentFilter&) override {
        return Result<QList<Student>>::success(data);
    }
    Result<Student> findById(const QString& id) override {
        for (const auto& s : data)
            if (s.id == id)
                return Result<Student>::success(s);
        return Result<Student>::failure(QStringLiteral("Not found"));
    }
    Result<QString> add(const Student& student) override {
        ++addCalls;
        Student added = student;
        added.id = QStringLiteral("HV%1").arg(data.size() + 1, 5, 10, QLatin1Char('0'));
        data.append(added);
        return Result<QString>::success(added.id);
    }
    VoidResult update(const Student&) override { return VoidResult::success(); }
    VoidResult remove(const QString&) override { return VoidResult::success(); }
};

// The branch list (normally the BRANCH table): one branch is enough here
class FakeCatalog : public ICatalogRepository {
public:
    Result<QList<Branch>> branches() override {
        return Result<QList<Branch>>::success(
            {{QStringLiteral("BR01"), QStringLiteral("District 1 Branch")}});
    }
};

// Plays SQL Server during sign-in: only gvu_lan / right-password is accepted. locked = true simulates an
// account whose password is right but whose ACCOUNT row is locked; logoutCalls shows whether the
// connection was closed.
class FakeAuthGateway : public IAuthGateway {
public:
    bool locked = false;
    int logoutCalls = 0;

    Result<Account> login(const ServerConfig&, const QString& username, const QString& password) override {
        if (username == QStringLiteral("gvu_lan") && password == QStringLiteral("right-password")) {
            Account account;
            account.username = username;
            account.role = Role::AcademicStaff;
            account.fullName = QStringLiteral("Lê Thị Lan");
            account.active = !locked;
            return Result<Account>::success(account);
        }
        return Result<Account>::failure(QStringLiteral("Wrong username or password"));
    }
    void logout() override { ++logoutCalls; }
    VoidResult changePassword(const QString&, const QString&) override { return VoidResult::success(); }
};

// The saved settings (normally QSettings) kept in members; languageSaves counts the language saves
class FakeSettings : public ISettingsStore {
public:
    ServerConfig config;
    QString username;
    Language lang = Language::Vietnamese;
    int languageSaves = 0;
    ServerConfig serverConfig() const override { return config; }
    void saveServerConfig(const ServerConfig& c) override { config = c; }
    QString lastUsername() const override { return username; }
    void saveLastUsername(const QString& u) override { username = u; }
    Language language() const override { return lang; }
    void saveLanguage(Language l) override {
        lang = l;
        ++languageSaves;
    }
};

class TestApplication : public QObject {
    Q_OBJECT

private slots:
    // A valid student reaches the repository exactly once, with the name normalized (extra spaces removed)
    void addStudent_valid_callsRepository() {
        FakeStudentRepository repository;
        FakeCatalog catalog;
        StudentService service(repository, catalog);
        Student s;
        s.fullName = QStringLiteral("  Trần   Thị  Bích  ");
        s.dateOfBirth = QDate(2001, 3, 4);
        s.gender = QStringLiteral("Female");
        s.phone = QStringLiteral("0909000111");
        s.branchId = QStringLiteral("BR01");
        const auto result = service.add(s, QDate(2026, 10, 1));
        QVERIFY2(result.ok(), qPrintable(result.error()));
        QCOMPARE(repository.addCalls, 1);
        QCOMPARE(repository.data.first().fullName, QStringLiteral("Trần Thị Bích")); // whitespace normalized
    }

    // An empty student fails the domain validation, so the service never calls the repository (the database)
    void addStudent_invalid_doesNotCallRepository() {
        FakeStudentRepository repository;
        FakeCatalog catalog;
        StudentService service(repository, catalog);
        const auto result = service.add(Student{}, QDate(2026, 10, 1));
        QVERIFY(!result.ok());
        QCOMPARE(repository.addCalls, 0);
    }

    // Update and delete need the ID of a student; without it the repository is never reached
    void updateOrRemoveStudent_missingId_fails() {
        FakeStudentRepository repository;
        FakeCatalog catalog;
        StudentService service(repository, catalog);
        QVERIFY(!service.update(Student{}, QDate(2026, 10, 1)).ok());
        QVERIFY(!service.remove(QString()).ok());
        QVERIFY(!service.details(QString()).ok());
    }

    // Accepted sign-in: the session keeps the role, the username is remembered, logout ends the session
    void login_success_keepsSession() {
        FakeAuthGateway gateway;
        FakeSettings settings;
        AuthService auth(gateway, settings);
        QVERIFY(auth.login(QStringLiteral("gvu_lan"), QStringLiteral("right-password")).ok());
        QVERIFY(auth.isLoggedIn());
        QCOMPARE(auth.role(), Role::AcademicStaff);
        QCOMPARE(settings.username, QStringLiteral("gvu_lan"));
        auth.logout();
        QVERIFY(!auth.isLoggedIn());
    }

    // An empty username/password and a wrong password are both refused
    void login_missingInput_fails() {
        FakeAuthGateway gateway;
        FakeSettings settings;
        AuthService auth(gateway, settings);
        QVERIFY(!auth.login(QString(), QString()).ok());
        QVERIFY(!auth.login(QStringLiteral("gvu_lan"), QStringLiteral("wrong")).ok());
    }

    void login_lockedAccount_isRejectedAndDisconnected() {
        FakeAuthGateway gateway;
        gateway.locked = true;
        FakeSettings settings;
        AuthService auth(gateway, settings);
        const auto result = auth.login(QStringLiteral("gvu_lan"), QStringLiteral("right-password"));
        QVERIFY(!result.ok());
        QCOMPARE(result.error(), QStringLiteral("The account is locked."));
        QVERIFY(!auth.isLoggedIn());
        QCOMPARE(gateway.logoutCalls, 1);     // the connection opened by the gateway is closed
        QVERIFY(settings.username.isEmpty()); // a refused login is not remembered
    }

    // The quick checks of AuthService before the database: at least 8 characters, the confirmation must
    // match; a valid change reaches the gateway (the fake accepts it)
    void changePassword_validatesInput() {
        FakeAuthGateway gateway;
        FakeSettings settings;
        AuthService auth(gateway, settings);
        QVERIFY(auth.login(QStringLiteral("gvu_lan"), QStringLiteral("right-password")).ok());
        QVERIFY(
            !auth.changePassword(QStringLiteral("a"), QStringLiteral("short"), QStringLiteral("short")).ok());
        QVERIFY(
            !auth.changePassword(QStringLiteral("a"), QStringLiteral("Password@1"), QStringLiteral("Other@1"))
                 .ok());
        QVERIFY(auth.changePassword(QStringLiteral("a"), QStringLiteral("Password@1"),
                                    QStringLiteral("Password@1"))
                    .ok());
    }

    // Spot checks of the role -> feature matrix of Permissions (it decides what the menu shows; the GRANTs of
    // 06_security.sql are the real check)
    void permissions_teacherCannotSeeStudents() {
        QVERIFY(!Permissions::isAllowed(Role::Teacher, Feature::Students));
        QVERIFY(Permissions::isAllowed(Role::Teacher, Feature::MyTeachingSchedule));
        QVERIFY(!Permissions::isAllowed(Role::AcademicStaff, Feature::Payroll));
        QVERIFY(Permissions::isAllowed(Role::Accountant, Feature::OutstandingTuition));
        QVERIFY(!Permissions::canEditStudents(Role::Accountant));
        QVERIFY(Permissions::allowedFeatures(Role::Unknown).isEmpty());
    }

    void language_defaultVietnamese_selectionIsSaved() {
        FakeSettings settings;
        LanguageService language(settings);
        QCOMPARE(language.current(), Language::Vietnamese);
        language.select(Language::English);
        QCOMPARE(settings.languageSaves, 1);
        QCOMPARE(language.current(), Language::English);
        QCOMPARE(LanguageService::supported(), supportedLanguages());
    }
};

// main() without a Qt application object: the use cases are plain logic
QTEST_APPLESS_MAIN(TestApplication)
#include "tst_application.moc"
