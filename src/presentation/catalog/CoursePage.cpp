#include "presentation/catalog/CoursePage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDialog>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QSpinBox>
#include <QVBoxLayout>

CoursePage::CoursePage(AppServices services, QWidget* parent) : DataPage(services, Feature::Courses, parent) {
    const bool edit = canEdit();
    if (edit) {
        addAction(tr("New course"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { editCourse(true); });
        addAction(tr("Edit course"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editCourse(false); });
    }
    addAction(tr("Syllabus"), QStringLiteral("book-open"), QStringLiteral("syllabusButton"), true,
              [this] { showSyllabus(); });
    addAction(tr("Find by skill"), QStringLiteral("search"), QStringLiteral("findBySkillButton"), false,
              [this] { findBySkill(); });
    addAction(tr("Programs"), QStringLiteral("layers"), QStringLiteral("programsButton"), false,
              [this] { showPrograms(); });
    // The grade components of the selected course: their title and buttons sit next to their own table
    auto* componentBar = new QWidget(this);
    auto* bar = new QHBoxLayout(componentBar);
    bar->setContentsMargins(0, 6, 0, 0);
    m_componentsTitle = new QLabel(componentBar);
    m_componentsTitle->setObjectName(QStringLiteral("CardTitle"));
    bar->addWidget(m_componentsTitle, 1);
    if (edit) {
        auto* addComponent =
            UiHelpers::secondaryButton(tr("New grade component"), QStringLiteral("plus"), componentBar);
        addComponent->setObjectName(QStringLiteral("addComponentButton"));
        m_editComponent =
            UiHelpers::secondaryButton(tr("Edit component"), QStringLiteral("edit"), componentBar);
        m_editComponent->setObjectName(QStringLiteral("editComponentButton"));
        m_removeComponent =
            UiHelpers::secondaryButton(tr("Delete component"), QStringLiteral("trash"), componentBar);
        m_removeComponent->setObjectName(QStringLiteral("deleteComponentButton"));
        for (QPushButton* b : {addComponent, m_editComponent, m_removeComponent})
            bar->addWidget(b);
        m_editComponent->setEnabled(false);
        m_removeComponent->setEnabled(false);
        connect(addComponent, &QPushButton::clicked, this, [this] {
            if (!selectedCourseId().isEmpty())
                editComponent(true);
        });
        connect(m_editComponent, &QPushButton::clicked, this, [this] { editComponent(false); });
        connect(m_removeComponent, &QPushButton::clicked, this, &CoursePage::removeComponent);
    }
    addBodyWidget(componentBar);
    m_components = new DataTable(QStringLiteral("componentTable"), this);
    m_components->setHiddenColumns({QStringLiteral("ComponentId")});
    addBodyWidget(m_components, 1);

    connect(table(), &DataTable::selectionChanged, this, &CoursePage::loadComponents);
    connect(m_components, &DataTable::selectionChanged, this, [this] {
        if (m_editComponent) {
            m_editComponent->setEnabled(m_components->hasSelection());
            m_removeComponent->setEnabled(m_components->hasSelection());
        }
    });
    reload();
}

Result<TableData> CoursePage::fetch() {
    return m_services.courses.list();
}

void CoursePage::dataLoaded() {
    if (!table()->hasSelection())
        table()->selectFirstRow();
    loadComponents();
}

QString CoursePage::selectedCourseId() const {
    return selected(QStringLiteral("CourseId")).toString();
}

void CoursePage::loadComponents() {
    m_componentsTitle->setText(tr("Grade components of %1 (the weights must add up to 100%)")
                                   .arg(selected(QStringLiteral("CourseName")).toString()));
    const auto components = m_services.courses.components(selectedCourseId());
    m_components->setData(components.ok() ? components.value() : TableData());
    if (!components.ok())
        m_componentsTitle->setText(components.error());
    if (m_editComponent) {
        m_editComponent->setEnabled(false);
        m_removeComponent->setEnabled(false);
    }
}

void CoursePage::editCourse(bool isNew) {
    Course c;
    if (!isNew) {
        const auto current = m_services.courses.details(selectedCourseId());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        c = current.value();
    }
    const auto programs = m_services.catalog.programOptions();
    const auto courses = m_services.courses.options();
    FormDialog dialog(isNew ? tr("New course") : tr("Edit course %1").arg(c.id), this);
    auto* code = Fields::code(&dialog, c.id);
    code->setEnabled(isNew);
    auto* program =
        Fields::lookup(&dialog, programs.ok() ? programs.value() : QList<LookupItem>(), c.programId);
    auto* name = Fields::text(&dialog, 100, c.name);
    auto* level = new QComboBox(&dialog);
    for (const QString& l : CatalogValues::levels())
        level->addItem(l, l);
    Fields::select(level, c.level);
    auto* sessions = Fields::integer(&dialog, 1, 200, c.sessionCount);
    auto* minutes = Fields::integer(&dialog, 30, 240, c.sessionMinutes);
    auto* tuition = Fields::money(&dialog, c.tuition);
    auto* hasMinimum = new QCheckBox(tr("Entry requires a placement score of at least"), &dialog);
    hasMinimum->setChecked(c.minPlacementScore.has_value());
    auto* minimum = Fields::decimal(&dialog, 0, 10, 2, c.minPlacementScore.value_or(5));
    minimum->setEnabled(hasMinimum->isChecked());
    auto* minimumRow = new QHBoxLayout;
    minimumRow->addWidget(hasMinimum);
    minimumRow->addWidget(minimum);
    auto* prerequisite = Fields::lookup(&dialog, courses.ok() ? courses.value() : QList<LookupItem>(),
                                        c.prerequisiteId, tr("No prerequisite"));
    auto* status = Fields::values(&dialog, CatalogValues::courseStatuses(), c.status);
    status->setEnabled(!isNew);
    dialog.form()->addRow(tr("Course code"), code);
    dialog.form()->addRow(tr("Program"), program);
    dialog.form()->addRow(tr("Course name"), name);
    dialog.form()->addRow(tr("Level (CEFR)"), level);
    dialog.form()->addRow(tr("Sessions"), sessions);
    dialog.form()->addRow(tr("Minutes per session"), minutes);
    dialog.form()->addRow(tr("Tuition"), tuition);
    dialog.form()->addRow(tr("Entry score"), minimumRow);
    dialog.form()->addRow(tr("Prerequisite course"), prerequisite);
    dialog.form()->addRow(tr("Status"), status);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("A student enters when they passed the prerequisite course or "
                                        "reached the entry score in their latest placement test."),
                                     &dialog));
    connect(hasMinimum, &QCheckBox::toggled, minimum, &QWidget::setEnabled);
    QString savedId = c.id;
    dialog.setSaveAction([&] {
        Course course = c;
        course.id = code->text();
        course.programId = Fields::value(program);
        course.name = name->text();
        course.level = Fields::value(level);
        course.sessionCount = sessions->value();
        course.sessionMinutes = minutes->value();
        course.tuition = Fields::moneyValue(tuition);
        course.minPlacementScore =
            hasMinimum->isChecked() ? std::optional<double>(minimum->value()) : std::nullopt;
        course.prerequisiteId = Fields::value(prerequisite);
        course.status = Fields::value(status);
        savedId = course.id.trimmed().toUpper();
        return m_services.courses.save(course, isNew);
    });
    // A failed load of the programs or courses leaves a combo empty: say why
    dialog.showError(!programs.ok() ? programs.error() : (!courses.ok() ? courses.error() : QString()));
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("CourseId"), savedId);
}

// The units of the XML syllabus as a table (usp_Course_Syllabus: .nodes() + CROSS APPLY); the manager can
// also edit the XML document, which SQL Server validates against the schema collection xsc_CourseSyllabus
void CoursePage::showSyllabus() {
    const QString courseId = selectedCourseId();
    const QString courseName = selected(QStringLiteral("CourseName")).toString();
    const auto units = m_services.courses.syllabus(courseId);
    if (!units.ok()) {
        UiHelpers::showError(this, units.error());
        return;
    }
    TableDialog dialog(tr("Syllabus of %1 - %2").arg(courseId, courseName),
                       Labels::accountName(m_services.auth.account()), this);
    dialog.setSubtitle(units.value().rows.isEmpty() ? tr("This course has no syllabus yet.") : QString());
    dialog.setData(units.value());
    if (canEdit()) {
        auto* editButton = UiHelpers::secondaryButton(tr("Edit XML"), QStringLiteral("edit"), &dialog);
        dialog.layout()->addWidget(editButton);
        connect(editButton, &QPushButton::clicked, &dialog, [&] {
            // An editor opened empty after a failed load would delete the syllabus on Save (NULL removes it)
            const auto xml = m_services.courses.syllabusXml(courseId);
            if (!xml.ok()) {
                UiHelpers::showError(&dialog, xml.error());
                return;
            }
            FormDialog editor(tr("Syllabus XML of %1").arg(courseId), &dialog);
            editor.resize(760, 560);
            auto* text = new QPlainTextEdit(xml.value(), &editor);
            text->setObjectName(QStringLiteral("syllabusXmlEdit"));
            editor.body()->addWidget(
                new QLabel(tr("<Syllabus> with <Textbook>, <Objective> and <Unit No=\"1\" "
                              "Sessions=\"6\"> elements (title and skills). Empty = no syllabus."),
                           &editor));
            editor.body()->addWidget(text, 1);
            editor.setSaveAction(
                [&] { return m_services.courses.setSyllabus(courseId, text->toPlainText()); });
            if (editor.exec() == QDialog::Accepted) {
                const auto updated = m_services.courses.syllabus(courseId);
                if (updated.ok())
                    dialog.setData(updated.value());
                reloadAndSelect(QStringLiteral("CourseId"), courseId);
            }
        });
    }
    dialog.exec();
}

// XQuery .exist() with sql:variable (usp_Course_FindBySkill)
void CoursePage::findBySkill() {
    FormDialog ask(tr("Find courses by skill"), this);
    auto* skill = Fields::text(&ask, 50);
    skill->setPlaceholderText(tr("Speaking, Listening, Writing, Grammar..."));
    ask.form()->addRow(tr("Skill"), skill);
    ask.setSaveText(tr("Find"));
    TableData found;
    ask.setSaveAction([&]() -> VoidResult {
        const auto result = m_services.courses.findBySkill(skill->text());
        if (!result.ok())
            return VoidResult::failure(result.error());
        found = result.value();
        return VoidResult::success();
    });
    if (ask.exec() != QDialog::Accepted)
        return;
    TableDialog dialog(tr("Courses that practice %1").arg(skill->text().trimmed()),
                       Labels::accountName(m_services.auth.account()), this);
    dialog.setData(found);
    dialog.exec();
}

void CoursePage::showPrograms() {
    TableDialog dialog(tr("Programs"), Labels::accountName(m_services.auth.account()), this);
    auto load = [&] {
        const auto programs = m_services.catalog.programList();
        dialog.setData(programs.ok() ? programs.value() : TableData());
        dialog.setSubtitle(programs.ok() ? QString() : programs.error());
    };
    load();
    if (canEdit()) {
        auto* buttons = new QHBoxLayout;
        auto* addButton = UiHelpers::secondaryButton(tr("New program"), QStringLiteral("plus"), &dialog);
        auto* editButton = UiHelpers::secondaryButton(tr("Edit program"), QStringLiteral("edit"), &dialog);
        buttons->addWidget(addButton);
        buttons->addWidget(editButton);
        buttons->addStretch(1);
        qobject_cast<QVBoxLayout*>(dialog.layout())->insertLayout(1, buttons);
        auto editProgram = [&](bool isNew) {
            Program p;
            if (!isNew) {
                const auto current = m_services.catalog.program(
                    dialog.table()->selectedValue(QStringLiteral("ProgramId")).toString());
                if (!current.ok()) {
                    UiHelpers::showError(&dialog, current.error());
                    return;
                }
                p = current.value();
            }
            FormDialog form(isNew ? tr("New program") : tr("Edit program %1").arg(p.id), &dialog);
            auto* code = Fields::code(&form, p.id);
            code->setEnabled(isNew);
            auto* name = Fields::text(&form, 100, p.name);
            auto* learners = Fields::text(&form, 100, p.targetLearners);
            auto* description = Fields::text(&form, 500, p.description);
            form.form()->addRow(tr("Program code"), code);
            form.form()->addRow(tr("Program name"), name);
            form.form()->addRow(tr("Target learners"), learners);
            form.form()->addRow(tr("Description"), description);
            form.setSaveAction([&] {
                Program c = p;
                c.id = code->text();
                c.name = name->text();
                c.targetLearners = learners->text();
                c.description = description->text();
                return m_services.catalog.saveProgram(c, isNew);
            });
            if (form.exec() == QDialog::Accepted)
                load();
        };
        connect(addButton, &QPushButton::clicked, &dialog, [editProgram] { editProgram(true); });
        connect(editButton, &QPushButton::clicked, &dialog, [&] {
            if (!dialog.table()->hasSelection()) {
                UiHelpers::showError(&dialog, tr("Please select a program in the list."));
                return;
            }
            editProgram(false);
        });
    }
    dialog.exec();
}

void CoursePage::editComponent(bool isNew) {
    GradeComponent c;
    c.courseId = selectedCourseId();
    if (!isNew) {
        c.id = m_components->selectedValue(QStringLiteral("ComponentId")).toInt();
        c.name = m_components->selectedValue(QStringLiteral("ComponentName")).toString();
        c.weight = m_components->selectedValue(QStringLiteral("Weight")).toDouble();
    }
    FormDialog dialog(isNew ? tr("New grade component") : tr("Edit grade component"), this);
    auto* name = Fields::text(&dialog, 50, c.name);
    auto* weight = Fields::decimal(&dialog, 0.01, 100, 2, isNew ? 10 : c.weight);
    dialog.form()->addRow(tr("Course"),
                          new QLabel(selected(QStringLiteral("CourseName")).toString(), &dialog));
    dialog.form()->addRow(tr("Component name"), name);
    dialog.form()->addRow(tr("Weight (%)"), weight);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("The components of a course whose classes were evaluated cannot "
                                        "change any more (open a new course instead)."),
                                     &dialog));
    dialog.setSaveAction([&] {
        GradeComponent component = c;
        component.name = name->text();
        component.weight = weight->value();
        return m_services.courses.saveComponent(component);
    });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("CourseId"), c.courseId);
}

void CoursePage::removeComponent() {
    const int id = m_components->selectedValue(QStringLiteral("ComponentId")).toInt();
    const QString name = m_components->selectedValue(QStringLiteral("ComponentName")).toString();
    if (!UiHelpers::confirm(this, tr("Delete the grade component %1?").arg(name)))
        return;
    const auto result = m_services.courses.removeComponent(id);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("CourseId"), selectedCourseId());
}
