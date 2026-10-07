#include "presentation/grades/GradeBookPage.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Labels.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/grades/GradeBookModel.h"

#include <QApplication>
#include <QComboBox>
#include <QDoubleValidator>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QKeyEvent>
#include <QLabel>
#include <QLineEdit>
#include <QLocale>
#include <QPushButton>
#include <QSignalBlocker>
#include <QStyledItemDelegate>
#include <QTableView>
#include <QVBoxLayout>
#include <functional>

namespace {
// Editor of a score cell: a text field that accepts 0-10 with at most 2 decimals (GRADE.Score is
// DECIMAL(4,2)) in the number format of the UI language. Without it a cell with a score got an unbounded spin
// box and an empty cell a free text field. An empty field leaves the cell as it was; a value out of range
// (11) is not saved and onInvalid tells the user why.
class ScoreDelegate : public QStyledItemDelegate {
public:
    ScoreDelegate(std::function<void()> onInvalid, QObject* parent)
        : QStyledItemDelegate(parent), m_onInvalid(std::move(onInvalid)) {}

    QWidget* createEditor(QWidget* parent, const QStyleOptionViewItem&, const QModelIndex&) const override {
        auto* editor = new QLineEdit(parent);
        auto* validator =
            new QDoubleValidator(GradeLimits::minScore, GradeLimits::maxScore, GradeLimits::decimals, editor);
        validator->setNotation(QDoubleValidator::StandardNotation);
        editor->setValidator(validator);
        editor->setAlignment(Qt::AlignRight | Qt::AlignVCenter);
        return editor;
    }

    void setEditorData(QWidget* editor, const QModelIndex& index) const override {
        const QVariant score = index.data(Qt::EditRole);
        static_cast<QLineEdit*>(editor)->setText(
            score.isValid() ? QLocale().toString(score.toDouble(), 'f', GradeLimits::decimals) : QString());
    }

    void setModelData(QWidget* editor, QAbstractItemModel* model, const QModelIndex& index) const override {
        const auto* field = static_cast<QLineEdit*>(editor);
        if (field->text().trimmed().isEmpty())
            return;
        if (!field->hasAcceptableInput()) {
            m_onInvalid();
            return;
        }
        model->setData(index, field->text(), Qt::EditRole);
    }

protected:
    // Return with a value out of range keeps the editor open (Qt does not commit unacceptable input): say why
    bool eventFilter(QObject* object, QEvent* event) override {
        if (event->type() == QEvent::KeyPress) {
            const int key = static_cast<QKeyEvent*>(event)->key();
            const auto* field = qobject_cast<QLineEdit*>(object);
            if (field && (key == Qt::Key_Return || key == Qt::Key_Enter) &&
                !field->text().trimmed().isEmpty() && !field->hasAcceptableInput())
                m_onInvalid();
        }
        return QStyledItemDelegate::eventFilter(object, event);
    }

private:
    std::function<void()> m_onInvalid;
};
} // namespace

GradeBookPage::GradeBookPage(AppServices services, Feature feature, QWidget* parent)
    : QWidget(parent), m_services(services), m_feature(feature) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(10);

    auto* bar = new QHBoxLayout;
    m_class = new QComboBox(this);
    m_class->setObjectName(QStringLiteral("classCombo"));
    m_class->setMinimumWidth(320);
    auto* refreshButton = UiHelpers::secondaryButton(tr("Refresh"), QStringLiteral("refresh"), this);
    auto* csvButton = UiHelpers::secondaryButton(tr("Excel"), QStringLiteral("download"), this);
    auto* pdfButton = UiHelpers::secondaryButton(tr("PDF"), QStringLiteral("file"), this);
    auto* printButton = UiHelpers::printPreviewButton(this);
    m_saveButton = UiHelpers::primaryButton(tr("Save grades"), QStringLiteral("check"), this);
    m_saveButton->setObjectName(QStringLiteral("saveGradesButton"));
    bar->addWidget(new QLabel(tr("Class"), this));
    bar->addWidget(m_class, 1);
    bar->addWidget(refreshButton);
    bar->addWidget(csvButton);
    bar->addWidget(pdfButton);
    bar->addWidget(printButton);
    bar->addWidget(m_saveButton);
    v->addLayout(bar);

    m_info = new QLabel(this);
    m_info->setObjectName(QStringLiteral("Muted"));
    m_info->setWordWrap(true);
    v->addWidget(m_info);

    m_model = new GradeBookModel(this);
    m_table = new QTableView(this);
    m_table->setObjectName(QStringLiteral("listTable"));
    m_table->setModel(m_model);
    m_table->setAlternatingRowColors(true);
    m_table->verticalHeader()->hide();
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    m_table->setEditTriggers(QAbstractItemView::DoubleClicked | QAbstractItemView::EditKeyPressed |
                             QAbstractItemView::AnyKeyPressed);
    v->addWidget(m_table, 1);

    m_footer = new QLabel(this);
    m_footer->setObjectName(QStringLiteral("Muted"));
    m_footer->setProperty("testId", QStringLiteral("totalsLine"));
    v->addWidget(m_footer);

    m_table->setItemDelegate(new ScoreDelegate(
        [this] { m_footer->setText(tr("Scores are between 0 and 10, with at most 2 decimals.")); }, m_table));

    loadClasses();
    connect(m_class, &QComboBox::currentIndexChanged, this, [this] {
        // Leaving a class with typed but unsaved scores would lose them without a word
        reload();
    });
    // Refresh also reads the class list again: the page stays open between visits (MainWindow::pageFor), so a
    // class created or evaluated meanwhile appears with its new status
    connect(refreshButton, &QPushButton::clicked, this, [this] {
        loadClasses();
        reload();
    });
    connect(m_saveButton, &QPushButton::clicked, this, &GradeBookPage::save);
    connect(m_model, &GradeBookModel::changed, this, &GradeBookPage::updateFooter);
    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, *m_model, classTitle()); });
    connect(pdfButton, &QPushButton::clicked, this, [this] {
        UiHelpers::exportPdf(this, *m_model, classTitle(), Labels::accountName(m_services.auth.account()));
    });
    connect(printButton, &QPushButton::clicked, this, [this] {
        UiHelpers::previewReport(this, *m_model, classTitle(),
                                 Labels::accountName(m_services.auth.account()));
    });
    reload();
}

QString GradeBookPage::classTitle() const {
    return tr("Grade book %1").arg(m_class->currentText());
}

// The classes of the combo box; the selected class stays selected when it is still in the list. A failed load
// keeps the list shown before and says why above the table (the footer is rewritten by every change).
void GradeBookPage::loadClasses() {
    const QString current = m_class->currentData().toString();
    const auto classes = m_services.grades.classes(mineOnly());
    m_classError = classes.ok() ? QString() : classes.error();
    if (!classes.ok())
        return;
    m_classes = classes.value();
    const QSignalBlocker blocker(m_class); // reload() runs once, after the list is complete
    m_class->clear();
    for (const ClassOption& c : m_classes)
        m_class->addItem(QStringLiteral("%1 - %2 (%3)").arg(c.id, c.name, DbValues::label(c.status)), c.id);
    m_class->setCurrentIndex(qMax(0, m_class->findData(current)));
}

void GradeBookPage::reload() {
    // Typed scores are saved first when the user wants it; when saving fails they stay, with their class
    if (m_model->hasChanges() &&
        UiHelpers::confirm(this, tr("Save the scores you typed before reloading?")) && !save()) {
        const QSignalBlocker blocker(m_class);
        m_class->setCurrentIndex(qMax(0, m_class->findData(m_shownClassId)));
        return;
    }
    const QString classId = m_class->currentData().toString();
    m_shownClassId = classId;
    m_editable = false;
    m_saveButton->setVisible(false);
    if (classId.isEmpty()) {
        m_model->setBook({}, false);
        m_info->setText(m_classError);
        return;
    }
    QString status;
    for (const ClassOption& c : m_classes)
        if (c.id == classId)
            status = c.status;
    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto book = m_services.grades.book(classId, mineOnly());
    QApplication::restoreOverrideCursor();
    if (!book.ok()) {
        m_model->setBook({}, false);
        m_footer->setText(book.error());
        return;
    }
    const bool finished = status == ClassValues::finished();
    m_editable = Permissions::canEdit(m_services.auth.role(), m_feature) && !finished;
    m_model->setBook(book.value(), m_editable);
    m_saveButton->setVisible(m_editable);

    const double total = book.value().totalWeight();
    QStringList info;
    if (!m_classError.isEmpty())
        info << m_classError;
    info << (finished ? tr("The class has finished: its grades are final.")
                      : tr("Double-click a score to change it (0 to 10), then save."));
    if (!book.value().components.isEmpty() && !book.value().weightsComplete())
        info << tr("Warning: the weights of the course add up to %1%, not 100%: the class cannot be "
                   "evaluated.")
                    .arg(QLocale().toString(total)); // 99.99, not a rounded 100
    m_info->setText(info.join(QLatin1Char(' ')));
}

// true when nothing was typed or every score was saved; the book of the class shown is then read again
bool GradeBookPage::save() {
    const QList<GradeEntry> entries = m_model->changes();
    if (entries.isEmpty())
        return true;
    const auto result = m_services.grades.save(entries);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return false;
    }
    const auto book = m_services.grades.book(m_shownClassId, mineOnly());
    if (book.ok())
        m_model->setBook(book.value(), m_editable);
    return true;
}

void GradeBookPage::updateFooter() {
    int complete = 0;
    for (int r = 0; r < m_model->book().rows.size(); ++r)
        if (m_model->book().finalGrade(r))
            ++complete;
    QString text = tr("%1 students, %2 with every score").arg(m_model->book().rows.size()).arg(complete);
    if (m_model->hasChanges())
        text += QStringLiteral("   •   ") + tr("%1 scores not saved yet").arg(m_model->changes().size());
    m_footer->setText(text);
}
