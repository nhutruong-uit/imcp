// Records a demo video of the application by itself: a script signs in as the four demo accounts, opens the
// screens, types, clicks, fills in forms and says in captions what happens, while every window of the
// application is photographed 15 times a second and encoded to an .mp4 by ffmpeg. The result is committed as
// docs/demo/QLTTTA_Demo_vi.mp4 (see docs/demo/README.md), so a member who cannot run the application can
// still see it work, and the video is recorded again whenever the screens change. How it works: the real
// application code (the same AppContainer, MainWindow and pages as QLTTTA) runs against the real database in
// this process; `Director` plays the user (pointer, keys, clicks), `Recorder` takes the pictures with
// QWidget::grab and adds the pointer, the captions and the title cards. Nothing is captured from the screen,
// so no Screen Recording permission is needed and a rerun gives the same video. Developer tool, not part of
// the application: built only with -DQLTTTA_BUILD_TOOLS=ON; scripts/record_demo builds and runs it. Needs
// ffmpeg in PATH and the seed data loaded (the demo changes a little data and puts it back; the dates of the
// seed data are relative to the day it was loaded, so load it again before recording). Environment variables:
//   QLTTTA_DEMO_PASSWORD  shared password of the demo accounts (required)
//   QLTTTA_SERVER         SQL Server address (default localhost,1433)
//   QLTTTA_DEMO_LANG      UI and caption language: vi (default) or en
//   QLTTTA_DEMO_OUT       the video file (default docs/demo/QLTTTA_Demo_<lang>.mp4)
//   QLTTTA_DEMO_CHAPTERS  comma-separated chapters to record (default: all; see Scenario.cpp)
//   QLTTTA_DEMO_FPS       pictures per second (default 15)
//   QLTTTA_DEMO_SIZE      size of the application window (default 1440x900); the video is a strip of 76 px
//                         higher, where the captions are written
//   QLTTTA_DEMO_CRF       H.264 quality, lower = better and larger (default 27)
//   QLTTTA_DEMO_CAPTIONS  the captions file (default docs/demo/captions.tsv)
//   QLTTTA_FFMPEG         the ffmpeg program (default: the one in PATH)
// The default paths are relative: run it from the repository root. It runs without a display:
//   QT_QPA_PLATFORM=offscreen ./qlttta_demo_video
// Exit code: 0 = the video was written, 1 = the script or ffmpeg failed (the pictures so far are kept as
// <video>.failed.mp4 for a look), 2 = wrong settings.
#include "app/AppContainer.h"
#include "demo/Director.h"
#include "demo/Recorder.h"
#include "demo/Scenario.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Theme.h"

#include <QApplication>
#include <QTextStream>
#include <thread>

namespace {
constexpr int kCaptionBand = 76; // height of the strip under the application where the captions are written

QtMessageHandler g_defaultHandler = nullptr;

// An environment variable that is set but empty counts as not set (PowerShell cannot unset one easily)
QString envOr(const char* name, const QString& fallback) {
    const QString value = qEnvironmentVariable(name);
    return value.isEmpty() ? fallback : value;
}

// The offscreen platform has no window manager, so Qt warns about raise(), grabbing the keyboard and
// size hints on every dialog; they are expected here and would bury the real messages
void quietHandler(QtMsgType type, const QMessageLogContext& context, const QString& message) {
    if (message.startsWith(QLatin1String("This plugin does not support")))
        return;
    if (g_defaultHandler)
        g_defaultHandler(type, context, message);
}
} // namespace

int main(int argc, char* argv[]) {
    g_defaultHandler = qInstallMessageHandler(quietHandler);
    QApplication app(argc, argv);
    // Own settings organization: the tool never changes the settings of the real application
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103-Demo"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    // Closing the main window (log out, language switch) must not end the program: the script decides
    QApplication::setQuitOnLastWindowClosed(false);
    Theme::apply(app);
    QTextStream out(stdout);
    QTextStream err(stderr);

    DemoSettings settings;
    settings.password = qEnvironmentVariable("QLTTTA_DEMO_PASSWORD");
    if (settings.password.isEmpty()) {
        err << "QLTTTA_DEMO_PASSWORD is not set\n";
        return 2;
    }
    const Language language = languageFromCode(envOr("QLTTTA_DEMO_LANG", QStringLiteral("vi")));
    const QString code = languageCode(language);
    const QString output = envOr("QLTTTA_DEMO_OUT", QStringLiteral("docs/demo/QLTTTA_Demo_%1.mp4").arg(code));
    const QStringList sizeParts =
        envOr("QLTTTA_DEMO_SIZE", QStringLiteral("1440x900")).split(QLatin1Char('x'));
    const QSize appSize(sizeParts.value(0).toInt(), sizeParts.value(1).toInt());
    const int fps = envOr("QLTTTA_DEMO_FPS", QStringLiteral("15")).toInt();
    if (appSize.width() < 1024 || appSize.height() < 640 || appSize.width() % 2 || appSize.height() % 2 ||
        fps < 5 || fps > 60) {
        err << "QLTTTA_DEMO_SIZE needs even numbers of at least 1024x640 (the application's minimum window) "
               "and QLTTTA_DEMO_FPS must be 5-60\n";
        return 2;
    }
    settings.chapters =
        qEnvironmentVariable("QLTTTA_DEMO_CHAPTERS").split(QLatin1Char(','), Qt::SkipEmptyParts);

    AppContainer container;
    container.language().select(language);
    I18n::apply(language);
    ServerConfig config;
    config.host = envOr("QLTTTA_SERVER", QStringLiteral("localhost,1433"));
    container.auth().saveServerConfig(config);

    Captions captions;
    QString error;
    if (!captions.load(envOr("QLTTTA_DEMO_CAPTIONS", QStringLiteral("docs/demo/captions.tsv")), language,
                       &error)) {
        err << error << "\n";
        return 2;
    }
    if (!validChapters(settings.chapters, &error)) {
        err << error << "\n";
        return 2;
    }

    Recorder recorder(appSize, kCaptionBand, fps, output);
    if (!recorder.start(&error)) {
        err << error << "\n";
        return 1;
    }
    Director director(container, recorder, captions, appSize);

    // The script runs in its own thread while this one keeps the application's event loop going
    QString failure;
    std::thread script([&] {
        try {
            runScenario(director, settings);
        } catch (const std::exception& e) {
            failure = QString::fromUtf8(e.what());
        }
        QMetaObject::invokeMethod(&app, &QCoreApplication::quit, Qt::QueuedConnection);
    });
    app.exec();
    script.join();

    const bool succeeded = failure.isEmpty();
    if (!recorder.finish(succeeded, &error)) {
        err << error << "\n";
        director.shutdown();
        return 1;
    }
    director.shutdown();
    if (!succeeded) {
        err << "The script stopped: " << failure << "\n"
            << "The pictures so far are in the .failed.mp4 file next to " << output << "\n";
        return 1;
    }
    out << "Wrote " << output << "\n";
    return 0;
}
