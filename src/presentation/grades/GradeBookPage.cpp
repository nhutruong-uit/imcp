#include "presentation/grades/GradeBookPage.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Labels.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/grades/GradeBookModel.h"

#include <QApplication>
#include <QComboBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QTableView>
#include <QVBoxLayout>

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
    m_saveButton = UiHelpers::primaryButton(tr("Save grades"), QStringLiteral("check"), this);
    m_saveButton->setObjectName(QStringLiteral("saveGradesButton"));
    bar->addWidget(new QLabel(tr("Class"), this));
    bar->addWidget(m_class, 1);
    bar->addWidget(refreshButton);
    bar->addWidget(csvButton);
    bar->addWidget(pdfButton);
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

    const auto classes = m_services.grades.classes(mineOnly());
    if (classes.ok()) {
        m_classes = classes.value();
        for (const ClassOption& c : m_classes)
            m_class->addItem(QStringLiteral("%1 - %2 (%3)").arg(c.id, c.name, DbValues::label(c.status)),
                             c.id);
    } else {
        m_footer->setText(classes.error());
    }

    connect(m_class, &QComboBox::currentIndexChanged, this, [this] {
        // Leaving a class with typed but unsaved scores would lose them without a word
        reload();
    });
    connect(refreshButton, &QPushButton::clicked, this, &GradeBookPage::reload);
    connect(m_saveButton, &QPushButton::clicked, this, &GradeBookPage::save);
    connect(m_model, &GradeBookModel::changed, this, &GradeBookPage::updateFooter);
    connect(csvButton, &QPushButton::clicked, this,
            [this] { UiHelpers::exportCsv(this, *m_model, classTitle()); });
    connect(pdfButton, &QPushButton::clicked, this, [this] {
        UiHelpers::exportPdf(this, *m_model, classTitle(), Labels::accountName(m_services.auth.account()));
    });
    reload();
}

QString GradeBookPage::classTitle() const {
    return tr("Grade book %1").arg(m_class->currentText());
}

void GradeBookPage::reload() {
    const QString classId = m_class->currentData().toString();
    if (classId.isEmpty()) {
        m_model->setBook({}, false);
        return;
    }
    if (m_model->hasChanges() && UiHelpers::confirm(this, tr("Save the scores you typed before reloading?")))
        save();
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
    const bool editable = Permissions::canEdit(m_services.auth.role(), m_feature) && !finished;
    m_model->setBook(book.value(), editable);
    m_saveButton->setVisible(editable);

    const double total = book.value().totalWeight();
    QStringList info;
    info << tr("Double-click a score to change it (0 to 10), then save.");
    if (finished)
        info = QStringList{tr("The class has finished: its grades are final.")};
    if (!book.value().components.isEmpty() && qAbs(total - 100) > 0.001)
        info << tr("Warning: the weights of the course add up to %1%, not 100%: the class cannot be "
                   "evaluated.")
                    .arg(QLocale().toString(total, 'f', 0));
    m_info->setText(info.join(QLatin1Char(' ')));
}

void GradeBookPage::save() {
    const QList<GradeEntry> entries = m_model->changes();
    if (entries.isEmpty())
        return;
    const auto result = m_services.grades.save(entries);
    if (!result.ok()) {
        UiHelpers::showError(this, result.error());
        return;
    }
    const QString classId = m_class->currentData().toString();
    const auto book = m_services.grades.book(classId, mineOnly());
    if (book.ok())
        m_model->setBook(book.value(), m_saveButton->isVisible());
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
