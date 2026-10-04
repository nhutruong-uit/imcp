#pragma once

#include "application/services/Permissions.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "presentation/main/AppServices.h"

#include <QList>
#include <QWidget>
#include <functional>

class DataTable;
class QHBoxLayout;
class QLabel;
class QLineEdit;
class QPushButton;
class QVBoxLayout;

// Base of every page built around one list (classes, enrollments, receipts, catalogs...): a filter bar (the
// page's own filters + quick filter + Refresh / Excel / PDF), an action bar (the page's buttons), the list
// ("listTable") and a footer with the row count and totals ("totalsLine"). A page subclass: adds its filters
// and actions in its constructor, implements fetch() (one service call), and calls reload() at the end of its
// constructor. Buttons that need a selected row are enabled only when a row is selected; buttons that change
// data are only created when Permissions::canEdit allows it (the database still checks the GRANT).
class DataPage : public QWidget {
    Q_OBJECT
public:
    DataPage(AppServices services, Feature feature, QWidget* parent = nullptr);

public slots:
    void reload();

protected:
    virtual Result<TableData> fetch() = 0;
    virtual void dataLoaded() {} // after a successful reload (e.g. refresh a second table)

    void addFilter(QWidget* widget);
    // Adds a button to the action bar; needsSelection = enabled only while a row is selected
    QPushButton* addAction(const QString& text, const QString& icon, const QString& objectName,
                           bool needsSelection, std::function<void()> handler);
    void addBodyWidget(QWidget* widget, int stretch = 0); // below the main list (e.g. a second list)
    DataTable* table() const { return m_table; }
    QVariant selected(const QString& key) const; // raw value of the selected row
    bool canEdit() const;  // Permissions::canEdit(role of the user, feature of the page)
    QString title() const; // the menu name of the feature (report titles, file names)
    void reloadAndSelect(const QString& key, const QVariant& value);

    AppServices m_services;
    const Feature m_feature;

private:
    void updateActions();

    QVBoxLayout* m_layout = nullptr;
    QHBoxLayout* m_filterBar = nullptr;
    QHBoxLayout* m_actionBar = nullptr;
    QWidget* m_actionRow = nullptr;
    QLineEdit* m_quickFilter = nullptr;
    DataTable* m_table = nullptr;
    QLabel* m_footer = nullptr;
    QList<QPushButton*> m_selectionActions;
};
