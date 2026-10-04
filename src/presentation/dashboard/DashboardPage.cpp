#include "presentation/dashboard/DashboardPage.h"

#include "presentation/common/Format.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/Theme.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/dashboard/RevenueChart.h"

#include <QComboBox>
#include <QDate>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QVBoxLayout>

DashboardPage::DashboardPage(AppServices services, QWidget* parent) : QWidget(parent), m_services(services) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 20);
    v->setSpacing(16);

    auto* top = new QHBoxLayout;
    auto* greeting = new QLabel(tr("Hello, %1").arg(Labels::accountName(m_services.auth.account())), this);
    greeting->setObjectName(QStringLiteral("PageTitle"));
    // Weekday name in the UI language (default QLocale set by I18n)
    auto* today =
        new QLabel(QLocale().toString(QDate::currentDate(), QStringLiteral("dddd, dd/MM/yyyy")), this);
    today->setObjectName(QStringLiteral("Muted"));
    auto* refreshButton = UiHelpers::secondaryButton(tr("Refresh"), QStringLiteral("refresh"), this);
    // The figures of the whole center or of one branch (usp_Dashboard_Stats / fn_MonthlyRevenue @BranchId)
    m_branch = new QComboBox(this);
    m_branch->setObjectName(QStringLiteral("dashboardBranchCombo"));
    m_branch->addItem(tr("Whole center"), QString());
    const auto branches = m_services.catalog.activeBranches();
    if (branches.ok())
        for (const Branch& b : branches.value())
            m_branch->addItem(b.name, b.id);
    else
        m_branchError = branches.error(); // only "Whole center" is left: shown under the figures
    auto* greetingColumn = new QVBoxLayout;
    greetingColumn->addWidget(greeting);
    greetingColumn->addWidget(today);
    top->addLayout(greetingColumn, 1);
    top->addWidget(m_branch, 0, Qt::AlignTop);
    top->addWidget(refreshButton, 0, Qt::AlignTop);
    v->addLayout(top);

    auto* grid = new QGridLayout;
    grid->setSpacing(16);
    grid->addWidget(buildCard(tr("Active students"), QStringLiteral("users"), &m_activeStudents), 0, 0);
    grid->addWidget(buildCard(tr("Active classes"), QStringLiteral("book"), &m_activeClasses), 0, 1);
    grid->addWidget(buildCard(tr("Classes enrolling"), QStringLiteral("award"), &m_enrollingClasses), 0, 2);
    grid->addWidget(buildCard(tr("Revenue this month"), QStringLiteral("chart"), &m_revenue), 1, 0);
    grid->addWidget(buildCard(tr("Outstanding tuition"), QStringLiteral("wallet"), &m_outstanding), 1, 1);
    grid->addWidget(buildCard(tr("Sessions today"), QStringLiteral("calendar"), &m_sessionsToday), 1, 2);
    m_revenue->setProperty("testId", QStringLiteral("revenueKpi"));
    v->addLayout(grid);

    auto* chartCard = UiHelpers::card(this);
    auto* cv = new QVBoxLayout(chartCard);
    cv->setContentsMargins(20, 16, 20, 16);
    auto* chartTitle = new QLabel(tr("Monthly revenue - %1").arg(QDate::currentDate().year()), chartCard);
    chartTitle->setObjectName(QStringLiteral("CardTitle"));
    m_chart = new RevenueChart(chartCard);
    cv->addWidget(chartTitle);
    cv->addWidget(m_chart, 1);
    v->addWidget(chartCard, 1);

    m_error = new QLabel(this);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->hide();
    v->addWidget(m_error);

    connect(refreshButton, &QPushButton::clicked, this, &DashboardPage::reload);
    connect(m_branch, &QComboBox::currentIndexChanged, this, &DashboardPage::reload);
    reload();
}

QWidget* DashboardPage::buildCard(const QString& title, const QString& icon, QLabel** value) {
    auto* card = UiHelpers::card(this);
    auto* h = new QHBoxLayout(card);
    h->setContentsMargins(18, 16, 18, 16);
    auto* iconLabel = new QLabel(card);
    iconLabel->setObjectName(QStringLiteral("KpiIcon"));
    iconLabel->setPixmap(Icons::pixmap(icon, QLatin1String(Theme::kAccent), 24));
    iconLabel->setFixedSize(44, 44);
    iconLabel->setAlignment(Qt::AlignCenter);
    auto* column = new QVBoxLayout;
    auto* titleLabel = new QLabel(title, card);
    titleLabel->setObjectName(QStringLiteral("Muted"));
    *value = new QLabel(QStringLiteral("—"), card);
    (*value)->setObjectName(QStringLiteral("KpiValue"));
    column->addWidget(titleLabel);
    column->addWidget(*value);
    h->addWidget(iconLabel);
    h->addSpacing(8);
    h->addLayout(column, 1);
    return card;
}

void DashboardPage::reload() {
    const QString branchId = m_branch->currentData().toString();
    const auto stats = m_services.statistics.dashboard(branchId);
    if (stats.ok()) {
        const auto& s = stats.value();
        m_activeStudents->setText(QString::number(s.activeStudents));
        m_activeClasses->setText(QString::number(s.activeClasses));
        m_enrollingClasses->setText(QString::number(s.enrollingClasses));
        m_revenue->setText(s.revenueThisMonth ? Format::money(*s.revenueThisMonth) : tr("No permission"));
        m_outstanding->setText(Format::money(s.outstandingTuition));
        m_sessionsToday->setText(QString::number(s.sessionsToday));
        m_error->setText(m_branchError);
        m_error->setVisible(!m_branchError.isEmpty());
    } else {
        m_error->setText(stats.error());
        m_error->show();
    }

    // A role without the revenue right gets NULL from usp_Dashboard_Stats: that is not an error. Any other
    // failure (lost connection, missing GRANT) shows its real message instead of "no permission".
    if (stats.ok() && !stats.value().revenueThisMonth) {
        m_chart->setMessage(tr("No permission to view revenue, or no data yet."));
        return;
    }
    const auto revenue = m_services.statistics.monthlyRevenue(QDate::currentDate().year(), branchId);
    if (revenue.ok())
        m_chart->setData(revenue.value());
    else
        m_chart->setMessage(revenue.error());
}
