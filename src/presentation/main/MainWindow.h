#pragma once

#include "application/services/Permissions.h"
#include "presentation/main/AppServices.h"

#include <QHash>
#include <QMainWindow>
#include <optional>

class QComboBox;
class QLabel;
class QListWidget;
class QStackedWidget;

// Main window: the menu on the left is built from the user's role (Permissions), pages are shown on the right
// Qt vocabulary used by every window/page class:
//   - Q_OBJECT: a macro that lets the class have signals and slots (Qt generates extra code for it, "moc").
//   - signal: a notification the object sends ("logout was requested"); it has no code of its own.
//   - slot: a normal function that Qt calls when a connected signal is sent (connect(...) in the .cpp).
// The pages (dashboard, students, lists) are created on first use and kept in a QStackedWidget, which shows
// one of them at a time.
class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(AppServices services, QWidget* parent = nullptr);

    const QList<Feature>& features() const { return m_features; }
    void openFeature(Feature feature); // also used by the screenshot tool and the GUI tests
    std::optional<Feature> currentFeature() const;

signals:
    void logoutRequested();
    void languageChangeRequested(); // the language was switched: the caller rebuilds the window

private slots:
    void onMenuRowChanged(int row);
    void changePassword();
    void changeLanguage();

private:
    QWidget* buildSidebar();
    QWidget* buildHeader();
    QWidget* pageFor(Feature feature);

    AppServices m_services;
    QList<Feature> m_features;
    // key = (int)Feature, a page is created the first time it is opened. Raw pointers to widgets are fine in
    // Qt: a widget created with a parent is deleted automatically together with that parent.
    QHash<int, QWidget*> m_pages;
    QListWidget* m_menu = nullptr;
    QStackedWidget* m_content = nullptr;
    QLabel* m_title = nullptr;
    QComboBox* m_languageCombo = nullptr;
};
