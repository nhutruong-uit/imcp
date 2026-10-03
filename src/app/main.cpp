#include "app/AppContainer.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/Theme.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/MainWindow.h"

#include <QApplication>
#include <QTextStream>
#include <optional>

// Program entry point. Order of start-up:
//   1. QApplication (the Qt application object), names used by QSettings, icon, look (Theme)
//   2. AppContainer: creates every object of every layer and wires them together
//   3. the UI language chosen last time
//   4. either the diagnostic mode (--check-connection, no window) or the login -> main window loop below
int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    QApplication::setWindowIcon(Icons::get(QStringLiteral("logo"), QStringLiteral("#1F3864"), 64));
    Theme::apply(app);

    AppContainer container;
    I18n::apply(container.language().current()); // the language chosen last time (Vietnamese by default)

    // Diagnostic mode (no GUI): QLTTTA_USER, QLTTTA_PASSWORD, optional QLTTTA_SERVER
    //   ./QLTTTA --check-connection
    if (QApplication::arguments().contains(QStringLiteral("--check-connection"))) {
        if (qEnvironmentVariableIsSet("QLTTTA_SERVER")) {
            ServerConfig config = container.auth().serverConfig();
            config.host = qEnvironmentVariable("QLTTTA_SERVER");
            container.auth().saveServerConfig(config);
        }
        const auto result = container.auth().login(qEnvironmentVariable("QLTTTA_USER"),
                                                   qEnvironmentVariable("QLTTTA_PASSWORD"));
        QTextStream out(stdout);
        if (result.ok())
            out << "OK: " << result.value().fullName << " (" << Labels::role(result.value().role) << ")"
                << Qt::endl;
        else
            out << "ERROR: " << result.error() << Qt::endl;
        return result.ok() ? 0 : 1;
    }

    // Loop: login -> main window -> (log out) -> login again.
    // Switching language rebuilds the screen that is open (the new translation is already loaded);
    // the session stays logged in.
    for (;;) {
        LoginDialog login(container.auth(), container.language());
        const int outcome = login.exec();
        if (outcome == LoginDialog::LanguageChanged)
            continue;
        if (outcome != QDialog::Accepted)
            return 0;

        enum class Exit { Closed, LoggedOut, LanguageChanged };
        Exit exit = Exit::LanguageChanged;
        std::optional<Feature> openPage;
        QByteArray geometry;
        while (exit == Exit::LanguageChanged) {
            exit = Exit::Closed;
            // QObject::connect(sender, signal, receiver, function): when the window emits the signal, Qt runs
            // the function. Here the functions are lambdas ("[&] { ... }" = a small unnamed function that can
            // use the local variables of main).
            MainWindow window(container.services());
            if (!geometry.isEmpty())
                window.restoreGeometry(geometry);
            if (openPage)
                window.openFeature(*openPage);
            QObject::connect(&window, &MainWindow::logoutRequested, &window, [&] {
                exit = Exit::LoggedOut;
                window.close();
            });
            QObject::connect(&window, &MainWindow::languageChangeRequested, &window, [&] {
                exit = Exit::LanguageChanged;
                openPage = window.currentFeature();
                geometry = window.saveGeometry();
                window.close();
            });
            window.show();
            // Event loop: waits for clicks/keys and runs the connected code until the window closes
            app.exec();
        }
        container.auth().logout();
        if (exit != Exit::LoggedOut)
            return 0;
    }
}
