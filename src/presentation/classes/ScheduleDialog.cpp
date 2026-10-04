#include "presentation/classes/ScheduleDialog.h"

#include "application/services/ClassService.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/Format.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QTimeEdit>
#include <QVBoxLayout>

ScheduleDialog::ScheduleDialog(ClassService& service, const QString& classId, const QString& className,
                               bool canEdit, QWidget* parent)
    : QDialog(parent), m_service(service), m_classId(classId) {
    setWindowTitle(tr("Weekly schedule - %1").arg(className));
    resize(560, 440);
    auto* v = new QVBoxLayout(this);
    auto* title = new QLabel(tr("Weekly schedule of %1 - %2").arg(classId, className), this);
    title->setObjectName(QStringLiteral("PageTitle"));
    title->setWordWrap(true);
    v->addWidget(title);
    m_table = new DataTable(QStringLiteral("scheduleTable"), this);
    v->addWidget(m_table, 1);

    // One slot per weekday: saving a weekday that has a slot changes its hours
    auto* editor = new QHBoxLayout;
    m_weekday = new QComboBox(this);
    for (int day = 1; day <= 7; ++day)
        m_weekday->addItem(Format::weekday(day), day);
    m_start = Fields::time(this, QTime(18, 0));
    m_end = Fields::time(this, QTime(20, 0));
    auto* saveButton = UiHelpers::primaryButton(tr("Save slot"), QStringLiteral("check"), this);
    saveButton->setObjectName(QStringLiteral("saveSlotButton"));
    auto* removeButton = UiHelpers::secondaryButton(tr("Remove slot"), QStringLiteral("trash"), this);
    editor->addWidget(new QLabel(tr("Weekday"), this));
    editor->addWidget(m_weekday);
    editor->addWidget(new QLabel(tr("From"), this));
    editor->addWidget(m_start);
    editor->addWidget(new QLabel(tr("To"), this));
    editor->addWidget(m_end);
    editor->addWidget(saveButton);
    editor->addWidget(removeButton);
    v->addLayout(editor);
    for (QWidget* w :
         {static_cast<QWidget*>(m_weekday), static_cast<QWidget*>(m_start), static_cast<QWidget*>(m_end),
          static_cast<QWidget*>(saveButton), static_cast<QWidget*>(removeButton)})
        w->setVisible(canEdit);

    auto* note =
        new QLabel(tr("Existing sessions do not change: generate the sessions again on the Classes page "
                      "while none has been taught."),
                   this);
    note->setObjectName(QStringLiteral("Muted"));
    note->setWordWrap(true);
    note->setVisible(canEdit);
    v->addWidget(note);
    m_error = new QLabel(this);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->setWordWrap(true);
    m_error->hide();
    v->addWidget(m_error);
    auto* closeButton = UiHelpers::secondaryButton(tr("Close"), QString(), this);
    v->addWidget(closeButton, 0, Qt::AlignRight);

    connect(saveButton, &QPushButton::clicked, this, &ScheduleDialog::saveSlot);
    connect(removeButton, &QPushButton::clicked, this, &ScheduleDialog::removeSlot);
    connect(closeButton, &QPushButton::clicked, this, &QDialog::accept);
    // Selecting a slot copies it into the editor, ready to change or remove
    connect(m_table, &DataTable::selectionChanged, this, [this] {
        if (!m_table->hasSelection())
            return;
        m_weekday->setCurrentIndex(
            m_weekday->findData(m_table->selectedValue(QStringLiteral("Weekday")).toInt()));
        m_start->setTime(QTime::fromString(m_table->selectedValue(QStringLiteral("StartTime")).toString(),
                                           QStringLiteral("HH:mm")));
        m_end->setTime(QTime::fromString(m_table->selectedValue(QStringLiteral("EndTime")).toString(),
                                         QStringLiteral("HH:mm")));
    });
    reload();
}

void ScheduleDialog::reload() {
    const auto slotsResult = m_service.schedule(m_classId);
    if (!slotsResult.ok()) {
        showError(slotsResult.error());
        return;
    }
    // The same column keys as usp_ClassSchedule_ByClass, so the catalog gives the titles and day names
    TableData data;
    data.columns = {QStringLiteral("Weekday"), QStringLiteral("StartTime"), QStringLiteral("EndTime")};
    for (const ScheduleSlot& slot : slotsResult.value())
        data.rows.append({slot.weekday, slot.start.toString(QStringLiteral("HH:mm")),
                          slot.end.toString(QStringLiteral("HH:mm"))});
    m_table->setData(data);
}

void ScheduleDialog::saveSlot() {
    ScheduleSlot slot;
    slot.weekday = m_weekday->currentData().toInt();
    slot.start = m_start->time();
    slot.end = m_end->time();
    const auto result = m_service.saveSlot(m_classId, slot);
    if (!result.ok()) {
        showError(result.error());
        return;
    }
    m_changed = true;
    m_error->hide();
    reload();
}

void ScheduleDialog::removeSlot() {
    const int weekday = m_weekday->currentData().toInt();
    if (!UiHelpers::confirm(this, tr("Remove the %1 slot?").arg(Format::weekday(weekday))))
        return;
    const auto result = m_service.removeSlot(m_classId, weekday);
    if (!result.ok()) {
        showError(result.error());
        return;
    }
    m_changed = true;
    m_error->hide();
    reload();
}

void ScheduleDialog::showError(const QString& message) {
    m_error->setText(message);
    m_error->show();
}
