#include "presentation/main/MainWindow.h"

#include "presentation/common/I18n.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/dashboard/DashboardPage.h"
#include "presentation/lists/ListPage.h"
#include "presentation/main/ChangePasswordDialog.h"
#include "presentation/students/StudentPage.h"

#include <QApplication>
#include <QComboBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QPushButton>
#include <QStackedWidget>
#include <QVBoxLayout>

MainWindow::MainWindow(AppServices services, QWidget* parent) : QMainWindow(parent), m_services(services) {
    setWindowTitle(tr("English Center Management"));
    resize(1280, 780);
    setMinimumSize(1024, 640);

    m_features = Permissions::allowedFeatures(m_services.auth.role());

    auto* central = new QWidget(this);
    auto* h = new QHBoxLayout(central);
    h->setContentsMargins(0, 0, 0, 0);
    h->setSpacing(0);
    h->addWidget(buildSidebar());

    auto* right = new QWidget(central);
    auto* v = new QVBoxLayout(right);
    v->setContentsMargins(0, 0, 0, 0);
    v->setSpacing(0);
    v->addWidget(buildHeader());
    m_content = new QStackedWidget(right);
    m_content->setObjectName(QStringLiteral("Content"));
    v->addWidget(m_content, 1);
    h->addWidget(right, 1);
    setCentralWidget(central);

    connect(m_menu, &QListWidget::currentRowChanged, this, &MainWindow::onMenuRowChanged);
    // Row 0 of the menu is a group header ("GENERAL"), so open the first feature instead of selecting row 0
    if (!m_features.isEmpty())
        openFeature(m_features.first());
}

// Left menu: one entry per allowed feature, grouped under non-clickable group headers. Each entry stores its
// Feature in Qt::UserRole (the item's hidden data); group headers store -1 there.
QWidget* MainWindow::buildSidebar() {
    auto* sidebar = new QFrame(this);
    sidebar->setObjectName(QStringLiteral("Sidebar"));
    sidebar->setFixedWidth(240);
    auto* v = new QVBoxLayout(sidebar);
    v->setContentsMargins(0, 18, 0, 12);
    v->setSpacing(4);

    auto* brand = new QWidget(sidebar);
    auto* bh = new QHBoxLayout(brand);
    bh->setContentsMargins(20, 0, 20, 12);
    auto* logo = new QLabel(brand);
    logo->setPixmap(Icons::pixmap(QStringLiteral("logo"), QStringLiteral("#FFFFFF"), 30));
    auto* name = new QLabel(QStringLiteral("English Center"), brand); // product name, not translated
    name->setObjectName(QStringLiteral("SidebarBrand"));
    bh->addWidget(logo);
    bh->addWidget(name, 1);
    v->addWidget(brand);

    m_menu = new QListWidget(sidebar);
    m_menu->setObjectName(QStringLiteral("NavList"));
    m_menu->setIconSize(QSize(18, 18));
    m_menu->setFocusPolicy(Qt::NoFocus);
    QString previousGroup;
    for (Feature f : m_features) {
        const FeatureInfo info = Labels::feature(f);
        if (info.group != previousGroup) {
            auto* groupHeader = new QListWidgetItem(info.group.toUpper(), m_menu);
            groupHeader->setFlags(Qt::NoItemFlags);
            groupHeader->setData(Qt::UserRole, -1);
            groupHeader->setSizeHint(QSize(0, 30));
            QFont font = groupHeader->font();
            font.setPointSizeF(font.pointSizeF() * 0.8);
            font.setBold(true);
            groupHeader->setFont(font);
            previousGroup = info.group;
        }
        auto* item =
            new QListWidgetItem(Icons::get(info.icon, QStringLiteral("#E2E8F0"), 18), info.name, m_menu);
        item->setData(Qt::UserRole, static_cast<int>(f));
        item->setSizeHint(QSize(0, 40));
    }
    v->addWidget(m_menu, 1);

    auto* user = new QLabel(QStringLiteral("%1\n%2").arg(m_services.auth.account().fullName,
                                                         Labels::role(m_services.auth.role())),
                            sidebar);
    user->setObjectName(QStringLiteral("SidebarUser"));
    v->addWidget(user);
    return sidebar;
}

QWidget* MainWindow::buildHeader() {
    auto* header = new QFrame(this);
    header->setObjectName(QStringLiteral("Header"));
    header->setFixedHeight(60);
    auto* h = new QHBoxLayout(header);
    h->setContentsMargins(24, 0, 16, 0);

    m_title = new QLabel(header);
    m_title->setObjectName(QStringLiteral("HeaderTitle"));
    h->addWidget(m_title, 1);

    auto* role = new QLabel(Labels::role(m_services.auth.role()), header);
    role->setObjectName(QStringLiteral("RoleBadge"));
    role->setFixedHeight(26);
    h->addWidget(role, 0, Qt::AlignVCenter);

    m_languageCombo = UiHelpers::languageSelector(I18n::current(), header);
    auto* passwordButton = UiHelpers::secondaryButton(tr("Change password"), QStringLiteral("key"), header);
    auto* logoutButton = UiHelpers::secondaryButton(tr("Log out"), QStringLiteral("logout"), header);
    h->addWidget(m_languageCombo);
    h->addWidget(passwordButton);
    h->addWidget(logoutButton);

    connect(m_languageCombo, &QComboBox::currentIndexChanged, this, &MainWindow::changeLanguage);
    connect(passwordButton, &QPushButton::clicked, this, &MainWindow::changePassword);
    connect(logoutButton, &QPushButton::clicked, this, [this] {
        if (UiHelpers::confirm(this, tr("Do you want to log out?")))
            emit logoutRequested();
    });
    return header;
}

// The page of a feature: created on first use, then reused (switching back keeps its filters and data).
// Dashboard and Students have their own page; every other feature is a read-only list shown by ListPage.
QWidget* MainWindow::pageFor(Feature feature) {
    const int key = static_cast<int>(feature);
    if (QWidget* existing = m_pages.value(key, nullptr))
        return existing;

    QWidget* page = nullptr;
    switch (feature) {
    case Feature::Dashboard:
        page = new DashboardPage(m_services, m_content);
        break;
    case Feature::Students:
        page = new StudentPage(m_services, m_content);
        break;
    default:
        page = new ListPage(m_services, feature, m_content); // every read-only lookup list
        break;
    }
    m_content->addWidget(page);
    m_pages.insert(key, page);
    return page;
}

void MainWindow::onMenuRowChanged(int row) {
    QListWidgetItem* item = m_menu->item(row);
    if (!item || item->data(Qt::UserRole).toInt() < 0)
        return;
    const auto feature = static_cast<Feature>(item->data(Qt::UserRole).toInt());
    m_title->setText(Labels::feature(feature).name);
    m_content->setCurrentWidget(pageFor(feature));
}

void MainWindow::openFeature(Feature feature) {
    for (int i = 0; i < m_menu->count(); ++i) {
        if (m_menu->item(i)->data(Qt::UserRole).toInt() == static_cast<int>(feature)) {
            m_menu->setCurrentRow(i);
            return;
        }
    }
}

std::optional<Feature> MainWindow::currentFeature() const {
    const QListWidgetItem* item = m_menu->currentItem();
    if (!item || item->data(Qt::UserRole).toInt() < 0)
        return std::nullopt;
    return static_cast<Feature>(item->data(Qt::UserRole).toInt());
}

void MainWindow::changePassword() {
    ChangePasswordDialog dialog(m_services.auth, this);
    dialog.exec();
}

// Saves and loads the new language, then asks main.cpp to rebuild the window (texts are set when widgets are
// created, so a fresh window is simpler than re-translating every widget)
void MainWindow::changeLanguage() {
    const Language selected = languageFromCode(m_languageCombo->currentData().toString());
    if (selected == I18n::current())
        return;
    I18n::switchTo(m_services.language, selected);
    emit languageChangeRequested();
}
