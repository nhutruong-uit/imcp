#pragma once

#include "domain/common/TableData.h"

#include <QStringList>
#include <QVariant>
#include <QWidget>

class QAbstractItemModel;
class QSortFilterProxyModel;
class QTableView;
class TableDataModel;

// A table of database rows with the behavior every screen shares: titles and formats from the column catalog
// (Columns), sorting by the raw value, a quick filter, a totals line for money columns, and helpers to read
// the selected row by column KEY (never by position or displayed text). Data: TableData -> TableDataModel
// (formats each cell) -> QSortFilterProxyModel (filter, sort) -> QTableView.
class DataTable : public QWidget {
    Q_OBJECT
public:
    // tableObjectName: the name the end-to-end tests look up ("listTable" for the main list of a page)
    explicit DataTable(const QString& tableObjectName, QWidget* parent = nullptr);

    void setData(TableData data);
    const TableData& data() const;
    QTableView* view() const { return m_view; }
    const QAbstractItemModel&
    visibleModel() const; // what the user sees (filtered, sorted): used by the exports
    void setFilterText(const QString& text);
    void setHiddenColumns(const QStringList& keys); // technical keys (IDs) kept for the code, not shown

    int rowCount() const; // rows that pass the quick filter
    bool hasSelection() const;
    QVariant selectedValue(const QString& key) const; // raw value of that column in the selected row
    QVariant valueAt(int row, const QString& key) const;
    bool selectWhere(const QString& key, const QVariant& value); // true when a row matched
    void selectFirstRow();
    // "12 rows   •   Total outstanding: 6.500.000 ₫" over the visible rows (summable columns only)
    QString totalsText() const;

signals:
    void selectionChanged();
    void activated(); // double click / Enter on a row

private:
    int columnOf(const QString& key) const;
    void applyHiddenColumns();

    TableDataModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QTableView* m_view = nullptr;
    QStringList m_hidden;
};
