#include "presentation/common/TableDataModel.h"

#include "presentation/common/Format.h"

#include <QColor>

TableDataModel::TableDataModel(QObject* parent) : QAbstractTableModel(parent) {}

void TableDataModel::setTableData(TableData data) {
    beginResetModel();
    m_data = std::move(data);
    endResetModel();
}

int TableDataModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_data.rows.size());
}

int TableDataModel::columnCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_data.columns.size());
}

QVariant TableDataModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_data.rows.size())
        return {};
    const QVariantList& dong = m_data.rows.at(index.row());
    if (index.column() >= dong.size())
        return {};
    const QVariant& v = dong.at(index.column());
    const QString tieuDe = m_data.columns.value(index.column());

    switch (role) {
    case Qt::DisplayRole:
        return Format::oBang(v, tieuDe);
    case Qt::UserRole:
        return v;
    case Qt::TextAlignmentRole: {
        const int t = v.metaType().id();
        const bool laSo = t == QMetaType::Double || t == QMetaType::Int || t == QMetaType::LongLong ||
                          t == QMetaType::Float || t == QMetaType::UInt || t == QMetaType::ULongLong;
        return QVariant::fromValue(Qt::AlignVCenter | (laSo ? Qt::AlignRight : Qt::AlignLeft));
    }
    case Qt::ForegroundRole: {
        const QString s = v.toString();
        if (s == QStringLiteral("Không đạt") || s == QStringLiteral("Đã hủy") || s == QStringLiteral("Đã khóa") ||
            (tieuDe == QStringLiteral("Còn nợ") && v.toDouble() > 0))
            return QColor(0xDC, 0x26, 0x26);
        if (s == QStringLiteral("Đạt") || s == QStringLiteral("Đã dạy") || s == QStringLiteral("Hoạt động"))
            return QColor(0x15, 0x80, 0x3D);
        return {};
    }
    default:
        return {};
    }
}

QVariant TableDataModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (role == Qt::DisplayRole && orientation == Qt::Horizontal)
        return m_data.columns.value(section);
    return QAbstractTableModel::headerData(section, orientation, role);
}
