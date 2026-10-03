#include "presentation/reports/RevenuePage.h"

#include "presentation/common/Fields.h"

#include <QComboBox>
#include <QDateEdit>

RevenuePage::RevenuePage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Revenue, parent) {
    m_view = new QComboBox(this);
    m_view->setObjectName(QStringLiteral("revenueViewCombo"));
    m_view->addItem(tr("By month"), 0);
    m_view->addItem(tr("By course, for a period"), 1);
    // The current month so far by default
    const QDate today = QDate::currentDate();
    m_from = Fields::date(this, QDate(today.year(), today.month(), 1));
    m_to = Fields::date(this, today);
    m_branch = new QComboBox(this);
    m_branch->addItem(tr("All branches"), QString());
    const auto branches = m_services.catalog.activeBranches();
    if (branches.ok())
        for (const Branch& b : branches.value())
            m_branch->addItem(b.name, b.id);
    addFilter(m_view);
    addFilter(m_from);
    addFilter(m_to);
    addFilter(m_branch);

    connect(m_view, &QComboBox::currentIndexChanged, this, &RevenuePage::viewChanged);
    connect(m_from, &QDateEdit::dateChanged, this, &RevenuePage::reload);
    connect(m_to, &QDateEdit::dateChanged, this, &RevenuePage::reload);
    connect(m_branch, &QComboBox::currentIndexChanged, this, &RevenuePage::reload);
    viewChanged();
}

// The period and branch only apply to the report by course
void RevenuePage::viewChanged() {
    const bool period = m_view->currentData().toInt() == 1;
    m_from->setVisible(period);
    m_to->setVisible(period);
    m_branch->setVisible(period);
    reload();
}

Result<TableData> RevenuePage::fetch() {
    if (m_view->currentData().toInt() == 0)
        return m_services.lists.fetch(Feature::Revenue);
    return m_services.statistics.revenueReport(m_from->date(), m_to->date(),
                                               m_branch->currentData().toString());
}
