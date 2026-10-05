#include "presentation/sessions/TimetablePage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Format.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/sessions/AttendanceDialog.h"

#include <QComboBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>

TimetablePage::TimetablePage(AppServices services, Feature feature, QWidget* parent)
    : DataPage(services, feature, parent), m_week(SessionService::weekStart(QDate::currentDate())) {
    auto* previous = UiHelpers::secondaryButton(QString(), QStringLiteral("chevron-left"), this);
    previous->setObjectName(QStringLiteral("previousWeekButton"));
    previous->setToolTip(tr("Previous week"));
    auto* thisWeek = UiHelpers::secondaryButton(tr("This week"), QString(), this);
    auto* next = UiHelpers::secondaryButton(QString(), QStringLiteral("chevron-right"), this);
    next->setToolTip(tr("Next week"));
    m_weekLabel = new QLabel(this);
    m_weekLabel->setObjectName(QStringLiteral("CardTitle"));
    addFilter(previous);
    addFilter(thisWeek);
    addFilter(next);
    addFilter(m_weekLabel);
    table()->setHiddenColumns({QStringLiteral("SessionId")});

    if (canEdit()) {
        addAction(tr("Update session"), QStringLiteral("edit"), QStringLiteral("updateSessionButton"), true,
                  [this] { updateSession(); });
        addAction(tr("Attendance"), QStringLiteral("check"), QStringLiteral("attendanceButton"), true,
                  [this] { takeAttendance(); });
    }
    connect(previous, &QPushButton::clicked, this, [this] { moveWeek(-1); });
    connect(next, &QPushButton::clicked, this, [this] { moveWeek(1); });
    connect(thisWeek, &QPushButton::clicked, this, [this] {
        m_week = SessionService::weekStart(QDate::currentDate());
        reload();
    });
    connect(table(), &DataTable::activated, this, [this] {
        if (canEdit())
            takeAttendance();
    });
    reload();
}

Result<TableData> TimetablePage::fetch() {
    m_weekLabel->setText(tr("%1 - %2").arg(Format::date(m_week), Format::date(m_week.addDays(6))));
    return m_services.sessions.week(m_week, mineOnly());
}

void TimetablePage::moveWeek(int weeks) {
    m_week = m_week.addDays(7 * weeks);
    reload();
}

QString TimetablePage::sessionTitle() const {
    return tr("%1 - %2, session %3, %4")
        .arg(selected(QStringLiteral("ClassId")).toString(), selected(QStringLiteral("ClassName")).toString(),
             selected(QStringLiteral("SessionNo")).toString(),
             Format::date(selected(QStringLiteral("SessionDate")).toDate()));
}

void TimetablePage::updateSession() {
    const int sessionId = selected(QStringLiteral("SessionId")).toInt();
    const QDate date = selected(QStringLiteral("SessionDate")).toDate();
    FormDialog dialog(tr("Update session"), this);
    dialog.form()->addRow(tr("Session"), new QLabel(sessionTitle(), &dialog));
    auto* status =
        Fields::values(&dialog, SessionValues::statuses(), selected(QStringLiteral("Status")).toString());
    status->setObjectName(QStringLiteral("sessionStatusCombo"));
    auto* description =
        Fields::text(&dialog, SessionLimits::description, selected(QStringLiteral("Description")).toString());
    description->setPlaceholderText(tr("Content of the lesson"));
    dialog.form()->addRow(tr("Status"), status);
    dialog.form()->addRow(tr("Content"), description);
    dialog.setSaveAction([&] {
        SessionUpdate u;
        u.sessionId = sessionId;
        u.sessionDate = date;
        u.status = Fields::value(status);
        u.description = description->text();
        return m_services.sessions.update(u, QDate::currentDate());
    });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("SessionId"), sessionId);
}

void TimetablePage::takeAttendance() {
    const int sessionId = selected(QStringLiteral("SessionId")).toInt();
    AttendanceDialog dialog(m_services.sessions, sessionId, sessionTitle(), this);
    dialog.exec();
}
