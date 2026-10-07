#include "Scenario.h"

#include "Director.h"
#include "presentation/common/Columns.h"
#include "presentation/common/DataTable.h"

#include <QAbstractItemModel>
#include <QComboBox>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QDoubleSpinBox>
#include <QLineEdit>
#include <QPushButton>
#include <QStringList>
#include <QTableView>
#include <QTableWidget>
#include <functional>

// The story of the video. One function per chapter; a chapter signs in as one demo account, shows what that
// role does and signs out again (the last chapters stay signed in), so a chapter can also be recorded alone
// (QLTTTA_DEMO_CHAPTERS) while the story is being written. The words are ids of docs/demo/captions.tsv.
// Pauses are the time a viewer needs to look at the screen; a caption also stays long enough to be read.
namespace {
using Chapter = std::function<void(Director&, const DemoSettings&)>;

void clearText(Director& d, QLineEdit* edit) {
    d.gui([edit] { edit->clear(); });
}

QPushButton* button(Director& d, const char* objectName) {
    return d.find<QPushButton>(QString::fromLatin1(objectName));
}

// The login dialog is shown at the start of a chapter unless the previous chapter ended with a log out
void ensureLogin(Director& d) {
    if (!d.loginShown())
        d.openLogin();
    d.resetLoginForm();
}

// The title card of a chapter ("card.<name>.title"/".subtitle"); the login dialog is opened behind it, so the
// card fades out onto the screen where the chapter starts
void chapterCard(Director& d, const char* name) {
    const QString prefix = QStringLiteral("card.") + QLatin1String(name);
    d.card(prefix + QStringLiteral(".title"), prefix + QStringLiteral(".subtitle"), 3000,
           [&d] { ensureLogin(d); });
}

void signIn(Director& d, const DemoSettings& settings, const QString& user) {
    auto* username = d.find<QLineEdit>(QStringLiteral("usernameEdit"));
    auto* password = d.find<QLineEdit>(QStringLiteral("passwordEdit"));
    clearText(d, username);
    clearText(d, password);
    d.type(username, user);
    d.type(password, settings.password);
    d.click(button(d, "loginButton"));
    d.waitForMainWindow();
}

// The "Log out" button of the header, then Yes to "Do you want to log out?"
void signOut(Director& d) {
    d.sayNothing();
    d.click(d.buttonWithText("MainWindow", "Log out"));
    d.waitForDialog();
    d.pause(800);
    d.click(d.dialogButton(QDialogButtonBox::Yes));
    d.waitForLogin();
    d.pause(600);
}

// Yes to the question of the message box on top ("Put enrollment ... on hold?", "Delete student ...?")
void answerYes(Director& d) {
    d.waitForDialog();
    d.pause(1100);
    d.click(d.dialogButton(QDialogButtonBox::Yes));
    d.waitForDialog(false);
}

// Opens a dialog with the button of that name, which needs a selected row for most pages
void openDialogWith(Director& d, const char* buttonName) {
    d.click(button(d, buttonName));
    d.waitForDialog();
}

// Selects the row of the main list where a column has a value (the seed data has it)
void selectWhere(Director& d, const QString& key, const QString& value) {
    DataTable* table = d.list();
    const int row = d.rowWhere(table, key, value);
    if (row < 0)
        throw DemoError(QStringLiteral("no row with %1 = %2 in the list").arg(key, value).toStdString());
    d.selectRow(table->view(), row);
}

// Looks at a page for a moment with one caption
void visit(Director& d, Feature feature, const char* captionId, int lookMs) {
    d.openPage(feature);
    d.say(QString::fromLatin1(captionId));
    d.pause(lookMs);
}

// ---- chapters --------------------------------------------------------------------------------------------

void intro(Director& d, const DemoSettings&) {
    d.card(QStringLiteral("card.intro.title"), QStringLiteral("card.intro.subtitle"), 4200,
           [&d] { ensureLogin(d); });
}

void login(Director& d, const DemoSettings&) {
    ensureLogin(d);
    d.say(QStringLiteral("login.accounts"));
    d.pause(1800);
    auto* toggle = button(d, "LinkButton");
    d.click(toggle);
    d.say(QStringLiteral("login.server"));
    d.pause(2200);
    d.click(toggle);
    d.say(QStringLiteral("login.wrong"));
    auto* username = d.find<QLineEdit>(QStringLiteral("usernameEdit"));
    auto* password = d.find<QLineEdit>(QStringLiteral("passwordEdit"));
    clearText(d, username);
    clearText(d, password);
    d.type(username, QStringLiteral("ql_quan"));
    d.type(password, QStringLiteral("wrong-password"));
    d.click(button(d, "loginButton"));
    d.pause(2800);
}

void manager(Director& d, const DemoSettings& settings) {
    chapterCard(d, "manager");
    d.say(QStringLiteral("login.ok"));
    signIn(d, settings, QStringLiteral("ql_quan"));

    // Dashboard: the figures come from the database; the branch filter recomputes them
    d.say(QStringLiteral("dashboard.kpi"));
    d.pause(3000);
    auto* branch = d.find<QComboBox>(QStringLiteral("dashboardBranchCombo"));
    d.say(QStringLiteral("dashboard.branch"));
    d.chooseIndex(branch, 1);
    d.pause(2600);
    d.chooseIndex(branch, 0);
    d.pause(800);

    // Students: search, profile, add with a business rule, delete
    d.openPage(Feature::Students);
    d.say(QStringLiteral("students.search"));
    auto* search = d.find<QLineEdit>(QStringLiteral("searchEdit"));
    d.type(search, QStringLiteral("Ngô Khánh"));
    d.pause(1500);
    auto* table = d.find<QTableView>(QStringLiteral("studentTable"));
    d.selectRow(table, 0);
    d.say(QStringLiteral("students.profile"));
    openDialogWith(d, "profileButton");
    d.pause(4200);
    d.closeDialog();
    clearText(d, search);
    d.pause(600);

    d.say(QStringLiteral("students.add"));
    openDialogWith(d, "addButton");
    d.type(d.find<QLineEdit>(QStringLiteral("fullNameEdit")), QStringLiteral("Bé Demo Video"));
    auto* birth = d.find<QDateEdit>(QStringLiteral("dateOfBirthEdit"));
    d.click(birth);
    d.gui([birth] { birth->setDate(QDate::currentDate().addYears(-10)); });
    d.pause(600);
    d.say(QStringLiteral("students.rule"));
    d.click(d.dialogButton(QDialogButtonBox::Save));
    d.pause(3200);
    d.type(d.find<QLineEdit>(QStringLiteral("guardianNameEdit")), QStringLiteral("Phụ Huynh Demo"));
    d.type(d.find<QLineEdit>(QStringLiteral("guardianPhoneEdit")), QStringLiteral("0987000111"));
    d.say(QStringLiteral("students.saved"));
    d.click(d.dialogButton(QDialogButtonBox::Save));
    d.waitForDialog(false);
    d.type(search, QStringLiteral("Bé Demo Video"));
    d.pause(1500);
    d.selectRow(table, 0);
    d.say(QStringLiteral("students.delete"));
    d.click(button(d, "deleteButton"));
    answerYes(d);
    d.pause(1200);
    clearText(d, search);
    d.pause(300);

    // Catalogs: the course syllabus is XML checked by a schema
    d.openPage(Feature::Courses);
    d.say(QStringLiteral("courses.list"));
    d.pause(2600);
    d.selectRow(d.list()->view(), 0);
    d.say(QStringLiteral("courses.syllabus"));
    openDialogWith(d, "syllabusButton");
    d.pause(4200);
    d.closeDialog();
    visit(d, Feature::Teachers, "catalogs.teachers", 1200);
    visit(d, Feature::Branches, "catalogs.branches", 1200);
    visit(d, Feature::Promotions, "catalogs.promotions", 1200);

    // System
    visit(d, Feature::Accounts, "system.accounts", 1200);
    visit(d, Feature::Backup, "system.backup", 1200);
    signOut(d);
}

void staff(Director& d, const DemoSettings& settings) {
    chapterCard(d, "staff");
    signIn(d, settings, QStringLiteral("gvu_lan"));
    d.say(QStringLiteral("staff.revenue")); // the revenue card says "no permission"
    d.pause(3600);
    d.say(QStringLiteral("staff.menu"));
    d.pause(2600);

    visit(d, Feature::PlacementTests, "placement.list", 1200);

    // Classes: the students of a class and its weekly timetable
    d.openPage(Feature::Classes);
    d.say(QStringLiteral("classes.list"));
    d.pause(2400);
    selectWhere(d, QStringLiteral("ClassId"), QStringLiteral("CL0003"));
    d.say(QStringLiteral("classes.students"));
    openDialogWith(d, "studentsButton");
    d.pause(3600);
    d.closeDialog();
    d.say(QStringLiteral("classes.schedule"));
    openDialogWith(d, "scheduleButton");
    d.pause(4200);
    d.closeDialog();

    // Enrollments: the form checks the class, then a status change asks for confirmation
    d.openPage(Feature::Enrollments);
    d.say(QStringLiteral("enrollments.list"));
    d.pause(2600);
    d.say(QStringLiteral("enrollments.new"));
    openDialogWith(d, "addButton");
    d.type(d.find<QLineEdit>(QStringLiteral("studentSearchEdit")), QStringLiteral("Hồ Minh"));
    d.click(d.buttonWithText("EnrollDialog", "Find"));
    d.pause(1200);
    d.chooseIndex(d.find<QComboBox>(QStringLiteral("classCombo")), 1);
    d.pause(3200);
    d.closeDialog();

    selectWhere(d, QStringLiteral("Status"), QStringLiteral("Studying"));
    d.say(QStringLiteral("enrollments.hold"));
    d.click(button(d, "holdButton"));
    answerYes(d);
    d.pause(2200);
    d.say(QStringLiteral("enrollments.resume"));
    d.click(button(d, "resumeButton"));
    answerYes(d);
    d.pause(2000);

    // The weekly timetable of every class
    d.openPage(Feature::WeeklySchedule);
    d.say(QStringLiteral("schedule.week"));
    d.pause(3000);
    d.click(button(d, "previousWeekButton"));
    d.pause(2200);
    d.click(d.buttonWithText("TimetablePage", "This week"));
    d.pause(1500);

    // Grade book and learning results
    d.openPage(Feature::Grades);
    d.say(QStringLiteral("grades.book"));
    d.choose(d.find<QComboBox>(QStringLiteral("classCombo")), QStringLiteral("CL0003"));
    d.pause(3600);
    visit(d, Feature::LearningResults, "grades.results", 1200);
    signOut(d);
}

void accountant(Director& d, const DemoSettings& settings) {
    chapterCard(d, "accountant");
    signIn(d, settings, QStringLiteral("kt_minh"));
    d.openPage(Feature::Students);
    d.say(QStringLiteral("accountant.readonly")); // no Add / Edit / Delete buttons
    d.pause(3600);

    // Collect a payment: the receipt is recorded and a trigger recomputes what the student has paid
    d.openPage(Feature::Tuition);
    d.say(QStringLiteral("tuition.history"));
    d.pause(2400);
    d.say(QStringLiteral("tuition.collect"));
    openDialogWith(d, "collectButton");
    d.pause(800);
    d.selectRow(d.find<QTableView>(QStringLiteral("outstandingTable")), 0);
    d.pause(1800);
    auto* amount = d.find<QDoubleSpinBox>(QStringLiteral("amountEdit"));
    QLineEdit* amountText = nullptr;
    d.gui([&] { amountText = amount->findChild<QLineEdit*>(); });
    d.type(amountText, QStringLiteral("500000"), 80, true);
    d.pause(900);
    d.click(d.dialogButton(QDialogButtonBox::Save));
    d.waitForDialogOfType("QMessageBox"); // "Receipt ... was recorded. Print it now?"
    d.pause(1500);
    d.click(d.dialogButton(QDialogButtonBox::Yes));
    d.waitForDialogOfType("ReportPreviewDialog"); // the print preview of the A5 receipt
    d.say(QStringLiteral("tuition.receipt"));
    d.pause(4200);
    d.closeDialog();
    d.say(QStringLiteral("tuition.cancel"));
    openDialogWith(d, "cancelReceiptButton");
    d.type(d.find<QLineEdit>(QStringLiteral("reasonEdit")), QStringLiteral("Demo - nhập nhầm"));
    d.pause(600);
    d.click(d.dialogButton(QDialogButtonBox::Save));
    d.waitForDialog(false);
    d.pause(2600);

    // Outstanding tuition: print preview grouped by class, with a subtotal per group
    d.openPage(Feature::OutstandingTuition);
    d.say(QStringLiteral("outstanding.list"));
    d.pause(3000);
    d.say(QStringLiteral("outstanding.preview"));
    DataTable* outstanding = d.list(); // the column to group by, read before the preview opens over the page
    int classColumn = -1;
    d.gui([&] {
        for (int c = 0; c < outstanding->visibleModel().columnCount(); ++c)
            if (outstanding->visibleModel().headerData(c, Qt::Horizontal, Columns::KeyRole).toString() ==
                QLatin1String("ClassName"))
                classColumn = c;
    });
    if (classColumn < 0)
        throw DemoError("the outstanding tuition has no class column");
    d.click(button(d, "reportPreviewButton"));
    d.waitForDialogOfType("ReportPreviewDialog");
    d.pause(1500);
    d.choose(d.find<QComboBox>(QStringLiteral("groupByCombo")), classColumn);
    d.pause(4200);
    d.closeDialog();

    visit(d, Feature::Revenue, "revenue.month", 1200);
    d.chooseIndex(d.find<QComboBox>(QStringLiteral("revenueViewCombo")), 1);
    d.say(QStringLiteral("revenue.course"));
    d.pause(3200);
    visit(d, Feature::Payroll, "payroll.list", 1200);
    signOut(d);
}

void teacher(Director& d, const DemoSettings& settings) {
    chapterCard(d, "teacher");
    signIn(d, settings, QStringLiteral("gv_john"));
    d.say(QStringLiteral("teacher.menu"));
    d.pause(2800);

    d.openPage(Feature::MyClasses);
    d.say(QStringLiteral("teacher.classes"));
    d.pause(2400);
    d.selectRow(d.list()->view(), 0);
    openDialogWith(d, "studentsButton");
    d.pause(3200);
    d.closeDialog();

    // Attendance of a session of this week
    d.openPage(Feature::MyTeachingSchedule);
    d.say(QStringLiteral("teacher.schedule"));
    d.pause(2600);
    d.selectRow(d.list()->view(), 0);
    d.say(QStringLiteral("teacher.attendance"));
    openDialogWith(d, "attendanceButton");
    d.pause(1800);
    auto* grid = d.find<QTableWidget>(QStringLiteral("attendanceTable"));
    QComboBox* firstStatus = nullptr;
    d.gui([&] { firstStatus = qobject_cast<QComboBox*>(grid->cellWidget(0, 2)); });
    if (!firstStatus)
        throw DemoError("the attendance table has no status box");
    d.chooseIndex(firstStatus, firstStatus->count() - 1);
    d.pause(1200);
    d.click(button(d, "saveAttendanceButton"));
    d.waitForDialog(false);
    d.pause(1500);

    d.openPage(Feature::MyGrades);
    d.say(QStringLiteral("teacher.grades"));
    d.choose(d.find<QComboBox>(QStringLiteral("classCombo")), QStringLiteral("CL0003"));
    d.pause(3600);
    visit(d, Feature::MyPay, "teacher.pay", 1200);
}

void language(Director& d, const DemoSettings&) {
    d.card(QStringLiteral("card.language.title"), QStringLiteral("card.language.subtitle"), 2800);
    if (d.loginShown())
        throw DemoError("the language chapter follows a chapter that stays signed in");
    auto* languages = d.find<QComboBox>(QStringLiteral("languageCombo"));
    d.say(QStringLiteral("language.switch"));
    d.pause(1500);
    d.choose(languages, QStringLiteral("en"));
    d.waitForMainWindow();
    d.pause(4200);
    d.say(QStringLiteral("language.back"));
    d.choose(d.find<QComboBox>(QStringLiteral("languageCombo")), QStringLiteral("vi"));
    d.waitForMainWindow();
    d.pause(2200);
}

void outro(Director& d, const DemoSettings&) {
    d.card(QStringLiteral("card.outro.title"), QStringLiteral("card.outro.subtitle"), 4200, {}, false);
}

const QList<QPair<QString, Chapter>>& chapters() {
    static const QList<QPair<QString, Chapter>> all = {
        {QStringLiteral("intro"), intro},           {QStringLiteral("login"), login},
        {QStringLiteral("manager"), manager},       {QStringLiteral("staff"), staff},
        {QStringLiteral("accountant"), accountant}, {QStringLiteral("teacher"), teacher},
        {QStringLiteral("language"), language},     {QStringLiteral("outro"), outro},
    };
    return all;
}
} // namespace

bool validChapters(const QStringList& wanted, QString* error) {
    for (const QString& name : wanted) {
        bool known = false;
        for (const auto& chapter : chapters())
            known = known || chapter.first == name;
        if (!known) {
            *error = QStringLiteral("unknown chapter \"%1\"").arg(name);
            return false;
        }
    }
    return true;
}

void runScenario(Director& d, const DemoSettings& settings) {
    for (const auto& chapter : chapters())
        if (settings.chapters.isEmpty() || settings.chapters.contains(chapter.first))
            chapter.second(d, settings);
    d.sayNothing();
}
