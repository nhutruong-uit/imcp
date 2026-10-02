#include "presentation/students/StudentPage.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/students/StudentFormDialog.h"
#include "presentation/students/StudentTableModel.h"

#include <QApplication>
#include <QComboBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QSortFilterProxyModel>
#include <QTableView>
#include <QTimer>
#include <QVBoxLayout>

StudentPage::StudentPage(AppServices services, QWidget* parent) : QWidget(parent), m_services(services) {
    m_canEdit = Permissions::canEditStudents(m_services.auth.role());

    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(12);

    // --- Toolbar: filters on the left, actions on the right
    auto* toolbar = new QHBoxLayout;
    m_keyword = new QLineEdit(this);
    m_keyword->setObjectName(QStringLiteral("searchEdit"));
    m_keyword->setPlaceholderText(tr("Search by ID, name, phone..."));
    m_keyword->addAction(Icons::get(QStringLiteral("search"), QStringLiteral("#94A3B8"), 16),
                         QLineEdit::LeadingPosition);
    m_keyword->setClearButtonEnabled(true);
    m_keyword->setMinimumWidth(220);
    m_branchFilter = new QComboBox(this);
    m_branchFilter->addItem(tr("All branches"), QString());
    m_statusFilter = new QComboBox(this);
    m_statusFilter->addItem(tr("All statuses"), QString());
    for (const QString& status : StudentValues::statuses())
        m_statusFilter->addItem(DbValues::label(status),
                                status); // shown translated, filtered by stored value
    toolbar->addWidget(m_keyword, 1);
    toolbar->addWidget(m_branchFilter);
    toolbar->addWidget(m_statusFilter);
    toolbar->addSpacing(12);

    auto* addButton = UiHelpers::primaryButton(tr("Add"), QStringLiteral("plus"), this);
    addButton->setObjectName(QStringLiteral("addButton"));
    m_editButton = UiHelpers::secondaryButton(tr("Edit"), QStringLiteral("edit"), this);
    m_editButton->setObjectName(QStringLiteral("editButton"));
    m_deleteButton = UiHelpers::secondaryButton(tr("Delete"), QStringLiteral("trash"), this);
    m_deleteButton->setObjectName(QStringLiteral("deleteButton"));
    auto* csvButton = UiHelpers::secondaryButton(tr("Excel"), QStringLiteral("download"), this);
    auto* pdfButton = UiHelpers::secondaryButton(tr("PDF"), QStringLiteral("file"), this);
    addButton->setVisible(m_canEdit);
    m_editButton->setVisible(m_canEdit);
    m_deleteButton->setVisible(m_canEdit);
    toolbar->addWidget(addButton);
    toolbar->addWidget(m_editButton);
    toolbar->addWidget(m_deleteButton);
    toolbar->addWidget(csvButton);
    toolbar->addWidget(pdfButton);
    v->addLayout(toolbar);

    // --- Data table
    m_model = new StudentTableModel(this);
    m_proxy = new QSortFilterProxyModel(this);
    m_proxy->setSourceModel(m_model);
    m_proxy->setSortRole(Qt::UserRole);
    m_proxy->setSortLocaleAware(true);
    m_table = new QTableView(this);
    m_table->setObjectName(QStringLiteral("studentTable"));
    m_table->setModel(m_proxy);
    m_table->setSortingEnabled(true);
    m_table->horizontalHeader()->setSortIndicator(-1,
                                                  Qt::AscendingOrder); // keep the ORDER BY of the database
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setAlternatingRowColors(true);
    m_table->verticalHeader()->hide();
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    v->addWidget(m_table, 1);

    m_count = new QLabel(this);
    m_count->setProperty("testId", QStringLiteral("studentCount"));
    m_count->setObjectName(QStringLiteral("Muted"));
    v->addWidget(m_count);

    // Search automatically 300 ms after the user stops typing
    m_searchDelay = new QTimer(this);
    m_searchDelay->setSingleShot(true);
    m_searchDelay->setInterval(300);
    connect(m_searchDelay, &QTimer::timeout, this, &StudentPage::search);
    connect(m_keyword, &QLineEdit::textChanged, m_searchDelay, qOverload<>(&QTimer::start));
    connect(m_branchFilter, &QComboBox::currentIndexChanged, this, &StudentPage::search);
    connect(m_statusFilter, &QComboBox::currentIndexChanged, this, &StudentPage::search);
    connect(addButton, &QPushButton::clicked, this, &StudentPage::add);
    connect(m_editButton, &QPushButton::clicked, this, &StudentPage::edit);
    connect(m_deleteButton, &QPushButton::clicked, this, &StudentPage::remove);
    connect(m_table, &QTableView::doubleClicked, this, [this] {
        if (m_canEdit)
            edit();
    });
    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, *m_proxy, tr("StudentList")); });
    connect(pdfButton, &QPushButton::clicked, this, [this] {
        UiHelpers::exportPdf(this, *m_proxy, tr("Student list"), m_services.auth.account().fullName);
    });

    const auto branches = m_services.students.branches();
    if (branches.ok()) {
        m_branches = branches.value();
        for (const Branch& b : m_branches)
            m_branchFilter->addItem(b.name, b.id);
    }
    search();
}

void StudentPage::search() {
    StudentFilter filter;
    filter.keyword = m_keyword->text();
    filter.branchId = m_branchFilter->currentData().toString();
    filter.status = m_statusFilter->currentData().toString();

    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto result = m_services.students.search(filter);
    QApplication::restoreOverrideCursor();
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    m_model->setStudents(result.value());
    m_count->setText(tr("%1 students").arg(result.value().size()));
}

const Student* StudentPage::selectedStudent() const {
    const QModelIndex index = m_table->currentIndex();
    if (!index.isValid())
        return nullptr;
    return m_model->studentAt(m_proxy->mapToSource(index).row());
}

void StudentPage::selectById(const QString& id) {
    for (int r = 0; r < m_proxy->rowCount(); ++r) {
        const QModelIndex index = m_proxy->index(r, StudentTableModel::Id);
        if (index.data().toString() == id) {
            m_table->selectRow(r);
            m_table->scrollTo(index);
            return;
        }
    }
}

void StudentPage::add() {
    StudentFormDialog dialog(m_services.students, m_branches, Student{}, this);
    if (dialog.exec() == QDialog::Accepted) {
        search();
        selectById(dialog.savedStudentId());
    }
}

void StudentPage::edit() {
    const Student* selected = selectedStudent();
    if (!selected) {
        UiHelpers::showError(this, tr("Please select a student in the list."));
        return;
    }
    const auto details = m_services.students.details(selected->id);
    if (!details.ok()) {
        UiHelpers::showError(this, details.error());
        return;
    }
    StudentFormDialog dialog(m_services.students, m_branches, details.value(), this);
    if (dialog.exec() == QDialog::Accepted) {
        search();
        selectById(dialog.savedStudentId());
    }
}

void StudentPage::remove() {
    const Student* selected = selectedStudent();
    if (!selected) {
        UiHelpers::showError(this, tr("Please select a student in the list."));
        return;
    }
    if (!UiHelpers::confirm(this, tr("Delete student %1 - %2?").arg(selected->id, selected->fullName)))
        return;
    const auto result = m_services.students.remove(selected->id);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    search();
}
