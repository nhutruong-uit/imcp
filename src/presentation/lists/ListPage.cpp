#include "presentation/lists/ListPage.h"

#include "presentation/common/Columns.h"
#include "presentation/common/Format.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDataModel.h"
#include "presentation/common/Theme.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QSortFilterProxyModel>
#include <QTableView>
#include <QVBoxLayout>

ListPage::ListPage(AppServices services, Feature feature, QWidget* parent)
    : QWidget(parent), m_services(services), m_feature(feature) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(12);

    auto* toolbar = new QHBoxLayout;
    m_filter = new QLineEdit(this);
    m_filter->setObjectName(QStringLiteral("quickFilter"));
    m_filter->setPlaceholderText(tr("Quick filter..."));
    m_filter->addAction(Icons::get(QStringLiteral("search"), QLatin1String(Theme::kIconMuted), 16),
                        QLineEdit::LeadingPosition);
    m_filter->setClearButtonEnabled(true);
    auto* refreshButton = UiHelpers::secondaryButton(tr("Refresh"), QStringLiteral("refresh"), this);
    auto* csvButton = UiHelpers::secondaryButton(tr("Excel"), QStringLiteral("download"), this);
    auto* pdfButton = UiHelpers::primaryButton(tr("Export PDF report"), QStringLiteral("file"), this);
    toolbar->addWidget(m_filter, 1);
    toolbar->addWidget(refreshButton);
    toolbar->addWidget(csvButton);
    toolbar->addWidget(pdfButton);
    v->addLayout(toolbar);

    // The proxy model sits between the data and the table: it filters and sorts the rows without changing
    // the data (filter key column -1 = search in every column; sort by the raw value of Qt::UserRole, so
    // money and dates sort as numbers/dates, not as text)
    m_model = new TableDataModel(this);
    m_proxy = new QSortFilterProxyModel(this);
    m_proxy->setSourceModel(m_model);
    m_proxy->setFilterCaseSensitivity(Qt::CaseInsensitive);
    m_proxy->setFilterKeyColumn(-1);
    m_proxy->setSortRole(Qt::UserRole);
    m_proxy->setSortLocaleAware(true);

    m_table = new QTableView(this);
    m_table->setObjectName(QStringLiteral("listTable"));
    m_table->setModel(m_proxy);
    m_table->setSortingEnabled(true);
    m_table->horizontalHeader()->setSortIndicator(-1,
                                                  Qt::AscendingOrder); // keep the ORDER BY of the database
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setAlternatingRowColors(true);
    m_table->verticalHeader()->hide();
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    v->addWidget(m_table, 1);

    m_totals = new QLabel(this);
    m_totals->setProperty("testId", QStringLiteral("totalsLine"));
    m_totals->setObjectName(QStringLiteral("Muted"));
    v->addWidget(m_totals);

    connect(m_filter, &QLineEdit::textChanged, this, [this](const QString& text) {
        m_proxy->setFilterFixedString(text);
        updateTotals();
    });
    connect(refreshButton, &QPushButton::clicked, this, &ListPage::reload);
    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, *m_proxy, Labels::feature(m_feature).name); });
    connect(pdfButton, &QPushButton::clicked, this, [this] {
        UiHelpers::exportPdf(this, *m_proxy, Labels::feature(m_feature).name,
                             Labels::accountName(m_services.auth.account()));
    });
    reload();
}

void ListPage::reload() {
    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto result = m_services.lists.fetch(m_feature);
    QApplication::restoreOverrideCursor();
    if (!result.ok()) {
        m_model->setTableData({});
        m_totals->setText(result.error());
        return;
    }
    m_model->setTableData(result.value());
    updateTotals();
}

// "N rows - Total ...: x" line under the table, computed on the rows that pass the quick filter
void ListPage::updateTotals() {
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
    m_totals->setText(parts.join(QStringLiteral("   •   ")));
}
