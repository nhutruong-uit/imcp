#pragma once

#include "application/services/Permissions.h"
#include "presentation/common/I18n.h"

#include <QHash>
#include <QMetaObject>
#include <QPoint>
#include <QPointF>
#include <QSize>
#include <QString>
#include <QVariant>
#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>

class AppContainer;
class DataTable;
class LoginDialog;
class MainWindow;
class QComboBox;
class QLineEdit;
class QPushButton;
class QTableView;
class QWidget;
class Recorder;

// The script stops with this when something it expects is not on the screen (a button that does not exist,
// a page that did not open): a video with a missing step is worse than no video
class DemoError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

// The words of the video (captions and title cards), one line per id in docs/demo/captions.tsv:
//   id <TAB> English text <TAB> Vietnamese text
// The script only names ids, so the same story can be recorded in either language.
class Captions {
public:
    bool load(const QString& path, Language language, QString* error);
    QString text(const QString& id) const; // throws DemoError for an id that is not in the file

private:
    QHash<QString, QString> m_texts;
};

// What a person at the keyboard does, as calls the script can read like a story: glide the pointer to a
// button and click it, type into a field letter by letter, pick an item of a combo box, say something in a
// caption. It also plays the part of main.cpp (login -> main window -> log out -> login, switching language
// rebuilds the window), so the video shows the real flow of the application.
//
// Threads. The script runs in its own thread and every call here may be made from that thread only. A call
// that touches a widget runs in the GUI thread (`gui`) and waits for it; a click that may open a dialog is
// queued instead (`guiAsync`), because QDialog::exec() only returns when the dialog closes - the script goes
// on typing into that dialog while its event loop runs.
class Director {
public:
    Director(AppContainer& container, Recorder& recorder, Captions captions, QSize appSize);
    ~Director();

    // ---- the story ----
    // A title card over everything (fades in and out) and a chapter mark in the video file. whileCovered runs
    // once the card hides the screen, to get the next scene ready (the login dialog) so the card fades out
    // onto it; fadeOut = false keeps the card on screen (the last one).
    void card(const QString& titleId, const QString& subtitleId, int holdMs = 3200,
              const std::function<void()>& whileCovered = {}, bool fadeOut = true);
    // A caption at the bottom; it stays at least as long as it takes to read before the next one replaces it
    void say(const QString& id);
    void sayNothing();
    void pause(int ms);

    // ---- the application ----
    void openLogin();               // as main.cpp: the login dialog, and the main window after a good sign-in
    void resetLoginForm();          // empty fields, no old error message
    bool loginShown();              // is the login dialog on screen
    void waitForMainWindow();       // until the main window shows after the sign-in
    void waitForLogin();            // until the login dialog shows again (after a log out)
    void openPage(Feature feature); // clicks its entry in the sidebar
    void waitForDialog(bool open = true);
    // Until the dialog on top is of that class (a message box that follows a dialog replaces it at once, so
    // "the dialog closed" would never be seen)
    void waitForDialogOfType(const char* className);
    void closeDialog(); // Cancel / Close button of the dialog on top, else Escape
    // A standard button (QDialogButtonBox::Save, Cancel, Yes...) of the dialog or message box on top
    QPushButton* dialogButton(int standardButton);

    // ---- finding widgets (only the visible ones of the window or dialog on top) ----
    template <typename T> T* find(const QString& objectName) {
        return static_cast<T*>(findWidget(objectName, T::staticMetaObject));
    }
    // The visible button whose text is the translation of `source` in the class `context` (the text a page
    // passes to tr()), for the few buttons that have no object name
    QPushButton* buttonWithText(const char* context, const char* source);
    // The main list of the page on top ("listTable"), also inside a dialog
    DataTable* list();

    // ---- doing things ----
    void moveTo(QWidget* widget);
    void click(QWidget* widget);
    void selectRow(QTableView* view, int row);
    int rowWhere(DataTable* table, const QString& key, const QVariant& value); // -1 when there is none
    // replace: select what the field holds first, so the typed text takes its place
    void type(QLineEdit* edit, const QString& text, int msPerCharacter = 65, bool replace = false);
    void choose(QComboBox* combo, const QVariant& data); // opens the list and clicks the item with that data
    void chooseIndex(QComboBox* combo, int index);
    // Runs code in the GUI thread and waits for it (reading or changing a widget directly)
    void gui(const std::function<void()>& code);
    void waitUntil(const std::function<bool()>& condition, int timeoutMs, const QString& what);

    // Closes the windows and signs out (after the last scene)
    void shutdown();

private:
    QWidget* findWidget(const QString& objectName, const QMetaObject& type);
    QWidget* scope() const;
    void guiAsync(std::function<void()> code);
    void clickAt(QWidget* target, const QPoint& local);
    void glideTo(const QPointF& target);
    void finishReading();
    void scenePassed();
    QPointF canvasPoint(QWidget* widget, const QPoint& local);
    void runLogin();
    void showMainWindow(std::optional<Feature> page);

    AppContainer& m_container;
    Recorder& m_recorder;
    Captions m_captions;
    QSize m_appSize;
    std::unique_ptr<LoginDialog> m_login;
    std::unique_ptr<MainWindow> m_window;
    qint64 m_captionReadyAt = 0; // recorder clock: until then the caption on screen is still being read
};
