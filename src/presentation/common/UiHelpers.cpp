#include "presentation/common/UiHelpers.h"

#include "presentation/common/Icons.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableExporter.h"
#include "presentation/common/Theme.h"

#include <QComboBox>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QFrame>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QStandardPaths>
#include <QUrl>

namespace {
// Provides tr() with translation context "UiHelpers" for the free functions of namespace UiHelpers
struct UiText {
    Q_DECLARE_TR_FUNCTIONS(UiHelpers)
};
} // namespace

QPushButton* UiHelpers::primaryButton(const QString& text, const QString& icon, QWidget* parent) {
    auto* b = new QPushButton(text, parent);
    b->setProperty("variant", QStringLiteral("primary"));
    if (!icon.isEmpty())
        b->setIcon(Icons::get(icon, QLatin1String(Theme::kIconOnDark), 16));
    b->setCursor(Qt::PointingHandCursor);
    return b;
}

QPushButton* UiHelpers::secondaryButton(const QString& text, const QString& icon, QWidget* parent) {
    auto* b = new QPushButton(text, parent);
    if (!icon.isEmpty())
        b->setIcon(Icons::get(icon, QLatin1String(Theme::kIcon), 16));
    b->setCursor(Qt::PointingHandCursor);
    return b;
}

QLabel* UiHelpers::pageTitle(const QString& text, QWidget* parent) {
    auto* l = new QLabel(text, parent);
    l->setObjectName(QStringLiteral("PageTitle"));
    return l;
}

QFrame* UiHelpers::card(QWidget* parent) {
    auto* f = new QFrame(parent);
    f->setProperty("card", true);
    return f;
}

void UiHelpers::showError(QWidget* parent, const QString& message) {
    QMessageBox::warning(parent, UiText::tr("Could not complete the action"), message);
}

bool UiHelpers::confirm(QWidget* parent, const QString& question) {
    // Qt ships no Vietnamese translation for its standard buttons (Yes/No), so the button text is set here
    QMessageBox box(QMessageBox::Question, UiText::tr("Confirm"), question,
                    QMessageBox::Yes | QMessageBox::No, parent);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(UiText::tr("Yes"));
    box.button(QMessageBox::No)->setText(UiText::tr("No"));
    return box.exec() == QMessageBox::Yes;
}

void UiHelpers::exportCsv(QWidget* parent, const QAbstractItemModel& model, const QString& suggestedName) {
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString path = QFileDialog::getSaveFileName(
        parent, UiText::tr("Export to Excel (CSV)"),
        QDir(folder).filePath(suggestedName + QStringLiteral(".csv")), QStringLiteral("CSV (*.csv)"));
    if (path.isEmpty())
        return;
    QString error;
    if (!TableExporter::exportCsv(model, path, &error))
        showError(parent, error);
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void UiHelpers::exportPdf(QWidget* parent, const QAbstractItemModel& model, const QString& title,
                          const QString& preparedBy) {
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString path = QFileDialog::getSaveFileName(parent, UiText::tr("Export PDF report"),
                                                      QDir(folder).filePath(title + QStringLiteral(".pdf")),
                                                      QStringLiteral("PDF (*.pdf)"));
    if (path.isEmpty())
        return;
    QString error;
    if (!TableExporter::exportPdf(model, title, preparedBy, path, &error))
        showError(parent, error);
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

QComboBox* UiHelpers::languageSelector(Language current, QWidget* parent) {
    auto* combo = new QComboBox(parent);
    combo->setObjectName(QStringLiteral("languageCombo"));
    combo->setToolTip(UiText::tr("Language"));
    const QIcon globe = Icons::get(QStringLiteral("globe"), QLatin1String(Theme::kIcon), 16);
    for (Language language : supportedLanguages())
        combo->addItem(globe, Labels::language(language), languageCode(language));
    combo->setCurrentIndex(combo->findData(languageCode(current)));
    return combo;
}
