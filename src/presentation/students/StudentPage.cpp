#include "presentation/students/StudentPage.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/Theme.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/enrollments/EnrollDialog.h"
#include "presentation/placement/PlacementTestDialog.h"
#include "presentation/students/StudentFormDialog.h"
#include "presentation/students/StudentProfileDialog.h"
#include "presentation/students/StudentTableModel.h"

#include <QApplication>
#include <QComboBox>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QItemSelectionModel>
#include <QLabel>
#include <QLineEdit>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QSaveFile>
#include <QSortFilterProxyModel>
#include <QStandardPaths>
#include <QTableView>
#include <QTimer>
#include <QUrl>
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
    m_keyword->addAction(Icons::get(QStringLiteral("search"), QLatin1String(Theme::kIconMuted), 16),
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

    // --- Second row: what can be done with the selected student, and the XML import/export
    auto* actions = new QHBoxLayout;
    m_profileButton = UiHelpers::secondaryButton(tr("Profile"), QStringLiteral("user"), this);
    m_profileButton->setObjectName(QStringLiteral("profileButton"));
    actions->addWidget(m_profileButton);
    if (m_canEdit) {
        m_enrollButton = UiHelpers::secondaryButton(tr("Enroll"), QStringLiteral("user-plus"), this);
        m_enrollButton->setObjectName(QStringLiteral("enrollButton"));
        m_testButton = UiHelpers::secondaryButton(tr("Placement test"), QStringLiteral("clipboard"), this);
        m_testButton->setObjectName(QStringLiteral("placementTestButton"));
        auto* exportButton = UiHelpers::secondaryButton(tr("Export XML"), QStringLiteral("download"), this);
        auto* importButton = UiHelpers::secondaryButton(tr("Import XML"), QStringLiteral("upload"), this);
        actions->addWidget(m_enrollButton);
        actions->addWidget(m_testButton);
        actions->addSpacing(12);
        actions->addWidget(exportButton);
        actions->addWidget(importButton);
        connect(m_enrollButton, &QPushButton::clicked, this, &StudentPage::enroll);
        connect(m_testButton, &QPushButton::clicked, this, &StudentPage::placementTest);
        connect(exportButton, &QPushButton::clicked, this, &StudentPage::exportXml);
        connect(importButton, &QPushButton::clicked, this, &StudentPage::importXml);
    }
    actions->addStretch(1);
    v->addLayout(actions);
    connect(m_profileButton, &QPushButton::clicked, this, &StudentPage::showProfile);

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
    connect(m_table->selectionModel(), &QItemSelectionModel::selectionChanged, this,
            &StudentPage::updateButtons);

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
        UiHelpers::exportPdf(this, *m_proxy, tr("Student list"),
                             Labels::accountName(m_services.auth.account()));
    });

    const auto branches = m_services.students.branches();
    if (branches.ok()) {
        m_branches = branches.value();
        for (const Branch& b : m_branches)
            m_branchFilter->addItem(b.name, b.id);
    } else {
        UiHelpers::showError(this, branches.error()); // otherwise the form has no branch to choose
    }
    search();
}

// Runs usp_Student_Search with the current filters (typing waits 300 ms, see m_searchDelay)
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
    updateButtons();
}

// The buttons for one student need a selected row
void StudentPage::updateButtons() {
    const bool selected = m_table->selectionModel()->hasSelection();
    for (QPushButton* b : {m_editButton, m_deleteButton, m_profileButton, m_enrollButton, m_testButton})
        if (b)
            b->setEnabled(selected);
}

void StudentPage::showProfile() {
    const Student* selected = selectedStudent();
    if (!selected)
        return;
    StudentProfileDialog dialog(m_services, selected->id, this);
    dialog.exec();
}

void StudentPage::enroll() {
    const Student* selected = selectedStudent();
    if (!selected)
        return;
    const QString id = selected->id; // a copy: the list is searched again below
    EnrollDialog dialog(m_services.enrollments, m_services.students, id, QString(), this);
    if (dialog.exec() == QDialog::Accepted) {
        QMessageBox::information(this, tr("Student enrolled"),
                                 tr("Enrollment %1 was created.").arg(dialog.enrollmentId()));
        search();
        selectById(id);
    }
}

void StudentPage::placementTest() {
    const Student* selected = selectedStudent();
    if (!selected)
        return;
    const QString id = selected->id;
    PlacementTestDialog dialog(m_services.placement, m_services.students, id, this);
    if (dialog.exec() != QDialog::Accepted)
        return;
    const PlacementResult r = dialog.result();
    const QString overall = QLocale().toString(r.overallScore, 'f', 2);
    QMessageBox::information(
        this, tr("Placement test saved"),
        r.recommendedCourse.isEmpty()
            ? tr("Overall score %1. No open course matches this score.").arg(overall)
            : tr("Overall score %1. Recommended course: %2.").arg(overall, r.recommendedCourse));
}

// FOR XML PATH export of the students of the chosen branch (every branch when none is chosen)
void StudentPage::exportXml() {
    const QString branchId = m_branchFilter->currentData().toString();
    const auto xml = m_services.students.exportXml(branchId);
    if (!xml.ok()) {
        UiHelpers::showError(this, xml.error());
        return;
    }
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString path = QFileDialog::getSaveFileName(this, tr("Export students to XML"),
                                                      QDir(folder).filePath(QStringLiteral("students.xml")),
                                                      QStringLiteral("XML (*.xml)"));
    if (path.isEmpty())
        return;
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        UiHelpers::showError(this, file.errorString());
        return;
    }
    file.write(QByteArrayLiteral("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"));
    file.write(xml.value().toUtf8());
    if (!file.commit())
        UiHelpers::showError(this, file.errorString());
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

// usp_Student_ImportXml: shreds the file with .nodes(); rows with a phone/email already in use are skipped
void StudentPage::importXml() {
    const QString branchId = m_branchFilter->currentData().toString();
    if (branchId.isEmpty()) {
        UiHelpers::showError(this,
                             tr("Choose the branch of the imported students in the branch filter first."));
        return;
    }
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString path = QFileDialog::getOpenFileName(this, tr("Import students from XML"), folder,
                                                      QStringLiteral("XML (*.xml)"));
    if (path.isEmpty())
        return;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        UiHelpers::showError(this, file.errorString());
        return;
    }
    const QString xml = QString::fromUtf8(file.readAll());
    if (!UiHelpers::confirm(this, tr("Import the students of %1 into %2?")
                                      .arg(QFileInfo(path).fileName(), m_branchFilter->currentText())))
        return;
    const auto result = m_services.students.importXml(xml, branchId);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    QMessageBox::information(
        this, tr("Import finished"),
        tr("%1 students imported, %2 skipped (phone or email already used, or no name or "
           "date of birth).")
            .arg(result.value().imported)
            .arg(result.value().skipped));
    search();
}

const Student* StudentPage::selectedStudent() const {
    const QModelIndex index = m_table->currentIndex();
    if (!index.isValid())
        return nullptr;
    return m_model->studentAt(m_proxy->mapToSource(index).row());
}

// After add/edit: select the saved student in the refreshed list so the user sees the result
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
    Student student = details.value();
    student.branchName = selected->branchName; // usp_Student_Details has only the BranchId
    StudentFormDialog dialog(m_services.students, m_branches, student, this);
    if (dialog.exec() == QDialog::Accepted) {
        search();
        selectById(dialog.savedStudentId());
    }
}

void StudentPage::remove() {
    m_searchDelay->stop(); // a pending search would reload the list while the confirmation is open
    const Student* selected = selectedStudent();
    if (!selected) {
        UiHelpers::showError(this, tr("Please select a student in the list."));
        return;
    }
    // Copies: the pointer points into the model, which must not be read again after the dialog's event loop
    const QString id = selected->id;
    const QString name = selected->fullName;
    if (!UiHelpers::confirm(this, tr("Delete student %1 - %2?").arg(id, name)))
        return;
    const auto result = m_services.students.remove(id);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    search();
}
