#include "Director.h"

#include "Recorder.h"
#include "app/AppContainer.h"
#include "presentation/common/DataTable.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/MainWindow.h"

#include <QAbstractItemView>
#include <QApplication>
#include <QComboBox>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFile>
#include <QKeyEvent>
#include <QLabel>
#include <QLineEdit>
#include <QLineF>
#include <QListWidget>
#include <QMouseEvent>
#include <QPointer>
#include <QPushButton>
#include <QTableView>
#include <QTimer>
#include <algorithm>
#include <chrono>
#include <thread>

namespace {
// What the pointer would do at that place: press or release the left button over the widget
void sendMouse(QWidget* target, QEvent::Type type, const QPoint& local) {
    const bool release = type == QEvent::MouseButtonRelease;
    QMouseEvent event(type, QPointF(local), target->mapToGlobal(QPointF(local)), Qt::LeftButton,
                      release ? Qt::NoButton : Qt::LeftButton, Qt::NoModifier);
    QApplication::sendEvent(target, &event);
}
} // namespace

// ---- Captions --------------------------------------------------------------------------------------------

bool Captions::load(const QString& path, Language language, QString* error) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        *error = QStringLiteral("cannot read %1 (run the tool from the repository root)").arg(path);
        return false;
    }
    const int column = language == Language::Vietnamese ? 2 : 1;
    for (const QByteArray& raw : file.readAll().split('\n')) {
        const QString line = QString::fromUtf8(raw).trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        const QStringList parts = line.split(QLatin1Char('\t'));
        if (parts.size() < 3 || parts[1].trimmed().isEmpty() || parts[2].trimmed().isEmpty()) {
            *error = QStringLiteral("%1: the line \"%2\" needs an id, an English and a Vietnamese text")
                         .arg(path, parts.value(0));
            return false;
        }
        m_texts.insert(parts[0].trimmed(), parts[column].trimmed());
    }
    return true;
}

QString Captions::text(const QString& id) const {
    if (!m_texts.contains(id))
        throw DemoError(QStringLiteral("caption \"%1\" is not in the captions file").arg(id).toStdString());
    return m_texts.value(id);
}

// ---- Director: the story ---------------------------------------------------------------------------------

Director::Director(AppContainer& container, Recorder& recorder, Captions captions, QSize appSize)
    : m_container(container), m_recorder(recorder), m_captions(std::move(captions)), m_appSize(appSize) {}

Director::~Director() = default;

void Director::pause(int ms) {
    if (ms > 0)
        std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

void Director::card(const QString& titleId, const QString& subtitleId, int holdMs,
                    const std::function<void()>& whileCovered, bool fadeOut) {
    sayNothing();
    const QString title = m_captions.text(titleId);
    const QString subtitle = m_captions.text(subtitleId);
    m_recorder.addChapter(title);
    constexpr int kSteps = 8;
    for (int i = 1; i <= kSteps; ++i) { // fade in
        m_recorder.setCard(title, subtitle, double(i) / kSteps);
        pause(45);
    }
    if (whileCovered)
        whileCovered();
    pause(holdMs);
    if (!fadeOut)
        return;
    for (int i = kSteps - 1; i >= 0; --i) { // fade out, onto what whileCovered() put on the screen
        m_recorder.setCard(title, subtitle, double(i) / kSteps);
        pause(45);
    }
}

void Director::say(const QString& id) {
    const QString text = m_captions.text(id);
    finishReading();
    m_recorder.setCaption(text);
    // About 18 characters a second, and never less than two seconds
    m_captionReadyAt = m_recorder.nowMs() + std::max<qint64>(2000, 600 + 55 * text.size());
}

void Director::sayNothing() {
    finishReading();
    m_recorder.setCaption(QString());
}

// Waits until the caption on screen has been on screen long enough to be read. Called before the scene
// changes (a new page, a closing dialog), so a caption is never replaced - or left behind on another page -
// before the viewer could read it.
void Director::finishReading() {
    pause(int(m_captionReadyAt - m_recorder.nowMs()));
}

// The scene is about to change: the caption has been read and must not stay over the next page while it loads
void Director::scenePassed() {
    finishReading();
    m_recorder.setCaption(QString());
}

// ---- Director: the application ---------------------------------------------------------------------------

void Director::gui(const std::function<void()>& code) {
    QMetaObject::invokeMethod(qApp, code, Qt::BlockingQueuedConnection);
}

void Director::guiAsync(std::function<void()> code) {
    QMetaObject::invokeMethod(qApp, std::move(code), Qt::QueuedConnection);
}

void Director::waitUntil(const std::function<bool()>& condition, int timeoutMs, const QString& what) {
    for (int waited = 0;; waited += 50) {
        bool done = false;
        gui([&] { done = condition(); });
        if (done)
            return;
        if (waited >= timeoutMs)
            throw DemoError(QStringLiteral("timed out waiting for %1").arg(what).toStdString());
        pause(50);
    }
}

// Same loop as main.cpp: the login dialog (again in the new language when it is switched there), then the
// main window of the user who signed in
void Director::runLogin() {
    for (;;) {
        m_login = std::make_unique<LoginDialog>(m_container.auth(), m_container.language());
        m_login->resize(900, 540);
        m_recorder.setAnchor(m_login.get());
        const int outcome = m_login->exec();
        m_login.reset();
        m_recorder.setAnchor(nullptr);
        if (outcome == LoginDialog::LanguageChanged)
            continue;
        if (outcome == QDialog::Accepted)
            showMainWindow(std::nullopt);
        return;
    }
}

// The window closes through a zero-delay timer: the dialog that asked "Do you want to log out?" is still on
// the stack when the signal comes, and the window must not be deleted under it
void Director::showMainWindow(std::optional<Feature> page) {
    m_window = std::make_unique<MainWindow>(m_container.services());
    m_window->resize(m_appSize);
    if (page)
        m_window->openFeature(*page);
    QObject::connect(m_window.get(), &MainWindow::logoutRequested, m_window.get(), [this] {
        m_window->hide();
        QTimer::singleShot(0, qApp, [this] {
            m_recorder.setAnchor(nullptr);
            m_window.reset();
            m_container.auth().logout();
            runLogin();
        });
    });
    QObject::connect(m_window.get(), &MainWindow::languageChangeRequested, m_window.get(), [this] {
        const std::optional<Feature> current = m_window->currentFeature();
        m_window->hide();
        QTimer::singleShot(0, qApp, [this, current] {
            m_recorder.setAnchor(nullptr);
            m_window.reset();
            showMainWindow(current);
        });
    });
    m_window->show();
    m_recorder.setAnchor(m_window.get());
}

void Director::openLogin() {
    guiAsync([this] { runLogin(); });
    waitForLogin();
}

// The login dialog remembers the last user and keeps the message of the last failed attempt; a chapter starts
// from an empty form and types its own
void Director::resetLoginForm() {
    gui([this] {
        if (!m_login)
            return;
        for (QLineEdit* edit : m_login->findChildren<QLineEdit*>())
            if (edit->objectName() == QLatin1String("usernameEdit") ||
                edit->objectName() == QLatin1String("passwordEdit"))
                edit->clear();
        if (auto* error = m_login->findChild<QLabel*>(QStringLiteral("ErrorText")))
            error->hide();
    });
}

bool Director::loginShown() {
    bool shown = false;
    gui([&] { shown = m_login && m_login->isVisible(); });
    return shown;
}

void Director::waitForMainWindow() {
    waitUntil([this] { return m_window && m_window->isVisible(); }, 20000, QStringLiteral("the main window"));
    pause(400);
}

void Director::waitForLogin() {
    waitUntil([this] { return m_login && m_login->isVisible(); }, 10000, QStringLiteral("the login dialog"));
}

void Director::waitForDialog(bool open) {
    waitUntil(
        [this, open] {
            QWidget* modal = QApplication::activeModalWidget();
            return (modal != nullptr && modal != m_login.get()) == open;
        },
        8000, open ? QStringLiteral("a dialog to open") : QStringLiteral("the dialog to close"));
    pause(open ? 450 : 250);
}

void Director::waitForDialogOfType(const char* className) {
    waitUntil(
        [className] {
            const QWidget* modal = QApplication::activeModalWidget();
            return modal != nullptr && modal->inherits(className);
        },
        8000, QStringLiteral("a %1 to open").arg(QLatin1String(className)));
    pause(450);
}

void Director::shutdown() {
    m_recorder.setAnchor(nullptr);
    m_window.reset();
    if (m_login)
        m_login->reject();
    m_container.auth().logout();
}

// ---- Director: finding widgets ---------------------------------------------------------------------------

// The window to look in: the dialog on top, else the main window, else the login dialog
QWidget* Director::scope() const {
    if (QWidget* modal = QApplication::activeModalWidget())
        return modal;
    if (m_window)
        return m_window.get();
    return m_login.get();
}

QWidget* Director::findWidget(const QString& objectName, const QMetaObject& type) {
    QWidget* found = nullptr;
    gui([&] {
        if (QWidget* root = scope())
            for (QWidget* w : root->findChildren<QWidget*>(objectName))
                if (!found && w->isVisible() && type.cast(w))
                    found = w;
    });
    if (!found)
        throw DemoError(QStringLiteral("no visible %1 named \"%2\"")
                            .arg(QLatin1String(type.className()), objectName)
                            .toStdString());
    return found;
}

QPushButton* Director::buttonWithText(const char* context, const char* source) {
    const QString text = QCoreApplication::translate(context, source);
    QPushButton* found = nullptr;
    gui([&] {
        if (QWidget* root = scope())
            for (QPushButton* b : root->findChildren<QPushButton*>())
                if (!found && b->isVisible() && b->text().remove(QLatin1Char('&')).trimmed() == text)
                    found = b;
    });
    if (!found)
        throw DemoError(QStringLiteral("no visible button \"%1\"").arg(text).toStdString());
    return found;
}

DataTable* Director::list() {
    DataTable* found = nullptr;
    gui([&] {
        if (QWidget* root = scope())
            for (DataTable* t : root->findChildren<DataTable*>())
                if (!found && t->isVisible() && t->view()->objectName() == QLatin1String("listTable"))
                    found = t;
    });
    if (!found)
        throw DemoError("no visible list on this page");
    return found;
}

// ---- Director: doing things ------------------------------------------------------------------------------

QPointF Director::canvasPoint(QWidget* widget, const QPoint& local) {
    QPointF point;
    gui([&] { point = m_recorder.canvasPoint(widget, local); });
    return point;
}

// The pointer travels in a straight line and slows down at both ends, like a hand
void Director::glideTo(const QPointF& target) {
    QPointF from = m_recorder.cursor();
    if (from.x() < 0) // first move of the video: come from the bottom of the picture
        from = QPointF(m_appSize.width() * 0.5, m_appSize.height() - 40);
    const double distance = QLineF(from, target).length();
    if (distance < 2) {
        m_recorder.setCursor(target, true);
        return;
    }
    const int steps = std::max(1, int(std::clamp(distance * 0.9, 240.0, 900.0)) / 16);
    for (int i = 1; i <= steps; ++i) {
        const double t = double(i) / steps;
        const double eased = t * t * (3 - 2 * t);
        m_recorder.setCursor(from + (target - from) * eased, true);
        pause(16);
    }
}

void Director::moveTo(QWidget* widget) {
    QPoint local;
    gui([&] { local = widget->rect().center(); });
    glideTo(canvasPoint(widget, local));
}

// Glide, press, release. The release is queued: a click that opens a dialog does not return until the dialog
// is closed, and the script must be free to use that dialog
void Director::clickAt(QWidget* target, const QPoint& local) {
    const QPointF point = canvasPoint(target, local);
    glideTo(point);
    m_recorder.ripple(point);
    const QPointer<QWidget> guard(target);
    gui([&] {
        if (guard)
            sendMouse(target, QEvent::MouseButtonPress, local);
    });
    pause(90);
    guiAsync([guard, local] {
        if (guard)
            sendMouse(guard, QEvent::MouseButtonRelease, local);
    });
    pause(180);
}

void Director::click(QWidget* widget) {
    QPoint local;
    gui([&] { local = widget->rect().center(); });
    clickAt(widget, local);
}

void Director::selectRow(QTableView* view, int row) {
    QPoint local;
    gui([&] {
        int column = 0; // the first column may be a hidden technical ID: click in the first one that shows
        while (column < view->model()->columnCount() - 1 && view->isColumnHidden(column))
            ++column;
        const QModelIndex index = view->model()->index(row, column);
        view->scrollTo(index);
        const QRect rect = view->visualRect(index);
        local = QPoint(std::min(rect.right() - 8, rect.left() + 40), rect.center().y());
    });
    clickAt(view->viewport(), local);
}

int Director::rowWhere(DataTable* table, const QString& key, const QVariant& value) {
    int found = -1;
    gui([&] {
        for (int row = 0; row < table->rowCount() && found < 0; ++row)
            if (table->valueAt(row, key).toString() == value.toString())
                found = row;
    });
    return found;
}

void Director::type(QLineEdit* edit, const QString& text, int msPerCharacter, bool replace) {
    click(edit);
    if (replace)
        gui([edit] { edit->selectAll(); });
    int position = 0;
    for (const QChar c : text) {
        gui([&] {
            QKeyEvent press(QEvent::KeyPress, Qt::Key_unknown, Qt::NoModifier, QString(c));
            QApplication::sendEvent(edit, &press);
            QKeyEvent release(QEvent::KeyRelease, Qt::Key_unknown, Qt::NoModifier, QString(c));
            QApplication::sendEvent(edit, &release);
        });
        pause(msPerCharacter + (position++ % 3) * 12); // not a metronome
    }
    pause(150);
}

// The list opens under the combo box with a click and an item is chosen with another click. If a click does
// not select (some styles ignore a release that comes too early), the item is set directly so the story goes
// on.
void Director::chooseIndex(QComboBox* combo, int index) {
    // The choice may rebuild the whole window (the language selector): the combo box is gone by then
    QPointer<QComboBox> guard;
    gui([&] { guard = combo; });
    click(combo);
    pause(650);
    QWidget* viewport = nullptr;
    QPoint local;
    gui([&] {
        QAbstractItemView* view = combo->view();
        if (!view->isVisible())
            return;
        viewport = view->viewport();
        const QRect rect = view->visualRect(view->model()->index(index, 0));
        local = QPoint(std::min(rect.right() - 6, rect.left() + 40), rect.center().y());
    });
    if (!viewport)
        throw DemoError("the list of a combo box did not open");
    clickAt(viewport, local);
    pause(200);
    gui([&] {
        if (guard && (guard->currentIndex() != index || guard->view()->isVisible())) {
            combo->setCurrentIndex(index);
            combo->hidePopup();
            emit combo->activated(index);
        }
    });
    pause(250);
}

void Director::choose(QComboBox* combo, const QVariant& data) {
    int index = -1;
    gui([&] { index = combo->findData(data); });
    if (index < 0)
        throw DemoError(QStringLiteral("the combo box has no item %1").arg(data.toString()).toStdString());
    chooseIndex(combo, index);
}

void Director::openPage(Feature feature) {
    scenePassed();
    auto* nav = find<QListWidget>(QStringLiteral("NavList"));
    QPoint local;
    bool exists = false;
    gui([&] {
        for (int row = 0; row < nav->count(); ++row) {
            QListWidgetItem* item = nav->item(row);
            if (item->data(Qt::UserRole).toInt() == static_cast<int>(feature)) {
                nav->scrollToItem(item);
                local = nav->visualItemRect(item).center();
                exists = true;
            }
        }
    });
    if (!exists)
        throw DemoError(
            QStringLiteral("the menu of this user has no entry %1").arg(int(feature)).toStdString());
    clickAt(nav->viewport(), local);
    waitUntil([this, feature] { return m_window && m_window->currentFeature() == feature; }, 6000,
              QStringLiteral("the page %1").arg(int(feature)));
    pause(300);
}

// Closes the dialog on top the way a person would, with its own button. The dialogs of this application have
// either a QDialogButtonBox or a plain "Close" / "Cancel" button (the text its class passes to tr()); Escape
// is the last resort.
void Director::closeDialog() {
    scenePassed();
    QPushButton* button = nullptr;
    QDialog* dialog = nullptr;
    gui([&] {
        dialog = qobject_cast<QDialog*>(QApplication::activeModalWidget());
        if (!dialog)
            return;
        for (QDialogButtonBox* box : dialog->findChildren<QDialogButtonBox*>())
            for (auto kind : {QDialogButtonBox::Close, QDialogButtonBox::Cancel, QDialogButtonBox::Ok})
                if (!button && box->button(kind) && box->button(kind)->isVisible())
                    button = box->button(kind);
        const char* context = dialog->metaObject()->className();
        for (const char* source : {"Close", "Cancel"})
            for (QPushButton* b : dialog->findChildren<QPushButton*>())
                if (!button && b->isVisible() &&
                    b->text().remove(QLatin1Char('&')).trimmed() ==
                        QCoreApplication::translate(context, source))
                    button = b;
    });
    if (!dialog)
        throw DemoError("no dialog to close");
    if (button)
        click(button);
    else
        gui([&] { dialog->reject(); });
    waitForDialog(false);
}

QPushButton* Director::dialogButton(int standardButton) {
    QPushButton* found = nullptr;
    gui([&] {
        if (QWidget* root = scope())
            for (QDialogButtonBox* box : root->findChildren<QDialogButtonBox*>())
                if (!found && box->isVisible())
                    found = box->button(static_cast<QDialogButtonBox::StandardButton>(standardButton));
    });
    if (!found)
        throw DemoError(
            QStringLiteral("the dialog has no standard button %1").arg(standardButton).toStdString());
    return found;
}
