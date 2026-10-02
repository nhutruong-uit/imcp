#pragma once

#include "domain/common/TableData.h"

#include <QAbstractTableModel>

// Shows TableData in a QTableView (Qt::DisplayRole: formatted text, Qt::UserRole: raw value used for
// sorting). Horizontal headers: DisplayRole = title in the UI language, Columns::KeyRole = column key.
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
