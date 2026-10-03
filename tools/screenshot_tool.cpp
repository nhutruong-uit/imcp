// Takes screenshots of every screen automatically (for the report and for visual checks with real data).
// What it produces: PNG files of the login screen (also with the server settings open), of every feature each
// account may open, of the student form and of the change password dialog. The Vietnamese set in
// docs/report/images/screens is used by Chapter 6 of the report (docs/report/content/chapter6_8.py) and by
// the user guide (docs/user-guide). It signs in to the real database, so the seed data must be loaded.
// Developer tool, not part of the application: built only with -DQLTTTA_BUILD_TOOLS=ON (see AGENTS.md).
// Environment variables:
//   QLTTTA_SERVER        (default localhost,1433)
//   QLTTTA_SHOT_USERS    comma-separated accounts (default ql_quan,gvu_lan,kt_minh,gv_john)
//   QLTTTA_SHOT_PASSWORD shared password of the demo accounts (required)
//   QLTTTA_SHOT_LANG     UI language: vi (default, used by the report) or en
//   QLTTTA_SHOT_DIR      output folder (default: docs/report/images/screens for vi,
//                        build/screenshots/en for en, so English screenshots never overwrite the images
//                        of the Vietnamese report)
// The default folders are relative: run it from the repository root.
// File names are stable and independent of the UI language: login.png, login_server_settings.png,
// change_password.png, <account>_<feature>.png, <account>_student_form.png (the report and the user guide
// refer to them by name).
// Repeated runs give the same pictures for the same data: the login screen always shows the username
// ql_quan, never the account remembered from the previous run.
// Runs without a display: QT_QPA_PLATFORM=offscreen ./qlttta_screenshots
// Exit code: 0 = every account signed in, 1 = some sign-in failed, 2 = no password given.
#include "app/AppContainer.h"
#include "application/services/Permissions.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Labels.h"
#include "presentation/common/Theme.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/ChangePasswordDialog.h"
#include "presentation/main/MainWindow.h"
#include "presentation/students/StudentFormDialog.h"

#include <QApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QLineEdit>
#include <QPushButton>
#include <QTextStream>
#include <QThread>

namespace {
// Waits while still processing events, so the page can load its data and paint before the screenshot
void wait(int ms) {
    QElapsedTimer t;
    t.start();
    while (t.elapsed() < ms) {
        QApplication::processEvents(QEventLoop::AllEvents, 20);
        QThread::msleep(10);
    }
}

// Stable file-name part of a feature. Never derived from the menu label: that text is translated and may
// change. A switch without default makes the compiler warn (-Wswitch) when a new Feature has no file name.
QString fileName(Feature feature) {
    switch (feature) {
    case Feature::Dashboard:
        return QStringLiteral("dashboard");
    case Feature::Students:
        return QStringLiteral("students");
    case Feature::Classes:
        return QStringLiteral("classes");
    case Feature::WeeklySchedule:
        return QStringLiteral("weekly_schedule");
    case Feature::LearningResults:
        return QStringLiteral("learning_results");
    case Feature::OutstandingTuition:
        return QStringLiteral("outstanding_tuition");
    case Feature::Revenue:
        return QStringLiteral("revenue");
    case Feature::Payroll:
        return QStringLiteral("payroll");
    case Feature::Accounts:
        return QStringLiteral("accounts");
    case Feature::MyClasses:
        return QStringLiteral("my_classes");
    case Feature::MyTeachingSchedule:
        return QStringLiteral("my_teaching_schedule");
    case Feature::MyPay:
        return QStringLiteral("my_pay");
    }
    return QStringLiteral("feature_%1").arg(static_cast<int>(feature));
}
} // namespace

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    // Own settings organization: the tool never changes the settings of the real application
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103-Screenshots"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    Theme::apply(app);
    QTextStream out(stdout);

    const QString password = qEnvironmentVariable("QLTTTA_SHOT_PASSWORD");
    if (password.isEmpty()) {
        out << "QLTTTA_SHOT_PASSWORD is not set\n";
        return 2;
    }
    const Language language =
        languageFromCode(qEnvironmentVariable("QLTTTA_SHOT_LANG", QStringLiteral("vi")));
    const QString defaultFolder = language == Language::Vietnamese
                                      ? QStringLiteral("docs/report/images/screens")
                                      : QStringLiteral("build/screenshots/en");
    const QString folder = qEnvironmentVariable("QLTTTA_SHOT_DIR", defaultFolder);
    QDir().mkpath(folder);
    const QStringList accounts =
        qEnvironmentVariable("QLTTTA_SHOT_USERS", QStringLiteral("ql_quan,gvu_lan,kt_minh,gv_john"))
            .split(QLatin1Char(','), Qt::SkipEmptyParts);

    AppContainer container;
    I18n::apply(language);
    ServerConfig config;
    config.host = qEnvironmentVariable("QLTTTA_SERVER", QStringLiteral("localhost,1433"));
    container.auth().saveServerConfig(config);

    { // Login screen
        LoginDialog login(container.auth(), container.language());
        // The dialog pre-fills the username saved by the last sign-in (the last account of the previous run),
        // so the picture would change between runs. Show a fixed account instead, with the focus where the
        // application puts it for a remembered username.
        if (auto* usernameEdit = login.findChild<QLineEdit*>(QStringLiteral("usernameEdit"))) {
            usernameEdit->setText(QStringLiteral("ql_quan"));
        }
        if (auto* passwordEdit = login.findChild<QLineEdit*>(QStringLiteral("passwordEdit"))) {
            passwordEdit->setFocus();
        }
        login.resize(860, 520);
        login.show();
        wait(300);
        login.grab().save(QDir(folder).filePath(QStringLiteral("login.png")));
        // Same screen with the server settings opened (user guide: connecting to SQL Server)
        if (auto* toggle = login.findChild<QPushButton*>(QStringLiteral("LinkButton"))) {
            toggle->click();
            login.resize(960, 640); // wide enough for the whole certificate option label
            wait(300);
            login.grab().save(QDir(folder).filePath(QStringLiteral("login_server_settings.png")));
        }
    }
    { // Change password dialog (opened from the header of the main window)
        ChangePasswordDialog dialog(container.auth());
        dialog.show();
        wait(300);
        dialog.grab().save(QDir(folder).filePath(QStringLiteral("change_password.png")));
    }

    int failures = 0;
    for (const QString& account : accounts) {
        const auto result = container.auth().login(account, password);
        if (!result.ok()) {
            out << "[" << account << "] login failed: " << result.error() << "\n";
            ++failures;
            continue;
        }
        out << "[" << account << "] " << result.value().fullName << " - " << Labels::role(result.value().role)
            << "\n";
        {
            MainWindow w(container.services());
            w.resize(1440, 860);
            w.show();
            for (Feature f : w.features()) {
                w.openFeature(f);
                wait(400);
                // e.g. gvu_lan_students.png (names used by the report)
                const QString name = QStringLiteral("%1_%2.png").arg(account, fileName(f));
                w.grab().save(QDir(folder).filePath(name));
                out << "   -> " << name << "\n";
            }
            // Student edit form (Qt Designer)
            if (Permissions::canEditStudents(result.value().role)) {
                const auto student = container.services().students.details(QStringLiteral("ST00010"));
                const auto branches = container.services().students.branches();
                if (student.ok() && branches.ok()) {
                    StudentFormDialog dialog(container.services().students, branches.value(),
                                             student.value());
                    dialog.show();
                    wait(300);
                    dialog.grab().save(QDir(folder).filePath(account + QStringLiteral("_student_form.png")));
                }
            }
        }
        container.auth().logout();
    }
    return failures == 0 ? 0 : 1;
}
