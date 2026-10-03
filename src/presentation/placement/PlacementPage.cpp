#include "presentation/placement/PlacementPage.h"

#include "presentation/placement/PlacementTestDialog.h"

#include <QLocale>
#include <QMessageBox>

PlacementPage::PlacementPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::PlacementTests, parent) {
    if (canEdit())
        addAction(tr("New test"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { addTest(); });
    reload();
}

Result<TableData> PlacementPage::fetch() {
    return m_services.placement.search(QString());
}

void PlacementPage::addTest() {
    PlacementTestDialog dialog(m_services.placement, m_services.students, QString(), this);
    if (dialog.exec() != QDialog::Accepted)
        return;
    const PlacementResult r = dialog.result();
    reloadAndSelect(QStringLiteral("TestId"), r.testId);
    const QString overall = QLocale().toString(r.overallScore, 'f', 2);
    QMessageBox::information(
        this, tr("Placement test saved"),
        r.recommendedCourse.isEmpty()
            ? tr("Test %1: overall score %2. No open course matches this score.").arg(r.testId, overall)
            : tr("Test %1: overall score %2. Recommended course: %3.")
                  .arg(r.testId, overall, r.recommendedCourse));
}
