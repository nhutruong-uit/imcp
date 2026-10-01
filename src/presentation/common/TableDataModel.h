#pragma once

#include "domain/common/TableData.h"

#include <QAbstractTableModel>

// Model hiển thị TableData lên QTableView (Qt::DisplayRole: đã định dạng, Qt::UserRole: giá trị gốc để sắp xếp)
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
