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
    QHash<int, QWidget*> m_pages; // key = (int)Feature, a page is created the first time it is opened
    QListWidget* m_menu = nullptr;
    QStackedWidget* m_content = nullptr;
    QLabel* m_title = nullptr;
    QComboBox* m_languageCombo = nullptr;
};
