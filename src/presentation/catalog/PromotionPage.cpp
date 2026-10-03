#include "presentation/catalog/PromotionPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Labels.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLineEdit>

PromotionPage::PromotionPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Promotions, parent) {
    if (canEdit()) {
        addAction(tr("New promotion"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { editPromotion(true); });
        addAction(tr("Edit"), QStringLiteral("edit"), QStringLiteral("editButton"), true,
                  [this] { editPromotion(false); });
        connect(table(), &DataTable::activated, this, [this] { editPromotion(false); });
    }
    reload();
}

Result<TableData> PromotionPage::fetch() {
    return m_services.catalog.promotionList();
}

void PromotionPage::editPromotion(bool isNew) {
    Promotion p;
    p.startDate = QDate::currentDate();
    p.endDate = QDate::currentDate().addMonths(1);
    if (!isNew) {
        const auto current = m_services.catalog.promotion(selected(QStringLiteral("PromotionId")).toString());
        if (!current.ok()) {
            UiHelpers::showError(this, current.error());
            return;
        }
        p = current.value();
    }
    FormDialog dialog(isNew ? tr("New promotion") : tr("Edit promotion %1").arg(p.id), this);
    auto* code = Fields::code(&dialog, p.id);
    code->setEnabled(isNew);
    auto* name = Fields::text(&dialog, 100, p.name);
    auto* type = new QComboBox(&dialog);
    for (const QString& t : CatalogValues::discountTypes())
        type->addItem(Labels::discountType(t), t);
    Fields::select(type, p.discountType);
    auto* value = Fields::decimal(&dialog, 0, 999999999, 0, p.discountValue);
    value->setGroupSeparatorShown(true);
    auto* from = Fields::date(&dialog, p.startDate);
    auto* to = Fields::date(&dialog, p.endDate);
    dialog.form()->addRow(tr("Promotion code"), code);
    dialog.form()->addRow(tr("Promotion name"), name);
    dialog.form()->addRow(tr("Discount type"), type);
    dialog.form()->addRow(tr("Discount value"), value);
    dialog.form()->addRow(tr("Valid from"), from);
    dialog.form()->addRow(tr("Valid until"), to);
    QString savedId = p.id;
    dialog.setSaveAction([&] {
        Promotion c = p;
        c.id = code->text();
        c.name = name->text();
        c.discountType = Fields::value(type);
        c.discountValue = value->value();
        c.startDate = from->date();
        c.endDate = to->date();
        savedId = c.id.trimmed().toUpper();
        return m_services.catalog.savePromotion(c, isNew);
    });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("PromotionId"), savedId);
}
