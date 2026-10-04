#include "presentation/classes/ClassFormDialog.h"

#include "application/services/ClassService.h"
#include "presentation/common/Fields.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QSpinBox>

ClassFormDialog::ClassFormDialog(ClassService& service, const QList<Branch>& branches, const ClassInfo& c,
                                 QWidget* parent)
    : FormDialog(c.id.isEmpty() ? tr("New class") : tr("Edit class %1").arg(c.id), parent),
      m_service(service), m_original(c) {
    const bool isNew = c.id.isEmpty();
    m_name = Fields::text(this, ClassLimits::name, c.name);
    m_name->setObjectName(QStringLiteral("classNameEdit"));

    QList<LookupItem> branchItems;
    for (const Branch& b : branches)
        branchItems.append({b.id, b.name});
    m_branch = Fields::lookup(this, branchItems, c.branchId);
    m_branch->setEnabled(isNew);

    const auto courses = m_service.courseOptions();
    m_course = Fields::lookup(this, courses.ok() ? courses.value() : QList<LookupItem>(), c.courseId);
    m_course->setEnabled(isNew); // the course defines the sessions and grades of a class: it never changes
    const auto teachers = m_service.teacherOptions();
    m_teacher = Fields::lookup(this, teachers.ok() ? teachers.value() : QList<LookupItem>(), c.teacherId);
    m_room = new QComboBox(this);
    m_startDate = Fields::date(this, c.startDate.isValid() ? c.startDate : QDate::currentDate().addDays(7));
    m_maxStudents = Fields::integer(this, ClassLimits::minStudents, ClassLimits::maxStudents, c.maxStudents);
    m_tuition = Fields::money(this, c.tuition);

    form()->addRow(tr("Class name"), m_name);
    form()->addRow(tr("Course"), m_course);
    form()->addRow(tr("Branch"), m_branch);
    form()->addRow(tr("Main teacher"), m_teacher);
    form()->addRow(tr("Room"), m_room);
    form()->addRow(tr("Start date"), m_startDate);
    form()->addRow(tr("Maximum size"), m_maxStudents);
    form()->addRow(tr("Tuition"), m_tuition);
    if (!isNew)
        form()->addRow(QString(), new QLabel(tr("A new start date removes the generated sessions; they are "
                                                "generated again from the new date."),
                                             this));

    loadRooms();
    if (isNew)
        courseChanged();
    connect(m_branch, &QComboBox::currentIndexChanged, this, &ClassFormDialog::loadRooms);
    connect(m_course, &QComboBox::currentIndexChanged, this, &ClassFormDialog::courseChanged);
    if (!courses.ok())
        showError(courses.error());
}

// Rooms of the chosen branch (a room of another branch is refused by trg_CLASS_CheckRoom)
void ClassFormDialog::loadRooms() {
    const QString current = m_room->count() > 0 ? Fields::value(m_room) : m_original.roomId;
    const auto rooms = m_service.roomOptions(Fields::value(m_branch));
    Fields::fillLookup(m_room, rooms.ok() ? rooms.value() : QList<LookupItem>());
    if (!current.isEmpty() && m_room->findData(current) >= 0)
        Fields::select(m_room, current);
    else if (!m_original.roomId.isEmpty() && Fields::value(m_branch) == m_original.branchId)
        Fields::select(m_room, m_original.roomId); // a room under maintenance stays the room of the class
}

// A new class costs what its course costs, unless the user types another price
void ClassFormDialog::courseChanged() {
    const auto tuition = m_service.courseTuition(Fields::value(m_course));
    if (tuition.ok())
        m_tuition->setValue(double(tuition.value()));
}

bool ClassFormDialog::save() {
    ClassInfo c = m_original;
    c.name = m_name->text();
    c.courseId = Fields::value(m_course);
    c.branchId = Fields::value(m_branch);
    c.teacherId = Fields::value(m_teacher);
    c.roomId = Fields::value(m_room);
    c.startDate = m_startDate->date();
    c.maxStudents = m_maxStudents->value();
    c.tuition = Fields::moneyValue(m_tuition);
    if (c.id.isEmpty()) {
        const auto result = m_service.add(c);
        if (!result.ok()) {
            showError(result.error());
            return false;
        }
        m_savedId = result.value();
        return true;
    }
    const auto result = m_service.update(c);
    if (!result.ok()) {
        showError(result.error());
        return false;
    }
    m_savedId = c.id;
    m_startDateChanged = c.startDate != m_original.startDate;
    return true;
}
