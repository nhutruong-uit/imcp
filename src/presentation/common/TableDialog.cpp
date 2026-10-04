#include "presentation/common/TableDialog.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/UiHelpers.h"

#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>

TableDialog::TableDialog(const QString& title, const QString& preparedBy, QWidget* parent)
    : QDialog(parent), m_title(title), m_preparedBy(preparedBy) {
    setWindowTitle(title);
    resize(900, 560);
    auto* v = new QVBoxLayout(this);
    v->setSpacing(10);
    auto* titleLabel = new QLabel(title, this);
    titleLabel->setObjectName(QStringLiteral("PageTitle"));
    titleLabel->setWordWrap(true);
    v->addWidget(titleLabel);
    m_subtitle = new QLabel(this);
    m_subtitle->setObjectName(QStringLiteral("Muted"));
    m_subtitle->setWordWrap(true);
    m_subtitle->hide();
    v->addWidget(m_subtitle);

    m_table = new DataTable(QStringLiteral("dialogTable"), this);
    v->addWidget(m_table, 1);
    m_totals = new QLabel(this);
    m_totals->setObjectName(QStringLiteral("Muted"));
    v->addWidget(m_totals);

    auto* buttons = new QHBoxLayout;
    auto* csvButton = UiHelpers::secondaryButton(tr("Excel"), QStringLiteral("download"), this);
    auto* pdfButton = UiHelpers::secondaryButton(tr("PDF"), QStringLiteral("file"), this);
    auto* closeButton = UiHelpers::primaryButton(tr("Close"), QString(), this);
    buttons->addWidget(csvButton);
    buttons->addWidget(pdfButton);
    buttons->addStretch(1);
    buttons->addWidget(closeButton);
    v->addLayout(buttons);

    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, m_table->visibleModel(), m_title); });
    connect(pdfButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportPdf(this, m_table->visibleModel(), m_title, m_preparedBy); });
    connect(closeButton, &QPushButton::clicked, this, &QDialog::accept);
}

void TableDialog::setSubtitle(const QString& text) {
    m_subtitle->setText(text);
    m_subtitle->setVisible(!text.isEmpty());
}

void TableDialog::setData(TableData data) {
    m_table->setData(std::move(data));
    m_totals->setText(m_table->totalsText());
}
