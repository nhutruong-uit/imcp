// Unit tests of the application layer (the use cases): StudentService, AuthService, Permissions,
// LanguageService and the services of the data-entry screens (classes, enrollments, tuition, sessions,
// grades, payroll, accounts, catalogs, courses, staff, backup). No database is needed. The fake repository
// pattern: a use case only knows its ports (interfaces such as IStudentRepository or IAuthGateway), never SQL
// Server. So the test hands it small in-memory "fake" classes (written below) instead of the real Sql*
// classes, then checks what the service did - e.g. that an invalid student never reaches the repository
// (addCalls stays 0). Why not the real database: the tests run in milliseconds, on CI without SQL Server,
// need no seed data and fail only when the use case itself is wrong. The real repositories and the database
// rules are covered by tst_e2e_gui and database/12_tests.sql. Reference for new use cases:
// FakeStudentRepository (see .claude/rules/03-tests.md). Run only this suite:
//   ctest --preset macos-debug -R tst_application --output-on-failure
#include "application/services/AccountService.h"
#include "application/services/AuthService.h"
#include "application/services/BackupService.h"
#include "application/services/CatalogService.h"
#include "application/services/ClassService.h"
#include "application/services/CourseService.h"
#include "application/services/EnrollmentService.h"
#include "application/services/GradeService.h"
#include "application/services/LanguageService.h"
#include "application/services/ListService.h"
#include "application/services/PayrollService.h"
#include "application/services/Permissions.h"
#include "application/services/SessionService.h"
#include "application/services/StaffService.h"
#include "application/services/StudentService.h"
#include "application/services/TuitionService.h"

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
    Result<QString> exportXml(const QString&) override {
        return Result<QString>::success(QStringLiteral("<Students/>"));
    }
    Result<ImportResult> importXml(const QString& xml, const QString&) override {
        lastImportedXml = xml;
        return Result<ImportResult>::success({1, 0});
    }
    QString lastImportedXml;
};

// The catalogs (normally BRANCH, ROOM, PROGRAM, PROMOTION): one branch is enough here; the writes are
// recorded
class FakeCatalog : public ICatalogRepository {
public:
    QStringList calls; // "addBranch BR03", "updateRoom D1-101"...

    Result<QList<Branch>> branches() override {
        Branch b;
        b.id = QStringLiteral("BR01");
        b.name = QStringLiteral("District 1 Branch");
        return Result<QList<Branch>>::success({b});
    }
    Result<TableData> branchList() override { return Result<TableData>::success({}); }
    Result<Branch> branch(const QString&) override {
        return Result<Branch>::failure(QStringLiteral("unused"));
    }
    VoidResult addBranch(const Branch& b) override { return record(QStringLiteral("addBranch ") + b.id); }
    VoidResult updateBranch(const Branch& b) override {
        return record(QStringLiteral("updateBranch ") + b.id);
    }
    Result<TableData> roomList(const QString&) override { return Result<TableData>::success({}); }
    Result<Room> room(const QString&) override { return Result<Room>::failure(QStringLiteral("unused")); }
    VoidResult addRoom(const Room& r) override { return record(QStringLiteral("addRoom ") + r.id); }
    VoidResult updateRoom(const Room& r) override { return record(QStringLiteral("updateRoom ") + r.id); }
    Result<TableData> programList() override { return Result<TableData>::success({}); }
    Result<QList<LookupItem>> programOptions() override { return Result<QList<LookupItem>>::success({}); }
    Result<Program> program(const QString&) override {
        return Result<Program>::failure(QStringLiteral("unused"));
    }
    VoidResult addProgram(const Program& p) override { return record(QStringLiteral("addProgram ") + p.id); }
    VoidResult updateProgram(const Program& p) override {
        return record(QStringLiteral("updateProgram ") + p.id);
    }
    Result<TableData> promotionList() override { return Result<TableData>::success({}); }
    Result<Promotion> promotion(const QString&) override {
        return Result<Promotion>::failure(QStringLiteral("unused"));
    }
    VoidResult addPromotion(const Promotion& p) override {
        return record(QStringLiteral("addPromotion ") + p.id);
    }
    VoidResult updatePromotion(const Promotion& p) override {
        return record(QStringLiteral("updatePromotion ") + p.id);
    }

private:
    VoidResult record(const QString& call) {
        calls << call;
        return VoidResult::success();
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

// The class procedures; `calls` records what reached the "database", so a test proves an invalid input never
// does
class FakeClassRepository : public IClassRepository {
public:
    QStringList calls;
    Result<TableData> search(const ClassFilter&) override { return Result<TableData>::success({}); }
    Result<ClassInfo> findById(const QString&) override {
        return Result<ClassInfo>::failure(QStringLiteral("unused"));
    }
    Result<QString> add(const ClassInfo& c) override {
        calls << QStringLiteral("add ") + c.name;
        return Result<QString>::success(QStringLiteral("CL0099"));
    }
    VoidResult update(const ClassInfo& c) override { return record(QStringLiteral("update ") + c.id); }
    Result<QList<ScheduleSlot>> schedule(const QString&) override {
        return Result<QList<ScheduleSlot>>::success({});
    }
    VoidResult saveSlot(const QString& classId, const ScheduleSlot&) override {
        return record(QStringLiteral("saveSlot ") + classId);
    }
    VoidResult removeSlot(const QString& classId, int weekday) override {
        return record(QStringLiteral("removeSlot %1 %2").arg(classId).arg(weekday));
    }
    Result<SessionsGenerated> generateSessions(const QString&) override {
        return Result<SessionsGenerated>::success({});
    }
    VoidResult changeStatus(const QString& classId, const QString& status) override {
        return record(QStringLiteral("status %1 %2").arg(classId, status));
    }
    Result<EvaluationResult> evaluate(const QString&) override {
        return Result<EvaluationResult>::success({});
    }
    Result<TableData> students(const QString&, bool) override { return Result<TableData>::success({}); }
    Result<TableData> results(const QString&) override { return Result<TableData>::success({}); }
    Result<QList<LookupItem>> courseOptions() override { return Result<QList<LookupItem>>::success({}); }
    Result<QList<LookupItem>> teacherOptions() override { return Result<QList<LookupItem>>::success({}); }
    Result<QList<LookupItem>> roomOptions(const QString& branchId) override {
        calls << QStringLiteral("rooms ") + branchId;
        return Result<QList<LookupItem>>::success({});
    }
    Result<qint64> courseTuition(const QString&) override { return Result<qint64>::success(0); }

private:
    VoidResult record(const QString& call) {
        calls << call;
        return VoidResult::success();
    }
};

// Two TOEIC classes at BR01, one at BR02 and an IELTS class at BR01: the transfer targets come from this list
class FakeEnrollmentRepository : public IEnrollmentRepository {
public:
    QStringList calls;
    Result<TableData> search(const EnrollmentFilter&) override { return Result<TableData>::success({}); }
    Result<QString> enroll(const EnrollmentRequest& r) override {
        calls << QStringLiteral("enroll %1 %2").arg(r.studentId, r.classId);
        return Result<QString>::success(QStringLiteral("EN000999"));
    }
    VoidResult transfer(const QString& enrollmentId, const QString& classId) override {
        calls << QStringLiteral("transfer %1 %2").arg(enrollmentId, classId);
        return VoidResult::success();
    }
    VoidResult changeStatus(const QString& enrollmentId, const QString& status) override {
        calls << QStringLiteral("status %1 %2").arg(enrollmentId, status);
        return VoidResult::success();
    }
    Result<QList<ClassOption>> openClasses() override {
        auto option = [](const char* id, const char* course, const char* branch) {
            ClassOption c;
            c.id = QString::fromLatin1(id);
            c.courseId = QString::fromLatin1(course);
            c.branchId = QString::fromLatin1(branch);
            return c;
        };
        return Result<QList<ClassOption>>::success(
            {option("CL0004", "TO-450", "BR01"), option("CL0011", "TO-450", "BR01"),
             option("CL0012", "TO-450", "BR02"), option("CL0003", "IE-55", "BR01")});
    }
    Result<QList<LookupItem>> promotionOptions(const QDate&) override {
        return Result<QList<LookupItem>>::success({});
    }
};

class FakeTuitionRepository : public ITuitionRepository {
public:
    int collectCalls = 0;
    int cancelCalls = 0;
    Result<TableData> receipts(const ReceiptFilter&) override { return Result<TableData>::success({}); }
    Result<TableData> outstanding() override { return Result<TableData>::success({}); }
    Result<QString> collect(const ReceiptRequest&) override {
        ++collectCalls;
        return Result<QString>::success(QStringLiteral("RC000999"));
    }
    VoidResult cancel(const QString&, const QString&) override {
        ++cancelCalls;
        return VoidResult::success();
    }
    Result<ReceiptPrint> print(const QString&) override { return Result<ReceiptPrint>::success({}); }
};

class FakeSessionRepository : public ISessionRepository {
public:
    QDate from;
    QDate to;
    int saveCalls = 0;
    Result<TableData> sessions(const QDate& f, const QDate& t, bool) override {
        from = f;
        to = t;
        return Result<TableData>::success({});
    }
    VoidResult update(const SessionUpdate&) override { return VoidResult::success(); }
    Result<QList<AttendanceMark>> attendance(int) override {
        return Result<QList<AttendanceMark>>::success({});
    }
    VoidResult saveAttendance(int, const QList<AttendanceMark>&) override {
        ++saveCalls;
        return VoidResult::success();
    }
};

class FakeGradeRepository : public IGradeRepository {
public:
    int saveCalls = 0;
    Result<QList<ClassOption>> classes(bool) override { return Result<QList<ClassOption>>::success({}); }
    Result<QList<GradeCell>> cells(const QString&, bool) override {
        GradeCell c;
        c.enrollmentId = QStringLiteral("EN1");
        c.componentId = 7;
        c.weight = 100;
        c.score = 8.5;
        return Result<QList<GradeCell>>::success({c});
    }
    VoidResult save(const QList<GradeEntry>&) override {
        ++saveCalls;
        return VoidResult::success();
    }
};

class FakePayrollRepository : public IPayrollRepository {
public:
    int finalizeCalls = 0;
    int adjustCalls = 0;
    Result<TableData> list(const PayrollFilter&) override { return Result<TableData>::success({}); }
    Result<TableData> finalize(int, int) override {
        ++finalizeCalls;
        return Result<TableData>::success({});
    }
    VoidResult adjust(int, qint64) override {
        ++adjustCalls;
        return VoidResult::success();
    }
    VoidResult markPaid(int) override { return VoidResult::success(); }
};

class FakeAccountRepository : public IAccountRepository {
public:
    QStringList calls;
    Result<TableData> list() override { return Result<TableData>::success({}); }
    VoidResult create(const NewAccount& a) override {
        calls << QStringLiteral("create ") + a.username;
        return VoidResult::success();
    }
    VoidResult setLocked(const QString& username, bool locked) override {
        calls << QStringLiteral("%1 %2").arg(locked ? QStringLiteral("lock") : QStringLiteral("unlock"),
                                             username);
        return VoidResult::success();
    }
    VoidResult resetPassword(const QString& username, const QString&) override {
        calls << QStringLiteral("reset ") + username;
        return VoidResult::success();
    }
    Result<QList<LookupItem>> peopleWithoutAccount(Role) override {
        return Result<QList<LookupItem>>::success({});
    }
};

class FakeCourseRepository : public ICourseRepository {
public:
    QString lastSyllabus;
    int saveCalls = 0;
    Result<TableData> list() override { return Result<TableData>::success({}); }
    Result<QList<LookupItem>> options() override { return Result<QList<LookupItem>>::success({}); }
    Result<Course> findById(const QString&) override {
        return Result<Course>::failure(QStringLiteral("unused"));
    }
    int addCalls = 0;
    int updateCalls = 0;
    VoidResult add(const Course&) override {
        ++addCalls;
        return saved();
    }
    VoidResult update(const Course&) override {
        ++updateCalls;
        return saved();
    }
    Result<TableData> syllabus(const QString&) override { return Result<TableData>::success({}); }
    Result<QString> syllabusXml(const QString&) override { return Result<QString>::success({}); }
    VoidResult setSyllabus(const QString&, const QString& xml) override {
        lastSyllabus = xml;
        return VoidResult::success();
    }
    Result<TableData> findBySkill(const QString&) override { return Result<TableData>::success({}); }
    Result<TableData> components(const QString&) override { return Result<TableData>::success({}); }
    VoidResult saveComponent(const GradeComponent&) override { return saved(); }
    VoidResult removeComponent(int) override { return saved(); }

private:
    VoidResult saved() {
        ++saveCalls;
        return VoidResult::success();
    }
};

class FakeStaffRepository : public IStaffRepository {
public:
    int addCalls = 0;
    Result<TableData> employees() override { return Result<TableData>::success({}); }
    Result<Employee> employee(const QString&) override {
        return Result<Employee>::failure(QStringLiteral("unused"));
    }
    Result<QString> addEmployee(const Employee&) override {
        ++addCalls;
        return Result<QString>::success(QStringLiteral("EM0099"));
    }
    int updateCalls = 0;
    QString lastProfileXml;
    VoidResult updateEmployee(const Employee&) override {
        ++updateCalls;
        return VoidResult::success();
    }
    Result<TableData> teachers() override { return Result<TableData>::success({}); }
    Result<Teacher> teacher(const QString&) override {
        return Result<Teacher>::failure(QStringLiteral("unused"));
    }
    Result<QString> addTeacher(const Teacher& t) override {
        ++addCalls;
        lastProfileXml = t.profileXml;
        return Result<QString>::success(QStringLiteral("TE0099"));
    }
    VoidResult updateTeacher(const Teacher& t) override {
        ++updateCalls;
        lastProfileXml = t.profileXml;
        return VoidResult::success();
    }
    Result<TableData> findTeachersByCertificate(const QString&, double) override {
        return Result<TableData>::success({});
    }
};

class FakeBackupRepository : public IBackupRepository {
public:
    int calls = 0;
    Result<QString> backup(const QString& type, const QString&) override {
        ++calls;
        return Result<QString>::success(QStringLiteral("/var/opt/mssql/data/QLTTTA_%1.bak").arg(type));
    }
};

// Records which lists were read
class FakeListRepository : public IListRepository {
public:
    QList<ListKind> kinds;
    Result<TableData> fetch(ListKind kind) override {
        kinds << kind;
        return Result<TableData>::success(TableData());
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
    void changePassword_shortOrMismatched_isRejected() {
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
    void permissions_eachRole_seesOnlyItsFeatures() {
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

    // Which roles change data on which page (the buttons); the GRANTs of 06_security.sql are the real check
    void permissions_canEdit_matchesTheRoles() {
        QVERIFY(Permissions::canEdit(Role::AcademicStaff, Feature::Classes));
        QVERIFY(Permissions::canEdit(Role::AcademicStaff, Feature::Grades));
        QVERIFY(
            !Permissions::canEdit(Role::AcademicStaff, Feature::Courses)); // academic staff only read courses
        QVERIFY(!Permissions::canEdit(Role::AcademicStaff, Feature::Tuition)); // not even in the menu
        QVERIFY(Permissions::canEdit(Role::Accountant, Feature::Tuition));
        QVERIFY(Permissions::canEdit(Role::Accountant, Feature::Payroll));
        QVERIFY(!Permissions::canEdit(Role::Accountant, Feature::Students));
        QVERIFY(Permissions::canEdit(Role::Manager, Feature::Backup));
        QVERIFY(Permissions::canEdit(Role::Teacher, Feature::MyGrades));
        QVERIFY(!Permissions::canEdit(Role::Teacher, Feature::MyPay));
        QVERIFY(
            !Permissions::canEdit(Role::Manager, Feature::MyGrades)); // the teacher pages are not in its menu
        QVERIFY(Permissions::isAllowed(Role::Teacher, Feature::MyGrades));
        QVERIFY(!Permissions::isAllowed(Role::AcademicStaff, Feature::Employees));
    }

    // A class without name or room never reaches usp_Class_Create; a valid one does, with the name normalized
    void addClass_invalid_doesNotCallRepository() {
        FakeClassRepository repository;
        ClassService service(repository);
        ClassInfo c;
        c.name = QStringLiteral("  TOEIC   550 ");
        c.courseId = QStringLiteral("TO-450");
        c.branchId = QStringLiteral("BR01");
        c.teacherId = QStringLiteral("TE0005");
        c.startDate = QDate(2026, 11, 2);
        QVERIFY(!service.add(c).ok()); // no room
        QVERIFY(repository.calls.isEmpty());
        c.roomId = QStringLiteral("D1-101");
        const auto result = service.add(c);
        QVERIFY2(result.ok(), qPrintable(result.error()));
        QCOMPARE(repository.calls, QStringList{QStringLiteral("add TOEIC 550")});
    }

    // Start and Cancel send the two moves usp_Class_UpdateStatus accepts; a bad slot is refused before the
    // database
    void classService_statusMoveOrBadSlot_sendsOnlyValidCalls() {
        FakeClassRepository repository;
        ClassService service(repository);
        QVERIFY(service.start(QStringLiteral("CL0010")).ok());
        QVERIFY(service.cancel(QStringLiteral("CL0010")).ok());
        QVERIFY(!service.saveSlot(QStringLiteral("CL0010"), {6, QTime(21, 0), QTime(22, 30)})
                     .ok()); // after 22:00
        QVERIFY(service.saveSlot(QStringLiteral("CL0010"), {6, QTime(9, 0), QTime(10, 30)}).ok());
        QVERIFY(!service.removeSlot(QStringLiteral("CL0010"), 9).ok());
        QCOMPARE(repository.calls,
                 QStringList({QStringLiteral("status CL0010 In progress"),
                              QStringLiteral("status CL0010 Cancelled"), QStringLiteral("saveSlot CL0010")}));
        QVERIFY(service.roomOptions(QString()).value().isEmpty()); // no branch, no query
        QCOMPARE(repository.calls.size(), 3);
    }

    // The transfer targets: open classes of the same course AND branch, without the current class
    // (usp_Enrollment_TransferClass refuses the others with 50027)
    void transferTargets_otherClasses_keepSameCourseAndBranch() {
        FakeEnrollmentRepository repository;
        EnrollmentService service(repository);
        const auto targets = service.transferTargets(QStringLiteral("CL0004"));
        QVERIFY(targets.ok());
        QCOMPARE(targets.value().size(), 1);
        QCOMPARE(targets.value().first().id, QStringLiteral("CL0011"));
        QVERIFY(service.transferTargets(QStringLiteral("CL9999")).value().isEmpty()); // unknown current class
    }

    // An enrollment dated tomorrow never reaches usp_Enrollment_Create (50100): attendance would count from
    // it
    void enrollmentService_futureDate_doesNotCallRepository() {
        FakeEnrollmentRepository repository;
        EnrollmentService service(repository);
        EnrollmentRequest request;
        request.studentId = QStringLiteral("ST00001");
        request.classId = QStringLiteral("CL0010");
        request.enrolledOn = QDate(2026, 10, 6);
        QVERIFY(!service.enroll(request, QDate(2026, 10, 5)).ok());
        QVERIFY(repository.calls.isEmpty());
        request.enrolledOn = QDate(2026, 9, 30); // typed later from a paper form
        QVERIFY(service.enroll(request, QDate(2026, 10, 5)).ok());
    }

    // An enrollment needs a student and a class; transfer needs another class; the status moves are sent as
    // stored values
    void enrollmentService_missingOrSameClass_doesNotCallRepository() {
        FakeEnrollmentRepository repository;
        EnrollmentService service(repository);
        EnrollmentRequest request;
        request.studentId = QStringLiteral("ST00001");
        QVERIFY(!service.enroll(request, QDate(2026, 10, 5)).ok());
        QVERIFY(
            !service.transfer(QStringLiteral("EN000001"), QStringLiteral("CL0004"), QStringLiteral("CL0004"))
                 .ok());
        QVERIFY(repository.calls.isEmpty());
        request.classId = QStringLiteral("CL0010");
        QVERIFY(service.enroll(request, QDate(2026, 10, 5)).ok());
        QVERIFY(service.putOnHold(QStringLiteral("EN000001")).ok());
        QVERIFY(service.resume(QStringLiteral("EN000001")).ok());
        QVERIFY(service.leave(QStringLiteral("EN000001")).ok());
        QCOMPARE(repository.calls,
                 QStringList(
                     {QStringLiteral("enroll ST00001 CL0010"), QStringLiteral("status EN000001 On hold"),
                      QStringLiteral("status EN000001 Studying"), QStringLiteral("status EN000001 Left")}));
    }

    // A payment above the balance and a cancellation without a reason never reach the database
    void tuitionService_overpaymentOrNoReason_doesNotCallRepository() {
        FakeTuitionRepository repository;
        TuitionService service(repository);
        ReceiptRequest r;
        r.enrollmentId = QStringLiteral("EN000001");
        r.amount = 3000000;
        QVERIFY(!service.collect(r, 2000000).ok());
        QCOMPARE(repository.collectCalls, 0);
        r.amount = 2000000;
        QVERIFY(service.collect(r, 2000000).ok());
        QCOMPARE(repository.collectCalls, 1);
        QVERIFY(!service.cancel(QStringLiteral("RC000001"), QStringLiteral("   ")).ok());
        QCOMPARE(repository.cancelCalls, 0);
        QVERIFY(service.cancel(QStringLiteral("RC000001"), QStringLiteral("Wrong amount")).ok());
        ReceiptFilter backwards;
        backwards.from = QDate(2026, 10, 1);
        backwards.to = QDate(2026, 9, 1);
        QVERIFY(!service.receipts(backwards).ok());
    }

    // The timetable asks for one whole week: from Monday (included) to the next Monday (excluded)
    void sessionService_anyDayOfWeek_asksMondayToMonday() {
        FakeSessionRepository repository;
        SessionService service(repository);
        QVERIFY(service.week(QDate(2026, 10, 8), false).ok()); // a Thursday
        QCOMPARE(repository.from, QDate(2026, 10, 5));
        QCOMPARE(repository.to, QDate(2026, 10, 12));
        QVERIFY(
            !service.saveAttendance(5, {{QStringLiteral("EN1"), {}, {}, QStringLiteral("Asleep"), {}, false}})
                 .ok());
        QVERIFY(
            service.saveAttendance(5, {{QStringLiteral("EN1"), {}, {}, QStringLiteral("Late"), {}, false}})
                .ok());
        QCOMPARE(repository.saveCalls, 1);
    }

    // The grade book comes back pivoted; a score outside 0-10 is never saved
    void gradeService_scoreAbove10_isNotSaved() {
        FakeGradeRepository repository;
        GradeService service(repository);
        const auto book = service.book(QStringLiteral("CL0003"), false);
        QVERIFY(book.ok());
        QCOMPARE(book.value().rows.size(), 1);
        QCOMPARE(*book.value().finalGrade(0), 8.5);
        QVERIFY(!service.save({{QStringLiteral("EN1"), 7, 11}}).ok());
        QVERIFY(service.save({}).ok()); // nothing changed
        QCOMPARE(repository.saveCalls, 0);
        QVERIFY(service.save({{QStringLiteral("EN1"), 7, 9.25}}).ok());
        QCOMPARE(repository.saveCalls, 1);
    }

    // A future month and a negative deduction are refused before the database (50050, CK_PAYROLL_Figures)
    void payrollService_futureMonthOrNegativeDeduction_isRejected() {
        FakePayrollRepository repository;
        PayrollService service(repository);
        QVERIFY(!service.finalize(11, 2026, QDate(2026, 10, 4)).ok());
        QVERIFY(!service.finalize(13, 2026, QDate(2026, 10, 4)).ok());
        QVERIFY(service.finalize(9, 2026, QDate(2026, 10, 4)).ok());
        QCOMPARE(repository.finalizeCalls, 1);
        QVERIFY(!service.adjust(5, -1).ok());
        QVERIFY(service.adjust(5, 200000).ok());
        QCOMPARE(repository.adjustCalls, 1);
    }

    // Account administration: the username rule, lock / unlock, reset with confirmation
    void accountService_usernameWithAccents_isRejected() {
        FakeAccountRepository repository;
        AccountService service(repository);
        NewAccount a;
        a.username = QStringLiteral("kế_toán");
        a.password = QStringLiteral("Secret@123");
        a.confirmation = QStringLiteral("Secret@123");
        a.role = Role::Accountant;
        a.personId = QStringLiteral("EM0006");
        QVERIFY(!service.create(a).ok());
        a.username = QStringLiteral(" kt_mai ");
        QVERIFY(service.create(a).ok());
        QVERIFY(service.lock(QStringLiteral("kt_mai")).ok());
        QVERIFY(service.unlock(QStringLiteral("kt_mai")).ok());
        QVERIFY(
            !service.resetPassword(QStringLiteral("kt_mai"), QStringLiteral("NewPass@1"), QStringLiteral("x"))
                 .ok());
        QVERIFY(service
                    .resetPassword(QStringLiteral("kt_mai"), QStringLiteral("NewPass@1"),
                                   QStringLiteral("NewPass@1"))
                    .ok());
        QCOMPARE(repository.calls,
                 QStringList({QStringLiteral("create kt_mai"), QStringLiteral("lock kt_mai"),
                              QStringLiteral("unlock kt_mai"), QStringLiteral("reset kt_mai")}));
    }

    // A new code is normalized to upper case; a malformed code never reaches usp_Branch_Add (50092)
    void catalogService_newCode_isNormalizedOrRejected() {
        FakeCatalog repository;
        CatalogService service(repository);
        Branch b;
        b.id = QStringLiteral(" br03 ");
        b.name = QStringLiteral("Binh Thanh Branch");
        b.address = QStringLiteral("1 Street");
        QVERIFY(service.saveBranch(b, true).ok());
        b.id = QStringLiteral("BR 04");
        QVERIFY(!service.saveBranch(b, true).ok());
        Room r;
        r.id = QStringLiteral("d1-301");
        r.branchId = QStringLiteral("BR01");
        r.name = QStringLiteral("Room 301");
        QVERIFY(service.saveRoom(r, true).ok());
        QCOMPARE(repository.calls,
                 QStringList({QStringLiteral("addBranch BR03"), QStringLiteral("addRoom D1-301")}));
    }

    // Editing (isNew = false) calls the _Update procedures: an inverted condition would send every edit to
    // usp_*_Add, which refuses an existing code (50091)
    void catalogService_saveExisting_callsUpdate() {
        FakeCatalog repository;
        CatalogService service(repository);
        Branch b;
        b.id = QStringLiteral("BR01");
        b.name = QStringLiteral("District 1 Branch");
        b.address = QStringLiteral("1 Street");
        QVERIFY(service.saveBranch(b, false).ok());
        Room r;
        r.id = QStringLiteral("D1-101");
        r.branchId = QStringLiteral("BR01");
        r.name = QStringLiteral("Room 101");
        QVERIFY(service.saveRoom(r, false).ok());
        QCOMPARE(repository.calls,
                 QStringList({QStringLiteral("updateBranch BR01"), QStringLiteral("updateRoom D1-101")}));
    }

    void courseService_saveExisting_callsUpdate() {
        FakeCourseRepository repository;
        CourseService service(repository);
        Course c;
        c.id = QStringLiteral("CM-A1");
        c.programId = QStringLiteral("COMM");
        c.name = QStringLiteral("Communication A1");
        c.sessionCount = 20;
        QVERIFY(service.save(c, false).ok());
        QCOMPARE(repository.updateCalls, 1);
        QCOMPARE(repository.addCalls, 0);
    }

    // The XML declaration is removed before the syllabus reaches the typed XML column; a bad course never
    // saves
    void courseService_declarationOrBadCourse_isStrippedOrRejected() {
        FakeCourseRepository repository;
        CourseService service(repository);
        QVERIFY(
            service
                .setSyllabus(QStringLiteral("CM-A1"), QStringLiteral("<?xml version=\"1.0\"?> <Syllabus/>"))
                .ok());
        QCOMPARE(repository.lastSyllabus, QStringLiteral("<Syllabus/>"));
        Course c;
        c.id = QStringLiteral("CM-B2");
        c.programId = QStringLiteral("COMM");
        c.name = QStringLiteral("Communication B2");
        c.sessionCount = 0;
        QVERIFY(!service.save(c, true).ok());
        QCOMPARE(repository.saveCalls, 0);
        c.sessionCount = 24;
        QVERIFY(service.save(c, true).ok());
        QCOMPARE(repository.saveCalls, 1);
        QVERIFY(!service.findBySkill(QStringLiteral("  ")).ok());
    }

    // A teacher of 16 is not hired (CK_TEACHER_Age); a valid employee gets the ID from the repository
    void staffService_teacherUnder18_isRejected() {
        FakeStaffRepository repository;
        StaffService service(repository);
        Teacher t;
        t.fullName = QStringLiteral("Young Teacher");
        t.dateOfBirth = QDate(2010, 5, 5);
        t.phone = QStringLiteral("0909111222");
        t.email = QStringLiteral("young@example.com");
        t.hourlyRate = 300000;
        t.branchId = QStringLiteral("BR01");
        QVERIFY(!service.saveTeacher(t, QDate(2026, 10, 4)).ok());
        Employee e;
        e.fullName = QStringLiteral("Nguyễn Thị Mai");
        e.dateOfBirth = QDate(1998, 3, 3);
        e.phone = QStringLiteral("0909333444");
        e.branchId = QStringLiteral("BR02");
        const auto id = service.saveEmployee(e, QDate(2026, 10, 4));
        QVERIFY2(id.ok(), qPrintable(id.error()));
        QCOMPARE(id.value(), QStringLiteral("EM0099"));
        QCOMPARE(repository.addCalls, 1);
    }

    // A person with an ID is updated, never added again; the ID comes back unchanged
    void staffService_saveWithId_callsUpdate() {
        FakeStaffRepository repository;
        StaffService service(repository);
        Employee e;
        e.id = QStringLiteral("EM0002");
        e.fullName = QStringLiteral("Nguyễn Thị Lan");
        e.dateOfBirth = QDate(1995, 3, 3);
        e.phone = QStringLiteral("0909333444");
        e.branchId = QStringLiteral("BR01");
        const auto id = service.saveEmployee(e, QDate(2026, 10, 4));
        QVERIFY2(id.ok(), qPrintable(id.error()));
        QCOMPARE(id.value(), QStringLiteral("EM0002"));
        QCOMPARE(repository.updateCalls, 1);
        QCOMPARE(repository.addCalls, 0);
    }

    // A profile pasted with an encoding declaration is sent without it (SQL Server error 9402 otherwise)
    void staffService_teacherProfileWithDeclaration_isSentWithoutIt() {
        FakeStaffRepository repository;
        StaffService service(repository);
        Teacher t;
        t.fullName = QStringLiteral("Lê Văn Hòa");
        t.dateOfBirth = QDate(1990, 5, 5);
        t.phone = QStringLiteral("0909111222");
        t.email = QStringLiteral("hoa@example.com");
        t.hourlyRate = 300000;
        t.branchId = QStringLiteral("BR01");
        t.profileXml = QStringLiteral("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<Profile/>");
        const auto id = service.saveTeacher(t, QDate(2026, 10, 4));
        QVERIFY2(id.ok(), qPrintable(id.error()));
        QCOMPARE(repository.lastProfileXml, QStringLiteral("<Profile/>"));
    }

    // Only the three backup types of usp_Backup are sent (50070 otherwise)
    void backupService_unknownType_isRejected() {
        FakeBackupRepository repository;
        BackupService service(repository);
        QVERIFY(!service.backup(QStringLiteral("COPY"), QString()).ok());
        QCOMPARE(repository.calls, 0);
        const auto path = service.backup(QStringLiteral("FULL"), QString());
        QVERIFY(path.ok());
        QVERIFY(path.value().endsWith(QStringLiteral("FULL.bak")));
    }

    // ListService checks the role before reading: nobody signed in, a list of another role and a feature with
    // its own page never reach the repository; an allowed list is read as its ListKind
    void listService_featureNotAllowedOrWithoutList_doesNotCallRepository() {
        FakeAuthGateway gateway;
        FakeSettings settings;
        AuthService auth(gateway, settings);
        FakeListRepository repository;
        ListService service(repository, auth);
        QVERIFY(!service.fetch(Feature::LearningResults).ok()); // not signed in yet
        QVERIFY(auth.login(QStringLiteral("gvu_lan"), QStringLiteral("right-password")).ok());
        QVERIFY(!service.fetch(Feature::MyPay).ok());    // the teacher's own list
        QVERIFY(!service.fetch(Feature::Students).ok()); // allowed, but it has its own page
        QVERIFY(repository.kinds.isEmpty());
        QVERIFY(service.fetch(Feature::LearningResults).ok());
        QCOMPARE(repository.kinds, QList<ListKind>({ListKind::LearningResults}));
    }

    // The student import needs a branch and a student export (<Students>); the declaration is removed
    void studentService_importWithoutBranchOrStudents_isRejected() {
        FakeStudentRepository repository;
        FakeCatalog catalog;
        StudentService service(repository, catalog);
        QVERIFY(!service.importXml(QStringLiteral("<Students/>"), QString()).ok());
        QVERIFY(!service.importXml(QStringLiteral("<Teachers/>"), QStringLiteral("BR01")).ok());
        QVERIFY(
            service.importXml(QStringLiteral("<?xml version=\"1.0\"?>\n<Students/>"), QStringLiteral("BR01"))
                .ok());
        QCOMPARE(repository.lastImportedXml, QStringLiteral("<Students/>"));
    }
};

// main() without a Qt application object: the use cases are plain logic
QTEST_APPLESS_MAIN(TestApplication)
#include "tst_application.moc"
