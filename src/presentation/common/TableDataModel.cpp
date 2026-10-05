#include "presentation/common/TableDataModel.h"

#include "presentation/common/Columns.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/Theme.h"

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
    const QVariantList& row = m_data.rows.at(index.row());
    if (index.column() >= row.size())
        return {};
    const QVariant& value = row.at(index.column());
    const QString key = m_data.columns.value(index.column());

    switch (role) {
    case Qt::DisplayRole:
        return Format::cell(value, key);
    case Qt::UserRole:
        return value;
    case Qt::TextAlignmentRole: {
        const int t = value.metaType().id();
        const bool isNumber = t == QMetaType::Double || t == QMetaType::Int || t == QMetaType::LongLong ||
                              t == QMetaType::Float || t == QMetaType::UInt || t == QMetaType::ULongLong;
        return QVariant::fromValue(Qt::AlignVCenter | (isNumber ? Qt::AlignRight : Qt::AlignLeft));
    }
    case Qt::ForegroundRole:
        // Decided from the column key and the STORED value, never from the displayed (translated) text
        if (Columns::isDebt(key))
            return value.toDouble() > 0 ? QVariant(QColor(Theme::kNegativeText)) : QVariant();
        if (!Columns::isEnumerated(key))
            return {}; // free text (names...) is never highlighted, even if it looks like a status
        switch (DbValues::tone(value.toString())) {
        case DbValues::Tone::Positive:
            return QColor(Theme::kPositiveText);
        case DbValues::Tone::Negative:
            return QColor(Theme::kNegativeText);
        case DbValues::Tone::Neutral:
            break;
        }
        return {};
    default:
        return {};
    }
}

QVariant TableDataModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (orientation == Qt::Horizontal) {
        if (role == Qt::DisplayRole)
            return Columns::title(m_data.columns.value(section));
        if (role == Columns::KeyRole)
            return m_data.columns.value(section);
    }
    return QAbstractTableModel::headerData(section, orientation, role);
}
