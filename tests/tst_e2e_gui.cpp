// End-to-end tests through the GUI with a real database: typing and clicking on the application's own
// screens. Needs the QLTTTA database loaded with the seed data. SKIPPED unless these environment variables
// are set:
//   QLTTTA_E2E_PASSWORD  shared password of the demo accounts (docs/SETUP.md)
//   QLTTTA_SERVER        SQL Server address (default localhost,1433)
// Run: QLTTTA_E2E_PASSWORD='...' ctest --preset macos-debug -R e2e --output-on-failure
// The scenarios run in Vietnamese (the default UI language);
// language_switchToEnglish_rebuildsUi covers English.
// What it covers: login, the menu of every role and every feature it may open (with data), add/edit/delete
// of a student, the business forms (edit a class, put an enrollment on hold and resume it, take the
// attendance of a session), the totals line and the quick filter, PDF/CSV export, the password dialog,
// switching the language. Data changed by a test is restored at its end, because the other tests rely on the
// seed data.
// Qt Test tools used below:
// - QTRY_VERIFY / QTRY_COMPARE[_WITH_TIMEOUT]: repeat the check while processing events until it is true
//   or the timeout (default 5 s) runs out. Pages load their data through the event loop, so a single check
//   would come too early; no fixed QTest::qWait is needed.
// - QTimer::singleShot(300, ...) before a click that opens a modal dialog: exec() blocks the test until the
//   dialog closes, so the code that fills and closes the dialog is scheduled first and runs inside it.
// - MessageBoxCatcher: records and closes every message box, so an unexpected error box fails the test
//   instead of blocking it.
// - typeText: types Vietnamese letters (QTest::keyClicks converts each character to Latin-1, which has no
//   code for most of them).
// - *_data() function: a data-driven test. QTest::addColumn/newRow build a table; the test with the same
//   name runs once per row and reads the values with QFETCH.
// - QSignalSpy: counts how often a signal was emitted.
#include "app/AppContainer.h"
#include "application/services/Permissions.h"
#include "presentation/common/Columns.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableExporter.h"
#include "presentation/common/Theme.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/ChangePasswordDialog.h"
#include "presentation/main/MainWindow.h"

#include <QAbstractButton>
#include <QApplication>
#include <QComboBox>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QFileInfo>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QSignalSpy>
#include <QStackedWidget>
#include <QTableView>
#include <QTableWidget>
#include <QTemporaryDir>
#include <QTimer>
#include <QtTest>
#include <memory>

namespace {
// Types character by character (including Vietnamese letters), like an input method sending text key events
void typeText(QWidget* target, const QString& text) {
    for (const QChar c : text)
        QTest::sendKeyEvent(QTest::Click, target, Qt::Key_unknown, QString(c), Qt::NoModifier);
}

// Widget tagged with setProperty("testId", ...)
template <typename T> T* findByTestId(QWidget* root, const QString& testId) {
    for (T* w : root->findChildren<T*>())
        if (w->property("testId").toString() == testId)
            return w;
    return nullptr;
}

template <typename T> T* findVisibleByTestId(QWidget* root, const QString& testId) {
    for (T* w : root->findChildren<T*>())
        if (w->isVisible() && w->property("testId").toString() == testId)
            return w;
    return nullptr;
}

QStringList visibleMenu(MainWindow& w) {
    QStringList names;
    auto* nav = w.findChild<QListWidget*>(QStringLiteral("NavList"));
    for (int i = 0; nav && i < nav->count(); ++i)
        if (nav->item(i)->data(Qt::UserRole).toInt() >= 0)
            names << nav->item(i)->text();
    return names;
}

QStringList expectedMenu(Role role) {
    QStringList names;
    for (Feature f : Permissions::allowedFeatures(role))
        names << Labels::feature(f).name;
    return names;
}

// Right after opening, the main window shows the first feature (not a group header) and its page title
bool opensFirstFeature(MainWindow& w, Role role) {
    auto* nav = w.findChild<QListWidget*>(QStringLiteral("NavList"));
    auto* title = w.findChild<QLabel*>(QStringLiteral("HeaderTitle"));
    const Feature first = Permissions::allowedFeatures(role).first();
    return nav && nav->currentItem() &&
           nav->currentItem()->data(Qt::UserRole).toInt() == static_cast<int>(first) && title &&
           title->text() == Labels::feature(first).name;
}

// Catches every message box shown during a test: records its text and closes it,
// so the test never hangs and we know which screen reported an error. answerYes: a confirmation question
// (Yes / No, UiHelpers::confirm) is answered Yes and recorded in questions() instead of texts().
class MessageBoxCatcher {
public:
    explicit MessageBoxCatcher(bool answerYes = false) {
        m_timer.setInterval(100);
        QObject::connect(&m_timer, &QTimer::timeout, [this, answerYes] {
            if (auto* box = qobject_cast<QMessageBox*>(QApplication::activeModalWidget())) {
                if (QAbstractButton* yes = box->button(QMessageBox::Yes); answerYes && yes) {
                    m_questions << box->text();
                    yes->click();
                    return;
                }
                m_texts << box->text();
                box->done(0);
            }
        });
        m_timer.start();
    }
    const QStringList& texts() const { return m_texts; }
    const QStringList& questions() const { return m_questions; }

private:
    QTimer m_timer;
    QStringList m_texts;
    QStringList m_questions;
};

// Column with the given key (header Columns::KeyRole), -1 if absent
int columnByKey(const QAbstractItemModel* model, const QString& key) {
    for (int c = 0; c < model->columnCount(); ++c)
        if (model->headerData(c, Qt::Horizontal, Columns::KeyRole).toString() == key)
            return c;
    return -1;
}

// Table (QTableView) visible on the current page of the main window
QTableView* visibleTable(MainWindow& w, const QString& name) {
    for (QTableView* t : w.findChildren<QTableView*>(name))
        if (t->isVisible())
            return t;
    return nullptr;
}

// The main list of the page shown (a DataPage), to read and select rows by column key
DataTable* visibleList(MainWindow& w) {
    for (DataTable* t : w.findChildren<DataTable*>())
        if (t->isVisible() && t->view()->objectName() == QStringLiteral("listTable"))
            return t;
    return nullptr;
}

// Button of the page shown: the pages opened before stay in the window, hidden
QPushButton* visibleButton(MainWindow& w, const QString& name) {
    for (QPushButton* b : w.findChildren<QPushButton*>(name))
        if (b->isVisible())
            return b;
    return nullptr;
}

// Any widget of the page shown with that object name (the same rule as visibleButton)
template <typename T> T* visibleChild(MainWindow& w, const QString& name) {
    for (T* child : w.findChildren<T*>(name))
        if (child->isVisible())
            return child;
    return nullptr;
}
} // namespace

class TestE2EGui : public QObject {
    Q_OBJECT

private:
    // The real application wiring (repositories, services) as in main.cpp
    std::unique_ptr<AppContainer> m_app;
    QString m_password;

    // Logs in by typing into the LoginDialog and clicking "Sign in"
    bool login(const QString& username, const QString& password, QString* error = nullptr) {
        LoginDialog dialog(m_app->auth(), m_app->language());
        dialog.show();
        auto* usernameEdit = dialog.findChild<QLineEdit*>(QStringLiteral("usernameEdit"));
        auto* passwordEdit = dialog.findChild<QLineEdit*>(QStringLiteral("passwordEdit"));
        auto* button = dialog.findChild<QPushButton*>(QStringLiteral("loginButton"));
        if (!usernameEdit || !passwordEdit || !button)
            return false;
        usernameEdit->clear();
        passwordEdit->clear();
        QTest::keyClicks(usernameEdit, username);
        QTest::keyClicks(passwordEdit, password);
        QTest::mouseClick(button, Qt::LeftButton);
        if (error) {
            auto* label = findByTestId<QLabel>(&dialog, QStringLiteral("loginError"));
            *error = (label && !label->isHidden()) ? label->text() : QString();
        }
        return dialog.result() == QDialog::Accepted;
    }

    void useVietnamese() {
        m_app->language().select(Language::Vietnamese);
        I18n::apply(Language::Vietnamese);
    }

private slots:
    // Runs once before the first test: without a password the whole suite is skipped (QSKIP)
    void initTestCase() {
        m_password = qEnvironmentVariable("QLTTTA_E2E_PASSWORD");
        if (m_password.isEmpty())
            QSKIP("QLTTTA_E2E_PASSWORD is not set - skipping the GUI tests against a real database.");
        QApplication::setOrganizationName(
            QStringLiteral("UIT-IE103-E2E")); // keep the real settings untouched
        m_app = std::make_unique<AppContainer>();
        ServerConfig config;
        config.host = qEnvironmentVariable("QLTTTA_SERVER", QStringLiteral("localhost,1433"));
        m_app->auth().saveServerConfig(config);
        useVietnamese();
    }

    // Runs after every test: sign out and back to Vietnamese, so each test starts from the same state
    void cleanup() {
        if (!m_app)
            return;
        m_app->auth().logout();
        if (I18n::current() != Language::Vietnamese)
            useVietnamese();
    }

    void login_wrongPassword_showsError() {
        QString error;
        QVERIFY(!login(QStringLiteral("gvu_lan"), QStringLiteral("wrong-password-123"), &error));
        QVERIFY2(error.contains(QStringLiteral("Sai tên đăng nhập")), qPrintable(error));
        QVERIFY(!m_app->auth().isLoggedIn());
    }

    // Main flow of the Students module as academic staff: menu of the role, hidden revenue, search, add with
    // the guardian rule (first save refused), then delete the new student again
    void academicStaff_searchAddDeleteStudent() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        QCOMPARE(m_app->auth().role(), Role::AcademicStaff);

        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(visibleMenu(w), expectedMenu(Role::AcademicStaff));
        QVERIFY(opensFirstFeature(w, Role::AcademicStaff));
        // Academic staff may not see revenue: the database returns NULL,
        // the KPI card says "Không có quyền" (no permission)
        auto* revenueKpi = findByTestId<QLabel>(&w, QStringLiteral("revenueKpi"));
        QVERIFY(revenueKpi);
        QCOMPARE(revenueKpi->text(), QStringLiteral("Không có quyền"));

        w.openFeature(Feature::Students);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("studentTable"))) != nullptr);
        QTRY_VERIFY(table->model()->rowCount() >= 72);

        // Search (runs 300 ms after the user stops typing)
        auto* search = w.findChild<QLineEdit*>(QStringLiteral("searchEdit"));
        QVERIFY(search);
        typeText(search, QStringLiteral("Ngô Khánh"));
        QTRY_COMPARE_WITH_TIMEOUT(table->model()->rowCount(), 1, 3000);
        QCOMPARE(table->model()->index(0, 1).data().toString(), QStringLiteral("Ngô Khánh Linh"));

        // Add a 10-year-old student: first save fails (no guardian), second save with a guardian succeeds
        QString firstError;
        bool formOpened = false;
        QTimer::singleShot(300, this, [&] {
            auto* dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
            if (!dialog)
                return;
            formOpened = true;
            dialog->findChild<QLineEdit*>(QStringLiteral("fullNameEdit"))
                ->setText(QStringLiteral("Bé Kiểm Thử E2E"));
            dialog->findChild<QDateEdit*>(QStringLiteral("dateOfBirthEdit"))
                ->setDate(QDate::currentDate().addYears(-10));
            auto* save = dialog->findChild<QDialogButtonBox*>(QStringLiteral("buttonBox"))
                             ->button(QDialogButtonBox::Save);
            save->click();
            for (QLabel* l : dialog->findChildren<QLabel*>(QStringLiteral("ErrorText")))
                if (!l->isHidden())
                    firstError = l->text();
            dialog->findChild<QLineEdit*>(QStringLiteral("guardianNameEdit"))
                ->setText(QStringLiteral("Phụ Huynh E2E"));
            dialog->findChild<QLineEdit*>(QStringLiteral("guardianPhoneEdit"))
                ->setText(QStringLiteral("0987000111"));
            save->click();
            if (dialog->isVisible())
                dialog->reject(); // never hang if saving failed
        });
        search->clear();
        QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("addButton")), Qt::LeftButton);
        QVERIFY(formOpened);
        QVERIFY2(firstError.contains(QStringLiteral("phụ huynh")), qPrintable(firstError));

        typeText(search, QStringLiteral("Kiểm Thử E2E"));
        QTRY_COMPARE_WITH_TIMEOUT(table->model()->rowCount(), 1, 3000);
        const QString newId = table->model()->index(0, 0).data().toString();
        QVERIFY2(newId.startsWith(QStringLiteral("ST")), qPrintable(newId));

        // Delete the new student (confirm with Yes)
        table->selectRow(0);
        QTimer::singleShot(300, this, [] {
            if (auto* box = qobject_cast<QMessageBox*>(QApplication::activeModalWidget()))
                box->button(QMessageBox::Yes)->click();
        });
        QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("deleteButton")), Qt::LeftButton);
        QTRY_COMPARE_WITH_TIMEOUT(table->model()->rowCount(), 0, 3000);
    }

    // Search with a tone mark that code page 1258 has no precomposed letter for ("ồ"): the keyword must reach
    // SQL Server as Unicode with every ODBC driver (through FreeTDS it used to arrive as VARCHAR => no match)
    void academicStaff_searchWithToneMarks_findsStudent() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::Students);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("studentTable"))) != nullptr);
        auto* search = w.findChild<QLineEdit*>(QStringLiteral("searchEdit"));
        QVERIFY(search);
        typeText(search, QStringLiteral("Hồ Minh Quân"));
        QTRY_COMPARE_WITH_TIMEOUT(table->model()->rowCount(), 1, 3000);
        QCOMPARE(table->model()->index(0, 0).data().toString(), QStringLiteral("ST00054"));
    }

    void teacher_seesOnlyOwnClasses() {
        QVERIFY(login(QStringLiteral("gv_john"), m_password));
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(visibleMenu(w), expectedMenu(Role::Teacher));
        QVERIFY(opensFirstFeature(w, Role::Teacher));

        w.openFeature(Feature::MyClasses);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        QCOMPARE(table->model()->rowCount(), 2); // TE0001 teaches CL0003 and CL0008
        // Database values (English) are shown in the UI language
        const int statusColumn = columnByKey(table->model(), QStringLiteral("Status"));
        QVERIFY(statusColumn >= 0);
        const QModelIndex status = table->model()->index(0, statusColumn);
        const QString stored = status.data(Qt::UserRole).toString();
        QCOMPARE(status.data().toString(), DbValues::label(stored));
        QVERIFY2(status.data().toString() != stored, qPrintable(stored));

        w.openFeature(Feature::MyTeachingSchedule);
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        QVERIFY(table->model()->rowCount() > 0);
        const int classColumn = columnByKey(table->model(), QStringLiteral("ClassId"));
        QVERIFY(classColumn >= 0);
        for (int r = 0; r < table->model()->rowCount(); ++r) {
            const QString classCode = table->model()->index(r, classColumn).data().toString();
            QVERIFY2(classCode == QStringLiteral("CL0003") || classCode == QStringLiteral("CL0008"),
                     qPrintable(classCode));
        }
    }

    // Accountant: revenue visible, students read-only, outstanding tuition with totals, PDF/CSV export
    void accountant_outstandingTuition_exportsPdf() {
        QVERIFY(login(QStringLiteral("kt_minh"), m_password));
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(visibleMenu(w), expectedMenu(Role::Accountant));
        QVERIFY(opensFirstFeature(w, Role::Accountant));
        auto* revenueKpi = findByTestId<QLabel>(&w, QStringLiteral("revenueKpi"));
        QVERIFY(revenueKpi);
        QVERIFY2(revenueKpi->text().at(0).isDigit(), qPrintable(revenueKpi->text())); // e.g. "5.000.000 ₫"

        // Accountants can only view students: Add/Edit/Delete are hidden
        w.openFeature(Feature::Students);
        QTRY_VERIFY(visibleTable(w, QStringLiteral("studentTable")) != nullptr);
        QVERIFY(w.findChild<QPushButton*>(QStringLiteral("addButton"))->isHidden());

        w.openFeature(Feature::OutstandingTuition);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        QVERIFY(table->model()->rowCount() > 0);
        auto* totals = findVisibleByTestId<QLabel>(&w, QStringLiteral("totalsLine"));
        QVERIFY(totals);
        QVERIFY2(totals->text().contains(QStringLiteral("Tổng còn nợ")), qPrintable(totals->text()));

        QTemporaryDir folder;
        const QString pdf = folder.filePath(QStringLiteral("outstanding.pdf"));
        QString error;
        QVERIFY2(TableExporter::exportPdf(*table->model(), QStringLiteral("Công nợ học phí"),
                                          QStringLiteral("Kế toán"), pdf, &error),
                 qPrintable(error));
        QVERIFY(QFileInfo(pdf).size() > 2000);
        QVERIFY(TableExporter::exportCsv(*table->model(), folder.filePath(QStringLiteral("outstanding.csv")),
                                         &error));
    }

    // Different new password and confirmation: the dialog shows the error and stays open
    void changePassword_mismatch_showsError() {
        QVERIFY(login(QStringLiteral("gvu_ha"), m_password));
        ChangePasswordDialog dialog(m_app->auth());
        dialog.show();
        const auto edits = dialog.findChildren<QLineEdit*>();
        QCOMPARE(edits.size(), 3);
        QTest::keyClicks(edits[0], m_password);
        QTest::keyClicks(edits[1], QStringLiteral("NewPassword@1"));
        QTest::keyClicks(edits[2], QStringLiteral("Different@2"));
        dialog.findChild<QDialogButtonBox*>()->button(QDialogButtonBox::Save)->click();
        QVERIFY(dialog.isVisible()); // stays open because of the error
        bool hasError = false;
        for (QLabel* l : dialog.findChildren<QLabel*>(QStringLiteral("ErrorText")))
            hasError = hasError || (!l->isHidden() && l->text().contains(QStringLiteral("không khớp")));
        QVERIFY(hasError);
    }

    // Wrong current password: SQL Server rejects ALTER USER ... OLD_PASSWORD, the procedure reports it in
    // English and the UI shows it in Vietnamese (DbMessages catalog)
    void changePassword_wrongCurrentPassword_showsError() {
        QVERIFY(login(QStringLiteral("gvu_ha"), m_password));
        ChangePasswordDialog dialog(m_app->auth());
        dialog.show();
        const auto edits = dialog.findChildren<QLineEdit*>();
        QCOMPARE(edits.size(), 3);
        QTest::keyClicks(edits[0], QStringLiteral("WrongPassword@1"));
        QTest::keyClicks(edits[1], QStringLiteral("NewPassword@1"));
        QTest::keyClicks(edits[2], QStringLiteral("NewPassword@1"));
        dialog.findChild<QDialogButtonBox*>()->button(QDialogButtonBox::Save)->click();
        QVERIFY(dialog.isVisible());
        QString error;
        for (QLabel* l : dialog.findChildren<QLabel*>(QStringLiteral("ErrorText")))
            if (!l->isHidden())
                error = l->text();
        QCOMPARE(error, QStringLiteral("Mật khẩu hiện tại không đúng."));
    }

    // Every role opens EVERY allowed feature: right title, data present, no error, every column has a title.
    // Also catches database permission bugs (a missing GRANT in 06_security.sql leaves the page empty).
    // Data for the test below: one row per demo account (row name, username, role)
    void everyRole_opensEveryFeature_withData_data() {
        QTest::addColumn<QString>("username");
        QTest::addColumn<int>("role");
        QTest::newRow("manager") << QStringLiteral("ql_quan") << static_cast<int>(Role::Manager);
        QTest::newRow("academic_staff") << QStringLiteral("gvu_lan") << static_cast<int>(Role::AcademicStaff);
        QTest::newRow("accountant") << QStringLiteral("kt_minh") << static_cast<int>(Role::Accountant);
        QTest::newRow("teacher") << QStringLiteral("gv_john") << static_cast<int>(Role::Teacher);
    }

    void everyRole_opensEveryFeature_withData() {
        QFETCH(QString, username);
        QFETCH(int, role);
        const auto r = static_cast<Role>(role);
        QVERIFY(login(username, m_password));
        QCOMPARE(m_app->auth().role(), r);

        MessageBoxCatcher boxes;
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(visibleMenu(w), expectedMenu(r));
        auto* title = w.findChild<QLabel*>(QStringLiteral("HeaderTitle"));
        auto* content = w.findChild<QStackedWidget*>(QStringLiteral("Content"));
        QVERIFY(title && content);

        for (Feature f : Permissions::allowedFeatures(r)) {
            const QString name = Labels::feature(f).name;
            w.openFeature(f);
            QCOMPARE(title->text(), name);
            QWidget* page = content->currentWidget();
            QVERIFY(page);
            // The pages without a list: the dashboard (cards and chart) and the backup form
            if (f == Feature::Dashboard || f == Feature::Backup) {
                for (QLabel* l : page->findChildren<QLabel*>(QStringLiteral("ErrorText")))
                    QVERIFY2(l->isHidden(), qPrintable(name + QStringLiteral(": ") + l->text()));
                continue;
            }
            QTableView* table = nullptr;
            for (QTableView* t : page->findChildren<QTableView*>())
                if (t->isVisible())
                    table = t;
            QVERIFY2(table, qPrintable(name));
            QTRY_VERIFY2(table->model()->rowCount() > 0,
                         qPrintable(QStringLiteral("%1 / %2: no data").arg(username, name)));
            // Every column key returned by the database has an entry in the column catalog (Columns)
            for (int c = 0; c < table->model()->columnCount(); ++c) {
                const QString key =
                    table->model()->headerData(c, Qt::Horizontal, Columns::KeyRole).toString();
                QVERIFY2(Columns::contains(key),
                         qPrintable(QStringLiteral("%1: column %2 has no title").arg(name, key)));
            }
        }
        QVERIFY2(boxes.texts().isEmpty(), qPrintable(boxes.texts().join(QStringLiteral(" | "))));
    }

    // Academic staff edits a student's address in the form, checks it is saved, then restores it
    void academicStaff_editStudent_savesToDatabase() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::Students);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("studentTable"))) != nullptr);
        auto* search = w.findChild<QLineEdit*>(QStringLiteral("searchEdit"));
        typeText(search, QStringLiteral("ST00010"));
        QTRY_COMPARE_WITH_TIMEOUT(table->model()->rowCount(), 1, 3000);

        // Opens the Edit form, changes the Address field and saves; false if the form did not open or close
        auto editAddress = [&](const QString& newAddress, QString* oldAddress) {
            bool saved = false;
            QTimer::singleShot(300, this, [&] {
                auto* dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
                if (!dialog)
                    return;
                auto* field = dialog->findChild<QLineEdit*>(QStringLiteral("addressEdit"));
                if (oldAddress)
                    *oldAddress = field->text();
                field->setText(newAddress);
                dialog->findChild<QDialogButtonBox*>(QStringLiteral("buttonBox"))
                    ->button(QDialogButtonBox::Save)
                    ->click();
                saved = !dialog->isVisible();
                if (dialog->isVisible())
                    dialog->reject(); // never hang if saving failed
            });
            table->selectRow(0);
            QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("editButton")), Qt::LeftButton);
            return saved;
        };

        const QString newAddress = QStringLiteral("Số 1 đường Kiểm Thử E2E, TP. Thủ Đức");
        QString oldAddress;
        QVERIFY(editAddress(newAddress, &oldAddress));
        auto details = m_app->services().students.details(QStringLiteral("ST00010"));
        QVERIFY2(details.ok(), qPrintable(details.error()));
        QCOMPARE(details.value().address, newAddress);

        QVERIFY(editAddress(oldAddress, nullptr)); // restore the seed data
        details = m_app->services().students.details(QStringLiteral("ST00010"));
        QVERIFY(details.ok());
        QCOMPARE(details.value().address, oldAddress);
    }

    // Classes screen: academic staff renames a class in progress in the class form (usp_Class_Update, which
    // also checks the timetable again), sees the new name in the list, then restores it
    void academicStaff_editClass_savesToDatabase() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        MessageBoxCatcher boxes;
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::Classes);
        DataTable* list = nullptr;
        QTRY_VERIFY((list = visibleList(w)) != nullptr);
        QTRY_VERIFY(list->rowCount() > 0);
        const QString classId = QStringLiteral("CL0003");

        // Opens the Edit form of the class, changes its name and saves; false if the form did not close
        auto rename = [&](const QString& newName, QString* oldName) {
            bool saved = false;
            QTimer::singleShot(300, this, [&] {
                auto* dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
                if (!dialog)
                    return;
                auto* field = dialog->findChild<QLineEdit*>(QStringLiteral("classNameEdit"));
                if (field) {
                    if (oldName)
                        *oldName = field->text();
                    field->setText(newName);
                    dialog->findChild<QDialogButtonBox*>(QStringLiteral("buttonBox"))
                        ->button(QDialogButtonBox::Save)
                        ->click();
                    saved = !dialog->isVisible();
                }
                if (dialog->isVisible())
                    dialog->reject(); // never hang if saving failed
            });
            if (!list->selectWhere(QStringLiteral("ClassId"), classId))
                return false;
            QTest::mouseClick(visibleButton(w, QStringLiteral("editButton")), Qt::LeftButton);
            return saved;
        };

        const QString newName = QStringLiteral("Lớp Kiểm Thử E2E");
        QString oldName;
        QVERIFY(rename(newName, &oldName));
        QVERIFY(!oldName.isEmpty());
        auto details = m_app->services().classes.details(classId);
        QVERIFY2(details.ok(), qPrintable(details.error()));
        QCOMPARE(details.value().name, newName);
        QTRY_COMPARE(list->selectedValue(QStringLiteral("ClassName")).toString(), newName);

        QVERIFY(rename(oldName, nullptr)); // restore the seed data
        details = m_app->services().classes.details(classId);
        QVERIFY(details.ok());
        QCOMPARE(details.value().name, oldName);
        QVERIFY2(boxes.texts().isEmpty(), qPrintable(boxes.texts().join(QStringLiteral(" | "))));
    }

    // Enrollments screen: academic staff puts a Studying enrollment on hold, then resumes it
    // (usp_Enrollment_UpdateStatus; resuming checks the timetable clash again). Each step asks for a
    // confirmation; the list is read again from the database after each step.
    void academicStaff_putOnHoldAndResume_updatesEnrollment() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        MessageBoxCatcher boxes(true);
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::Enrollments);
        DataTable* list = nullptr;
        QTRY_VERIFY((list = visibleList(w)) != nullptr);
        QTRY_VERIFY(list->rowCount() > 0);
        QString enrollmentId;
        for (int r = 0; r < list->rowCount() && enrollmentId.isEmpty(); ++r)
            if (list->valueAt(r, QStringLiteral("Status")).toString() == EnrollmentValues::studying())
                enrollmentId = list->valueAt(r, QStringLiteral("EnrollmentId")).toString();
        QVERIFY2(!enrollmentId.isEmpty(), "no Studying enrollment in the seed data");

        QVERIFY(list->selectWhere(QStringLiteral("EnrollmentId"), enrollmentId));
        QTest::mouseClick(visibleButton(w, QStringLiteral("holdButton")), Qt::LeftButton);
        QTRY_COMPARE(list->selectedValue(QStringLiteral("EnrollmentId")).toString(), enrollmentId);
        QTRY_COMPARE(list->selectedValue(QStringLiteral("Status")).toString(), EnrollmentValues::onHold());

        QTest::mouseClick(visibleButton(w, QStringLiteral("resumeButton")), Qt::LeftButton); // restore
        QTRY_COMPARE(list->selectedValue(QStringLiteral("Status")).toString(), EnrollmentValues::studying());
        QCOMPARE(boxes.questions().size(), 2);
        QVERIFY2(boxes.texts().isEmpty(), qPrintable(boxes.texts().join(QStringLiteral(" | "))));
    }

    // New enrollment form: Return in the student search field finds the students and nothing else. QLineEdit
    // passes Return on to the dialog, whose default button would enroll the first match at once (or show the
    // error of that attempt); the form must stay open without an error and no enrollment may be added.
    void academicStaff_returnInStudentSearch_searchesWithoutEnrolling() {
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));
        MessageBoxCatcher boxes;
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::Enrollments);
        DataTable* list = nullptr;
        QTRY_VERIFY((list = visibleList(w)) != nullptr);
        QTRY_VERIFY(list->rowCount() > 0);
        const auto before = m_app->services().enrollments.search(EnrollmentFilter());
        QVERIFY2(before.ok(), qPrintable(before.error()));

        bool stayedOpen = false;
        bool errorShown = true;
        int matches = 0;
        QTimer::singleShot(300, this, [&] {
            auto* dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
            if (!dialog)
                return;
            auto* search = dialog->findChild<QLineEdit*>(QStringLiteral("studentSearchEdit"));
            auto* students = dialog->findChild<QComboBox*>(QStringLiteral("studentCombo"));
            auto* error = dialog->findChild<QLabel*>(QStringLiteral("ErrorText"));
            if (search && students && error) {
                search->setFocus();
                QTest::keyClicks(search, QStringLiteral("ST0000"));
                QTest::keyClick(search, Qt::Key_Return);
                stayedOpen = dialog->isVisible();
                errorShown = !error->isHidden();
                matches = students->count();
            }
            if (dialog->isVisible())
                dialog->reject(); // never hang
        });
        QTest::mouseClick(visibleButton(w, QStringLiteral("addButton")), Qt::LeftButton);
        QVERIFY2(stayedOpen, "Return in the search field closed the form");
        QVERIFY2(!errorShown, "Return in the search field tried to save the enrollment");
        QVERIFY(matches > 0);
        const auto after = m_app->services().enrollments.search(EnrollmentFilter());
        QVERIFY2(after.ok(), qPrintable(after.error()));
        QCOMPARE(after.value().rows.size(), before.value().rows.size());
        QVERIFY2(boxes.texts().isEmpty(), qPrintable(boxes.texts().join(QStringLiteral(" | "))));
    }

    // Teaching schedule: a teacher changes the attendance of one student at a session they taught
    // (usp_Attendance_Save), checks it is saved, then restores it. Only a session whose marks are all saved
    // is used, so saving creates no new row; early in the week it is found in the previous week.
    void teacher_takeAttendance_savesToDatabase() {
        QVERIFY(login(QStringLiteral("gv_john"), m_password));
        MessageBoxCatcher boxes;
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::MyTeachingSchedule);
        DataTable* list = nullptr;
        QTRY_VERIFY((list = visibleList(w)) != nullptr);
        QTRY_VERIFY(list->rowCount() > 0);
        int sessionId = 0;
        for (int week = 0; week < 2 && sessionId == 0; ++week) {
            if (week > 0)
                QTest::mouseClick(visibleButton(w, QStringLiteral("previousWeekButton")), Qt::LeftButton);
            for (int r = 0; r < list->rowCount() && sessionId == 0; ++r) {
                const int id = list->valueAt(r, QStringLiteral("SessionId")).toInt();
                const auto marks = m_app->services().sessions.attendance(id);
                if (!marks.ok() || marks.value().isEmpty())
                    continue;
                bool allSaved = true;
                for (const AttendanceMark& m : marks.value())
                    allSaved = allSaved && m.saved;
                if (allSaved)
                    sessionId = id;
            }
        }
        QVERIFY2(sessionId != 0, "no session of this week or the previous one has its attendance saved");

        // Opens the attendance of the session, sets the first student to that status and saves. Before that,
        // Return in the Notes cell must keep a mark that is not Present (no "All present" click); checked
        // after the data is restored.
        bool keptOnReturn = true;
        auto mark = [&](const QString& status, QString* oldStatus) {
            bool saved = false;
            QTimer::singleShot(300, this, [&] {
                auto* dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
                if (!dialog)
                    return;
                auto* grid = dialog->findChild<QTableWidget*>(QStringLiteral("attendanceTable"));
                auto* combo = grid ? qobject_cast<QComboBox*>(grid->cellWidget(0, 2)) : nullptr;
                auto* notes = grid ? qobject_cast<QLineEdit*>(grid->cellWidget(0, 3)) : nullptr;
                if (combo && notes) {
                    if (oldStatus)
                        *oldStatus = combo->currentData().toString();
                    const QString absent = AttendanceValues::statuses().constLast();
                    combo->setCurrentIndex(combo->findData(absent));
                    notes->setFocus();
                    QTest::keyClick(notes, Qt::Key_Return);
                    keptOnReturn =
                        keptOnReturn && dialog->isVisible() && combo->currentData().toString() == absent;
                    combo->setCurrentIndex(combo->findData(status));
                    dialog->findChild<QPushButton*>(QStringLiteral("saveAttendanceButton"))->click();
                    saved = !dialog->isVisible();
                }
                if (dialog->isVisible())
                    dialog->reject(); // never hang if saving failed
            });
            if (!list->selectWhere(QStringLiteral("SessionId"), sessionId))
                return false;
            QTest::mouseClick(visibleButton(w, QStringLiteral("attendanceButton")), Qt::LeftButton);
            return saved;
        };
        auto firstStatus = [&] {
            const auto marks = m_app->services().sessions.attendance(sessionId);
            return marks.ok() && !marks.value().isEmpty() ? marks.value().first().status : QString();
        };

        const QString before = firstStatus();
        QString changed; // any other stored status
        for (const QString& s : AttendanceValues::statuses())
            if (changed.isEmpty() && s != before)
                changed = s;
        QString oldStatus;
        QVERIFY(mark(changed, &oldStatus));
        QCOMPARE(oldStatus, before);
        QCOMPARE(firstStatus(), changed);

        QVERIFY(mark(before, nullptr)); // restore the seed data
        QCOMPARE(firstStatus(), before);
        QVERIFY2(keptOnReturn, "Return in the Notes cell changed the mark");
        QVERIFY2(boxes.texts().isEmpty(), qPrintable(boxes.texts().join(QStringLiteral(" | "))));
    }

    // My grade book: the score editor takes 0-10 only. 11 is not taken as a change and the footer says why
    // (before, a cell with a score opened an unbounded spin box and the value was dropped without a word).
    // Nothing is saved, so no data needs restoring.
    void teacher_gradeBookScoreAbove10_isRefusedWithMessage() {
        QVERIFY(login(QStringLiteral("gv_john"), m_password));
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::MyGrades);
        QString classId;
        const auto classes = m_app->services().grades.classes(true);
        QVERIFY2(classes.ok(), qPrintable(classes.error()));
        for (const ClassOption& c : classes.value())
            if (classId.isEmpty() && c.status == ClassValues::inProgress())
                classId = c.id;
        QVERIFY2(!classId.isEmpty(), "gv_john teaches no class in progress");

        QComboBox* combo = nullptr;
        QTableView* view = nullptr;
        QLabel* footer = nullptr;
        QTRY_VERIFY((combo = visibleChild<QComboBox>(w, QStringLiteral("classCombo"))) != nullptr);
        combo->setCurrentIndex(combo->findData(classId));
        QTRY_VERIFY((view = visibleChild<QTableView>(w, QStringLiteral("listTable"))) != nullptr);
        QTRY_VERIFY(view->model()->rowCount() > 0);
        for (QLabel* l : w.findChildren<QLabel*>())
            if (l->isVisible() && l->property("testId").toString() == QStringLiteral("totalsLine"))
                footer = l;
        QVERIFY(footer != nullptr);

        const QModelIndex cell = view->model()->index(0, 2); // the first grade component
        QVERIFY(view->model()->flags(cell) & Qt::ItemIsEditable);
        const QString before = cell.data().toString();
        view->setCurrentIndex(cell);
        view->edit(cell);
        QLineEdit* editor = nullptr;
        QTRY_VERIFY((editor = view->viewport()->findChild<QLineEdit*>()) != nullptr);
        editor->setText(QStringLiteral("11"));
        QTest::keyClick(editor, Qt::Key_Return);
        QTRY_COMPARE(footer->text(),
                     QCoreApplication::translate("GradeBookPage",
                                                 "Scores are between 0 and 10, with at most 2 decimals."));
        QCOMPARE(cell.data().toString(), before);
        QTest::keyClick(editor, Qt::Key_Escape); // close the editor without saving anything
    }

    // Quick filter on outstanding tuition: only matching rows remain,
    // the totals line follows the visible rows
    void accountant_quickFilter_recomputesTotals() {
        QVERIFY(login(QStringLiteral("kt_minh"), m_password));
        MainWindow w(m_app->services());
        w.show();
        w.openFeature(Feature::OutstandingTuition);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        const int allRows = table->model()->rowCount();
        QVERIFY(allRows > 2);

        QLineEdit* filter = nullptr;
        for (QLineEdit* e : w.findChildren<QLineEdit*>(QStringLiteral("quickFilter")))
            if (e->isVisible())
                filter = e;
        QVERIFY(filter);
        typeText(filter, QStringLiteral("CL0008"));
        QTRY_VERIFY(table->model()->rowCount() > 0 && table->model()->rowCount() < allRows);

        const auto* m = table->model();
        const int classColumn = columnByKey(m, QStringLiteral("ClassId"));
        const int outstandingColumn = columnByKey(m, QStringLiteral("Balance"));
        QVERIFY(classColumn >= 0 && outstandingColumn >= 0);
        qint64 outstanding = 0;
        for (int r = 0; r < m->rowCount(); ++r) {
            QCOMPARE(m->index(r, classColumn).data().toString(), QStringLiteral("CL0008"));
            outstanding += m->index(r, outstandingColumn).data(Qt::UserRole).toLongLong();
        }
        auto* totals = findVisibleByTestId<QLabel>(&w, QStringLiteral("totalsLine"));
        QVERIFY(totals);
        QVERIFY2(totals->text().startsWith(QStringLiteral("%1 dòng").arg(m->rowCount())),
                 qPrintable(totals->text()));
        QVERIFY2(totals->text().contains(QStringLiteral("Tổng còn nợ: ") + Format::money(outstanding)),
                 qPrintable(totals->text()));
    }

    // The user picks English on the login screen: the choice is saved, the screens are rebuilt in English
    // (menu, KPI cards, column titles, database values, totals) and switching back from the header works.
    void language_switchToEnglish_rebuildsUi() {
        {
            LoginDialog dialog(m_app->auth(), m_app->language());
            dialog.show();
            auto* combo = dialog.findChild<QComboBox*>(QStringLiteral("languageCombo"));
            QVERIFY(combo);
            QCOMPARE(combo->currentData().toString(), QStringLiteral("vi"));
            combo->setCurrentIndex(combo->findData(QStringLiteral("en")));
            QCOMPARE(dialog.result(), static_cast<int>(LoginDialog::LanguageChanged));
        }
        QCOMPARE(I18n::current(), Language::English);
        QCOMPARE(m_app->language().current(), Language::English);

        QString error;
        QVERIFY(!login(QStringLiteral("gvu_lan"), QStringLiteral("wrong-password-123"), &error));
        QVERIFY2(error.startsWith(QStringLiteral("Wrong username or password")), qPrintable(error));
        QVERIFY(login(QStringLiteral("gvu_lan"), m_password));

        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(visibleMenu(w).first(), QStringLiteral("Overview"));
        QVERIFY(visibleMenu(w).contains(QStringLiteral("Students")));
        auto* revenueKpi = findByTestId<QLabel>(&w, QStringLiteral("revenueKpi"));
        QVERIFY(revenueKpi);
        QCOMPARE(revenueKpi->text(), QStringLiteral("No permission"));

        w.openFeature(Feature::Classes);
        QTableView* table = nullptr;
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        const int statusColumn = columnByKey(table->model(), QStringLiteral("Status"));
        QVERIFY(statusColumn >= 0);
        QCOMPARE(table->model()->headerData(statusColumn, Qt::Horizontal).toString(),
                 QStringLiteral("Status"));
        const QModelIndex status = table->model()->index(0, statusColumn);
        const QString stored = status.data(Qt::UserRole).toString(); // English value from the database
        QCOMPARE(status.data().toString(), stored);                  // shown as it is in English
        QCOMPARE(status.data().toString(), DbValues::label(stored));

        w.openFeature(Feature::OutstandingTuition);
        QTRY_VERIFY((table = visibleTable(w, QStringLiteral("listTable"))) != nullptr);
        auto* totals = findVisibleByTestId<QLabel>(&w, QStringLiteral("totalsLine"));
        QVERIFY(totals);
        QVERIFY2(totals->text().startsWith(QStringLiteral("%1 rows").arg(table->model()->rowCount())),
                 qPrintable(totals->text()));
        QVERIFY2(totals->text().contains(QStringLiteral("Total outstanding: ")), qPrintable(totals->text()));
        // Money detection, totals and highlighting rely on column keys, so they still work with English
        // headers
        const int outstandingColumn = columnByKey(table->model(), QStringLiteral("Balance"));
        QVERIFY(outstandingColumn >= 0);
        QCOMPARE(table->model()->headerData(outstandingColumn, Qt::Horizontal).toString(),
                 QStringLiteral("Outstanding"));
        const QModelIndex owed = table->model()->index(0, outstandingColumn);
        // vw_OutstandingTuition only lists unpaid enrollments
        QVERIFY(owed.data(Qt::UserRole).toDouble() > 0);
        QVERIFY2(owed.data().toString().endsWith(QStringLiteral(" ₫")), qPrintable(owed.data().toString()));
        QCOMPARE(owed.data(Qt::ForegroundRole).value<QColor>(), QColor(Theme::kNegativeText));

        // Back to Vietnamese from the header: the window asks to be rebuilt
        QSignalSpy rebuild(&w, &MainWindow::languageChangeRequested);
        auto* combo = w.findChild<QComboBox*>(QStringLiteral("languageCombo"));
        QVERIFY(combo);
        combo->setCurrentIndex(combo->findData(QStringLiteral("vi")));
        QCOMPARE(rebuild.count(), 1);
        QCOMPARE(I18n::current(), Language::Vietnamese);
        QCOMPARE(m_app->language().current(), Language::Vietnamese);
    }
};

// main() with a full QApplication, needed for widgets
QTEST_MAIN(TestE2EGui)
#include "tst_e2e_gui.moc"
