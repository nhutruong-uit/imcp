#pragma once

#include "application/services/Permissions.h"
#include "presentation/main/AppServices.h"

#include <QWidget>

class QLabel;
class QLineEdit;
class QSortFilterProxyModel;
class QTableView;
class TableDataModel;

// Generic page for every read-only lookup list (classes, outstanding tuition, teaching schedule...):
// quick filter, sorting, totals line for money columns, Excel/PDF export.
// Data: ListService::fetch(feature) -> TableData -> TableDataModel -> QSortFilterProxyModel -> QTableView.
// The page knows nothing about the columns of a list: titles and formats come from the column catalog
// (Columns), so a new list needs no new page (docs/ARCHITECTURE.md, section 4).
class ListPage : public QWidget {
    Q_OBJECT
public:
    ListPage(AppServices services, Feature feature, QWidget* parent = nullptr);

public slots:
    void reload();

private:
    void updateTotals();

    AppServices m_services;
    Feature m_feature;
    QLineEdit* m_filter = nullptr;
    QTableView* m_table = nullptr;
    TableDataModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QLabel* m_totals = nullptr;
};
