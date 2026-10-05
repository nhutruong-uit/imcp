#include "presentation/catalog/BranchPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QDateEdit>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QSpinBox>

BranchPage::BranchPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Branches, parent) {
    if (canEdit()) {
        addAction(tr("New branch"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { editBranch(true); });
        addAction(tr("Edit branch"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editBranch(false); });
    }
    // The rooms of the selected branch: their title and buttons sit next to their own table
    auto* roomBar = new QWidget(this);
    auto* bar = new QHBoxLayout(roomBar);
    bar->setContentsMargins(0, 6, 0, 0);
    m_roomsTitle = new QLabel(roomBar);
    m_roomsTitle->setObjectName(QStringLiteral("CardTitle"));
    bar->addWidget(m_roomsTitle, 1);
    if (canEdit()) {
        m_addRoom = UiHelpers::secondaryButton(tr("New room"), QStringLiteral("plus"), roomBar);
        m_addRoom->setObjectName(QStringLiteral("addRoomButton"));
        m_editRoom = UiHelpers::secondaryButton(tr("Edit room"), QStringLiteral("edit"), roomBar);
        m_editRoom->setObjectName(QStringLiteral("editRoomButton"));
        m_editRoom->setEnabled(false);
        bar->addWidget(m_addRoom);
        bar->addWidget(m_editRoom);
        connect(m_addRoom, &QPushButton::clicked, this, [this] { editRoom(true); });
        connect(m_editRoom, &QPushButton::clicked, this, [this] { editRoom(false); });
    }
    addBodyWidget(roomBar);
    m_rooms = new DataTable(QStringLiteral("roomTable"), this);
    addBodyWidget(m_rooms, 2);

    connect(table(), &DataTable::selectionChanged, this, &BranchPage::loadRooms);
    connect(m_rooms, &DataTable::selectionChanged, this, [this] {
        if (m_editRoom)
            m_editRoom->setEnabled(m_rooms->hasSelection());
    });
    connect(m_rooms, &DataTable::activated, this, [this] {
        if (canEdit())
            editRoom(false);
    });
    reload();
}

Result<TableData> BranchPage::fetch() {
    return m_services.catalog.branchList();
}

void BranchPage::dataLoaded() {
    if (!table()->hasSelection())
        table()->selectFirstRow();
    loadRooms();
}

void BranchPage::loadRooms() {
    // A refresh of the list above calls this three times (the reset clears the selection, the row is selected
    // again, dataLoaded): the second list is read once per row shown. The reset clears the row first, so a
    // refresh still reads it again.
    const QString branchId = selected(QStringLiteral("BranchId")).toString();
    if (!branchId.isEmpty() && branchId == m_roomsOf)
        return;
    m_roomsOf = branchId;
    m_roomsTitle->setText(tr("Rooms of %1").arg(selected(QStringLiteral("BranchName")).toString()));
    const auto rooms =
        branchId.isEmpty() ? Result<TableData>::success(TableData()) : m_services.catalog.roomList(branchId);
    m_rooms->setData(rooms.ok() ? rooms.value() : TableData());
    // An empty list without a reason would look like a branch without rooms
    if (!rooms.ok())
        m_roomsTitle->setText(rooms.error());
    if (m_editRoom)
        m_editRoom->setEnabled(false);
}

void BranchPage::editBranch(bool isNew) {
    Branch b;
    if (!isNew) {
        const auto current = m_services.catalog.branch(selected(QStringLiteral("BranchId")).toString());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        b = current.value();
    }
    FormDialog dialog(isNew ? tr("New branch") : tr("Edit branch %1").arg(b.id), this);
    auto* code = Fields::code(&dialog, b.id);
    code->setObjectName(QStringLiteral("codeEdit"));
    code->setEnabled(isNew);
    auto* name = Fields::text(&dialog, 100, b.name);
    auto* address = Fields::text(&dialog, 200, b.address);
    auto* phone = Fields::digits(&dialog, 11, b.phone);
    auto* email = Fields::text(&dialog, 100, b.email);
    // BRANCH.FoundedOn is optional: an existing branch without it shows "Not recorded" (the first date of the
    // field) and keeps NULL unless a date is chosen; before, saving the form wrote today's date silently
    auto* founded = Fields::date(&dialog, b.foundedOn);
    founded->setMinimumDate(QDate(1900, 1, 1));
    founded->setSpecialValueText(tr("Not recorded"));
    if (!isNew && !b.foundedOn.isValid())
        founded->setDate(founded->minimumDate());
    auto* status = Fields::values(&dialog, CatalogValues::branchStatuses(), b.status);
    status->setEnabled(!isNew);
    dialog.form()->addRow(tr("Branch code"), code);
    dialog.form()->addRow(tr("Branch name"), name);
    dialog.form()->addRow(tr("Address"), address);
    dialog.form()->addRow(tr("Phone"), phone);
    dialog.form()->addRow(tr("Email"), email);
    dialog.form()->addRow(tr("Founded on"), founded);
    dialog.form()->addRow(tr("Status"), status);
    dialog.setSaveAction([&] {
        Branch c = b;
        c.id = code->text();
        c.name = name->text();
        c.address = address->text();
        c.phone = phone->text();
        c.email = email->text();
        c.foundedOn = founded->date() == founded->minimumDate() ? QDate() : founded->date();
        c.status = Fields::value(status);
        b.id = c.id.trimmed().toUpper();
        return m_services.catalog.saveBranch(c, isNew);
    });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("BranchId"), b.id);
}

void BranchPage::editRoom(bool isNew) {
    Room r;
    r.branchId = selected(QStringLiteral("BranchId")).toString();
    if (!isNew) {
        const auto current =
            m_services.catalog.room(m_rooms->selectedValue(QStringLiteral("RoomId")).toString());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        r = current.value();
    }
    QString branchError;
    const QList<LookupItem> branchItems =
        Fields::branchItems(m_services.catalog.activeBranches(), &branchError);
    FormDialog dialog(isNew ? tr("New room") : tr("Edit room %1").arg(r.id), this);
    auto* code = Fields::code(&dialog, r.id);
    code->setEnabled(isNew);
    auto* branch = Fields::lookup(&dialog, branchItems, r.branchId);
    auto* name = Fields::text(&dialog, 50, r.name);
    auto* capacity =
        Fields::integer(&dialog, CatalogLimits::minRoomCapacity, CatalogLimits::maxRoomCapacity, r.capacity);
    auto* type = Fields::values(&dialog, CatalogValues::roomTypes(), r.type);
    auto* status = Fields::values(&dialog, CatalogValues::roomStatuses(), r.status);
    status->setEnabled(!isNew);
    dialog.form()->addRow(tr("Room code"), code);
    dialog.form()->addRow(tr("Branch"), branch);
    dialog.form()->addRow(tr("Room name"), name);
    dialog.form()->addRow(tr("Seats"), capacity);
    dialog.form()->addRow(tr("Room type"), type);
    dialog.form()->addRow(tr("Status"), status);
    dialog.setSaveAction([&] {
        Room c = r;
        c.id = code->text();
        c.branchId = Fields::value(branch);
        c.name = name->text();
        c.capacity = capacity->value();
        c.type = Fields::value(type);
        c.status = Fields::value(status);
        return m_services.catalog.saveRoom(c, isNew);
    });
    dialog.showError(branchError); // empty: no error line
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("BranchId"), r.branchId);
}
