#include "presentation/sessions/AttendanceDialog.h"

#include "application/services/SessionService.h"
#include "presentation/common/Fields.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QTableWidget>
#include <QVBoxLayout>

namespace {
enum Column { StudentId, StudentName, Status, Notes, ColumnCount };
}

AttendanceDialog::AttendanceDialog(SessionService& service, int sessionId, const QString& title,
                                   QWidget* parent)
    : QDialog(parent), m_service(service), m_sessionId(sessionId) {
    setWindowTitle(tr("Attendance"));
    resize(760, 560);
    auto* v = new QVBoxLayout(this);
    auto* titleLabel = new QLabel(tr("Attendance - %1").arg(title), this);
    titleLabel->setObjectName(QStringLiteral("PageTitle"));
    titleLabel->setWordWrap(true);
    v->addWidget(titleLabel);
    auto* hint =
        new QLabel(tr("Students without a saved mark show Present. Present and Late count as attended "
                      "(at least 80% are needed to pass)."),
                   this);
    hint->setObjectName(QStringLiteral("Muted"));
    hint->setWordWrap(true);
    v->addWidget(hint);

    m_table = new QTableWidget(0, ColumnCount, this);
    m_table->setObjectName(QStringLiteral("attendanceTable"));
    m_table->setHorizontalHeaderLabels({tr("Student ID"), tr("Full name"), tr("Status"), tr("Notes")});
    m_table->verticalHeader()->hide();
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->setSelectionMode(QAbstractItemView::NoSelection);
    m_table->setEnabled(true);
    v->addWidget(m_table, 1);

    m_error = new QLabel(this);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->setWordWrap(true);
    m_error->hide();
    v->addWidget(m_error);

    auto* buttons = new QHBoxLayout;
    auto* allPresent = UiHelpers::secondaryButton(tr("All present"), QStringLiteral("check"), this);
    auto* saveButton = UiHelpers::primaryButton(tr("Save attendance"), QStringLiteral("check"), this);
    saveButton->setObjectName(QStringLiteral("saveAttendanceButton"));
    auto* closeButton = UiHelpers::secondaryButton(tr("Close"), QString(), this);
    // Return in a Notes cell reaches the dialog, which clicks its first auto-default button: "All present"
    // would reset the marks just chosen. No button reacts to Return here.
    for (QPushButton* button : {allPresent, saveButton, closeButton})
        button->setAutoDefault(false);
    buttons->addWidget(allPresent);
    buttons->addStretch(1);
    buttons->addWidget(saveButton);
    buttons->addWidget(closeButton);
    v->addLayout(buttons);

    connect(allPresent, &QPushButton::clicked, this, [this] { setAll(AttendanceValues::present()); });
    connect(saveButton, &QPushButton::clicked, this, &AttendanceDialog::save);
    connect(closeButton, &QPushButton::clicked, this, &QDialog::reject);
    load();
}

void AttendanceDialog::load() {
    const auto result = m_service.attendance(m_sessionId);
    if (!result.ok()) {
        m_error->setText(result.error());
        m_error->show();
        return;
    }
    m_marks = result.value();
    m_table->setRowCount(int(m_marks.size()));
    for (int r = 0; r < m_marks.size(); ++r) {
        const AttendanceMark& m = m_marks.at(r);
        auto* id = new QTableWidgetItem(m.studentId);
        auto* name =
            new QTableWidgetItem(m.saved ? m.studentName : tr("%1 (not saved yet)").arg(m.studentName));
        for (QTableWidgetItem* item : {id, name})
            item->setFlags(Qt::ItemIsEnabled);
        m_table->setItem(r, StudentId, id);
        m_table->setItem(r, StudentName, name);
        m_table->setCellWidget(r, Status, Fields::values(m_table, AttendanceValues::statuses(), m.status));
        auto* notes = Fields::text(m_table, SessionLimits::attendanceNotes, m.notes);
        m_table->setCellWidget(r, Notes, notes);
    }
    m_table->resizeColumnsToContents();
}

void AttendanceDialog::setAll(const QString& status) {
    for (int r = 0; r < m_table->rowCount(); ++r)
        Fields::select(qobject_cast<QComboBox*>(m_table->cellWidget(r, Status)), status);
}

void AttendanceDialog::save() {
    QList<AttendanceMark> marks = m_marks;
    for (int r = 0; r < marks.size(); ++r) {
        marks[r].status = Fields::value(qobject_cast<QComboBox*>(m_table->cellWidget(r, Status)));
        marks[r].notes = qobject_cast<QLineEdit*>(m_table->cellWidget(r, Notes))->text();
    }
    const auto result = m_service.saveAttendance(m_sessionId, marks);
    if (!result.ok()) {
        m_error->setText(result.error());
        m_error->show();
        return;
    }
    accept();
}
