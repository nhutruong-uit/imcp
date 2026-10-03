#pragma once

#include "domain/common/TableData.h"

#include <QAbstractTableModel>

// Shows TableData in a QTableView (Qt::DisplayRole: formatted text, Qt::UserRole: raw value used for
// sorting). Horizontal headers: DisplayRole = title in the UI language, Columns::KeyRole = column key.
// Qt model/view in short: the view (QTableView) draws the table and asks the model for each cell with a
// "role" = what it needs: DisplayRole the text, UserRole the raw value (sorting, totals), ForegroundRole the
// text color, TextAlignmentRole the alignment. The model never draws; the view never formats.
class TableDataModel : public QAbstractTableModel {
    Q_OBJECT
public:
    explicit TableDataModel(QObject* parent = nullptr);

    void setTableData(TableData data);
    const TableData& tableData() const { return m_data; }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    int columnCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const override;

private:
    TableData m_data;
};
