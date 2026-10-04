#include "presentation/common/DataTable.h"

#include "presentation/common/Columns.h"
#include "presentation/common/Format.h"
#include "presentation/common/TableDataModel.h"

#include <QHeaderView>
#include <QItemSelectionModel>
#include <QRegularExpression>
#include <QSortFilterProxyModel>
#include <QTableView>
#include <QVBoxLayout>
#include <functional>

namespace {
// The quick filter searches the visible columns only: a row must not match on a hidden technical ID
class QuickFilterProxy : public QSortFilterProxyModel {
public:
    QuickFilterProxy(std::function<bool(int)> isHidden, QObject* parent)
        : QSortFilterProxyModel(parent), m_isHidden(std::move(isHidden)) {}

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override {
        const QRegularExpression& pattern = filterRegularExpression();
        if (pattern.pattern().isEmpty())
            return true;
        for (int c = 0; c < sourceModel()->columnCount(sourceParent); ++c) {
            if (m_isHidden(c))
                continue;
            const QModelIndex cell = sourceModel()->index(sourceRow, c, sourceParent);
            if (cell.data(filterRole()).toString().contains(pattern))
                return true;
        }
        return false;
    }

private:
    std::function<bool(int)> m_isHidden;
};

// What the exports read: the rows as the user sees them, without the hidden columns
class ExportProxy : public QSortFilterProxyModel {
public:
    ExportProxy(std::function<bool(int)> isHidden, QObject* parent)
        : QSortFilterProxyModel(parent), m_isHidden(std::move(isHidden)) {}

protected:
    bool filterAcceptsColumn(int sourceColumn, const QModelIndex&) const override {
        return !m_isHidden(sourceColumn);
    }

private:
    std::function<bool(int)> m_isHidden;
};
} // namespace

DataTable::DataTable(const QString& tableObjectName, QWidget* parent) : QWidget(parent) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(0, 0, 0, 0);

    // The proxy model sits between the data and the table: it filters and sorts the rows without changing the
    // data (the quick filter searches every visible column; sort by the raw value of Qt::UserRole, so money
    // and dates sort as numbers/dates, not as text). A second proxy drops the hidden columns for the exports.
    m_model = new TableDataModel(this);
    const auto isHidden = [this](int column) {
        const QStringList& keys = m_model->tableData().columns;
        return column >= 0 && column < keys.size() && m_hidden.contains(keys.at(column));
    };
    m_proxy = new QuickFilterProxy(isHidden, this);
    m_proxy->setSourceModel(m_model);
    m_proxy->setFilterCaseSensitivity(Qt::CaseInsensitive);
    m_proxy->setSortRole(Qt::UserRole);
    m_proxy->setSortLocaleAware(true);
    m_exportProxy = new ExportProxy(isHidden, this);
    m_exportProxy->setSourceModel(m_proxy);

    m_view = new QTableView(this);
    m_view->setObjectName(tableObjectName);
    m_view->setModel(m_proxy);
    m_view->setSortingEnabled(true);
    m_view->horizontalHeader()->setSortIndicator(-1, Qt::AscendingOrder); // keep the ORDER BY of the database
    m_view->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_view->setSelectionMode(QAbstractItemView::SingleSelection);
    m_view->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_view->setAlternatingRowColors(true);
    m_view->verticalHeader()->hide();
    m_view->horizontalHeader()->setStretchLastSection(true);
    m_view->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    v->addWidget(m_view);

    connect(m_view->selectionModel(), &QItemSelectionModel::selectionChanged, this,
            &DataTable::selectionChanged);
    connect(m_view, &QTableView::activated, this, &DataTable::activated);
}

void DataTable::setData(TableData data) {
    m_model->setTableData(std::move(data));
    applyHiddenColumns();
    emit selectionChanged(); // a reset clears the selection
}

const TableData& DataTable::data() const {
    return m_model->tableData();
}

const QAbstractItemModel& DataTable::visibleModel() const {
    return *m_exportProxy;
}

void DataTable::setFilterText(const QString& text) {
    m_proxy->setFilterFixedString(text);
}

void DataTable::setHiddenColumns(const QStringList& keys) {
    m_hidden = keys;
    applyHiddenColumns();
    m_proxy->invalidate(); // the quick filter and the exports read m_hidden
    m_exportProxy->invalidate();
}

void DataTable::applyHiddenColumns() {
    const QStringList& keys = m_model->tableData().columns;
    for (int c = 0; c < keys.size(); ++c)
        m_view->setColumnHidden(c, m_hidden.contains(keys.at(c)));
}

int DataTable::columnOf(const QString& key) const {
    return int(m_model->tableData().columns.indexOf(key));
}

int DataTable::rowCount() const {
    return m_proxy->rowCount();
}

bool DataTable::hasSelection() const {
    return m_view->selectionModel()->hasSelection();
}

QVariant DataTable::selectedValue(const QString& key) const {
    const QModelIndexList rows = m_view->selectionModel()->selectedRows();
    if (rows.isEmpty())
        return {};
    return valueAt(rows.first().row(), key);
}

QVariant DataTable::valueAt(int row, const QString& key) const {
    const int column = columnOf(key);
    if (column < 0 || row < 0 || row >= m_proxy->rowCount())
        return {};
    return m_proxy->index(row, column).data(Qt::UserRole);
}

bool DataTable::selectWhere(const QString& key, const QVariant& value) {
    const int column = columnOf(key);
    if (column < 0)
        return false;
    for (int r = 0; r < m_proxy->rowCount(); ++r) {
        const QModelIndex index = m_proxy->index(r, column);
        if (index.data(Qt::UserRole).toString() == value.toString()) {
            m_view->selectRow(r);
            m_view->scrollTo(index);
            return true;
        }
    }
    return false;
}

void DataTable::selectFirstRow() {
    if (m_proxy->rowCount() > 0)
        m_view->selectRow(0);
}

QString DataTable::totalsText() const {
    QStringList parts{tr("%1 rows").arg(m_proxy->rowCount())};
    const QStringList& keys = m_model->tableData().columns;
    for (int c = 0; c < keys.size(); ++c) {
        if (!Columns::isSummable(keys.at(c)))
            continue;
        double total = 0;
        for (int r = 0; r < m_proxy->rowCount(); ++r)
            total += m_proxy->index(r, c).data(Qt::UserRole).toDouble();
        parts << QStringLiteral("%1: %2").arg(Columns::totalLabel(keys.at(c)),
                                              Format::money(static_cast<qint64>(total)));
    }
    return parts.join(QStringLiteral("   •   "));
}
