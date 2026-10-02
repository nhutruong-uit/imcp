#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "application/services/Permissions.h"
#include "application/services/StudentService.h"

#include <QtTest>

// ===== Fakes that replace SQL Server =====
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

class FakeCatalog : public ICatalogRepository {
public:
    Result<QList<Branch>> branches() override {
        return Result<QList<Branch>>::success(
            {{QStringLiteral("BR01"), QStringLiteral("District 1 Branch")}});
    }
};

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

    void addStudent_invalid_doesNotCallRepository() {
        FakeStudentRepository repository;
        FakeCatalog catalog;
        StudentService service(repository, catalog);
        const auto result = service.add(Student{}, QDate(2026, 10, 1));
        QVERIFY(!result.ok());
        QCOMPARE(repository.addCalls, 0);
    }

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

QTEST_APPLESS_MAIN(TestApplication)
#include "tst_application.moc"
