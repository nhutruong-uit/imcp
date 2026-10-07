#include "presentation/common/DataPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/Theme.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QClipboard>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMenu>
#include <QPushButton>
#include <QShortcut>
#include <QTableView>
#include <QVBoxLayout>

DataPage::DataPage(AppServices services, Feature feature, QWidget* parent)
    : QWidget(parent), m_services(services), m_feature(feature) {
    m_layout = new QVBoxLayout(this);
    m_layout->setContentsMargins(24, 20, 24, 16);
    m_layout->setSpacing(10);

    // Filters on the left, quick filter in the middle, the shared tools on the right
    m_filterBar = new QHBoxLayout;
    m_quickFilter = new QLineEdit(this);
    m_quickFilter->setObjectName(QStringLiteral("quickFilter"));
    m_quickFilter->setPlaceholderText(tr("Quick filter..."));
    m_quickFilter->addAction(Icons::get(QStringLiteral("search"), QLatin1String(Theme::kIconMuted), 16),
                             QLineEdit::LeadingPosition);
    m_quickFilter->setClearButtonEnabled(true);
    m_quickFilter->setToolTip(UiHelpers::withShortcut(tr("Filter the rows shown"), QKeySequence::Find));
    m_quickFilter->setMinimumWidth(180);
    auto* refreshButton = UiHelpers::secondaryButton(tr("Refresh"), QStringLiteral("refresh"), this);
    auto* csvButton = UiHelpers::secondaryButton(tr("Excel"), QStringLiteral("download"), this);
    auto* pdfButton = UiHelpers::secondaryButton(tr("PDF"), QStringLiteral("file"), this);
    auto* printButton = UiHelpers::printPreviewButton(this);
    // Shortcuts of the shown page only: Qt ignores the shortcuts of hidden widgets (the other pages)
    refreshButton->setShortcut(QKeySequence::Refresh);
    refreshButton->setToolTip(UiHelpers::withShortcut(tr("Read the list again"), QKeySequence::Refresh));
    auto* find = new QShortcut(QKeySequence::Find, this);
    connect(find, &QShortcut::activated, this, [this] {
        m_quickFilter->setFocus();
        m_quickFilter->selectAll();
    });
    m_filterBar->addWidget(m_quickFilter, 1);
    m_filterBar->addWidget(refreshButton);
    m_filterBar->addWidget(csvButton);
    m_filterBar->addWidget(pdfButton);
    m_filterBar->addWidget(printButton);
    m_layout->addLayout(m_filterBar);

    // The page's buttons; the row stays hidden while it has none (read-only pages)
    m_actionRow = new QWidget(this);
    m_actionBar = new QHBoxLayout(m_actionRow);
    m_actionBar->setContentsMargins(0, 0, 0, 0);
    m_actionBar->addStretch(1);
    m_actionRow->hide();
    m_layout->addWidget(m_actionRow);

    m_table = new DataTable(QStringLiteral("listTable"), this);
    m_layout->addWidget(m_table, 3);

    m_footer = new QLabel(this);
    m_footer->setProperty("testId", QStringLiteral("totalsLine"));
    m_footer->setObjectName(QStringLiteral("Muted"));
    m_footer->setWordWrap(true);
    m_layout->addWidget(m_footer);

    connect(m_quickFilter, &QLineEdit::textChanged, this, [this](const QString& text) {
        m_table->setFilterText(text);
        m_footer->setText(m_table->totalsText());
    });
    connect(refreshButton, &QPushButton::clicked, this, &DataPage::reload);
    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, m_table->visibleModel(), title()); });
    connect(pdfButton, &QPushButton::clicked, this, [this] {
        UiHelpers::exportPdf(this, m_table->visibleModel(), title(),
                             Labels::accountName(m_services.auth.account()));
    });
    connect(printButton, &QPushButton::clicked, this, &DataPage::previewReport);
    connect(m_table, &DataTable::selectionChanged, this, &DataPage::updateActions);
    m_table->view()->setContextMenuPolicy(Qt::CustomContextMenu);
    connect(m_table->view(), &QWidget::customContextMenuRequested, this, &DataPage::showContextMenu);
}

void DataPage::reload() {
    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto result = fetch();
    QApplication::restoreOverrideCursor();
    if (!result.ok()) {
        m_table->setData({});
        m_footer->setText(result.error());
        return;
    }
    // Keep the selected row after a refresh: the first column is the key of every list (ClassId,
    // ReceiptId...)
    const QString key = m_table->data().columns.value(0);
    const QVariant selectedKey = key.isEmpty() ? QVariant() : m_table->selectedValue(key);
    m_table->setData(result.value());
    if (selectedKey.isValid())
        m_table->selectWhere(key, selectedKey);
    m_footer->setText(m_table->totalsText());
    dataLoaded();
}

void DataPage::reloadAndSelect(const QString& key, const QVariant& value) {
    reload();
    m_table->selectWhere(key, value);
}

void DataPage::addFilter(QWidget* widget) {
    m_filterBar->insertWidget(m_filterBar->indexOf(m_quickFilter), widget);
}

QPushButton* DataPage::addAction(const QString& text, const QString& icon, const QString& objectName,
                                 bool needsSelection, std::function<void()> handler) {
    auto* button = UiHelpers::secondaryButton(text, icon, m_actionRow);
    button->setObjectName(objectName);
    m_actionBar->insertWidget(m_actionBar->count() - 1, button); // before the stretch
    m_actionRow->show();
    m_actions.append(button);
    if (needsSelection) {
        m_selectionActions.append(button);
        button->setEnabled(m_table->hasSelection());
    }
    connect(button, &QPushButton::clicked, this, [handler] { handler(); });
    return button;
}

void DataPage::addBodyWidget(QWidget* widget, int stretch) {
    m_layout->insertWidget(m_layout->indexOf(m_footer), widget, stretch);
}

QVariant DataPage::selected(const QString& key) const {
    return m_table->selectedValue(key);
}

bool DataPage::canEdit() const {
    return Permissions::canEdit(m_services.auth.role(), m_feature);
}

QString DataPage::title() const {
    return Labels::feature(m_feature).name;
}

void DataPage::updateActions() {
    const bool selectedRow = m_table->hasSelection();
    for (QPushButton* button : m_selectionActions)
        button->setEnabled(selectedRow);
}

void DataPage::previewReport() {
    UiHelpers::previewReport(this, m_table->visibleModel(), title(),
                             Labels::accountName(m_services.auth.account()));
}

// Popup menu of the list (Chapter 4 of the course - Menu): the row under the cursor is selected first, then
// the menu offers the page's buttons (same text, same enabled state, so the same permissions), copying the
// cell and the shared tools of the filter bar
void DataPage::showContextMenu(const QPoint& pos) {
    QTableView* view = m_table->view();
    const QModelIndex cell = view->indexAt(pos);
    if (cell.isValid())
        view->selectRow(cell.row());

    QMenu menu(this);
    menu.setObjectName(QStringLiteral("listContextMenu"));
    for (QPushButton* button : std::as_const(m_actions)) {
        if (!button->isVisible())
            continue;
        QAction* action = menu.addAction(button->icon(), button->text(), button, &QPushButton::click);
        action->setEnabled(button->isEnabled());
    }
    if (!menu.isEmpty())
        menu.addSeparator();
    QAction* copy = menu.addAction(tr("Copy cell"), this, [cell] {
        QApplication::clipboard()->setText(cell.data(Qt::DisplayRole).toString());
    });
    copy->setEnabled(cell.isValid());
    menu.addSeparator();
    menu.addAction(Icons::get(QStringLiteral("refresh"), QLatin1String(Theme::kIcon), 16), tr("Refresh"),
                   this, &DataPage::reload);
    menu.addAction(Icons::get(QStringLiteral("download"), QLatin1String(Theme::kIcon), 16),
                   tr("Export to Excel"), this,
                   [this] { UiHelpers::exportCsv(this, m_table->visibleModel(), title()); });
    menu.addAction(Icons::get(QStringLiteral("printer"), QLatin1String(Theme::kIcon), 16),
                   tr("Print preview..."), this, &DataPage::previewReport);
    menu.exec(view->viewport()->mapToGlobal(pos));
}
