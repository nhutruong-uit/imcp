#include "presentation/common/Fields.h"

#include "presentation/common/DbValues.h"

#include <QComboBox>
#include <QDateEdit>
#include <QDoubleSpinBox>
#include <QLineEdit>
#include <QRegularExpressionValidator>
#include <QSpinBox>
#include <QTimeEdit>
#include <cmath>

QLineEdit* Fields::text(QWidget* parent, int maxLength, const QString& value) {
    auto* edit = new QLineEdit(value, parent);
    edit->setMaxLength(maxLength);
    return edit;
}

QLineEdit* Fields::digits(QWidget* parent, int maxDigits, const QString& value) {
    auto* edit = new QLineEdit(value, parent);
    edit->setValidator(new QRegularExpressionValidator(
        QRegularExpression(QStringLiteral("[0-9]{0,%1}").arg(maxDigits)), edit));
    return edit;
}

QLineEdit* Fields::code(QWidget* parent, const QString& value) {
    auto* edit = new QLineEdit(value, parent);
    edit->setValidator(
        new QRegularExpressionValidator(QRegularExpression(QStringLiteral("[A-Za-z0-9_-]{0,10}")), edit));
    return edit;
}

QDateEdit* Fields::date(QWidget* parent, const QDate& value) {
    auto* edit = new QDateEdit(value.isValid() ? value : QDate::currentDate(), parent);
    edit->setDisplayFormat(QStringLiteral("dd/MM/yyyy"));
    edit->setCalendarPopup(true);
    return edit;
}

QTimeEdit* Fields::time(QWidget* parent, const QTime& value) {
    auto* edit = new QTimeEdit(value, parent);
    edit->setDisplayFormat(QStringLiteral("HH:mm"));
    return edit;
}

QSpinBox* Fields::integer(QWidget* parent, int minimum, int maximum, int value) {
    auto* spin = new QSpinBox(parent);
    spin->setRange(minimum, maximum);
    spin->setValue(value);
    return spin;
}

QDoubleSpinBox* Fields::decimal(QWidget* parent, double minimum, double maximum, int decimals, double value) {
    auto* spin = new QDoubleSpinBox(parent);
    spin->setDecimals(decimals);
    spin->setRange(minimum, maximum);
    spin->setValue(value);
    return spin;
}

QDoubleSpinBox* Fields::money(QWidget* parent, qint64 value, qint64 maximum) {
    // A double spin box holds amounts above the int range of QSpinBox; 0 decimals = whole dong
    auto* spin = new QDoubleSpinBox(parent);
    spin->setDecimals(0);
    spin->setRange(0, double(maximum));
    spin->setSingleStep(100000);
    spin->setGroupSeparatorShown(true);
    spin->setSuffix(QStringLiteral(" ₫"));
    spin->setValue(double(value));
    return spin;
}

qint64 Fields::moneyValue(const QDoubleSpinBox* field) {
    return static_cast<qint64>(std::llround(field->value()));
}

QComboBox* Fields::values(QWidget* parent, const QStringList& stored, const QString& current) {
    auto* combo = new QComboBox(parent);
    for (const QString& v : stored)
        combo->addItem(DbValues::label(v), v);
    if (!current.isEmpty())
        select(combo, current, DbValues::label(current));
    return combo;
}

QComboBox* Fields::lookup(QWidget* parent, const QList<LookupItem>& items, const QString& current,
                          const QString& emptyText) {
    auto* combo = new QComboBox(parent);
    fillLookup(combo, items, emptyText);
    if (!current.isEmpty())
        select(combo, current, current);
    return combo;
}

void Fields::fillLookup(QComboBox* combo, const QList<LookupItem>& items, const QString& emptyText) {
    combo->clear();
    if (!emptyText.isEmpty())
        combo->addItem(emptyText, QString());
    // A stored value next to the name (LookupItem::detail) is shown with its label in the UI language
    for (const LookupItem& item : items)
        combo->addItem(item.detail.isEmpty()
                           ? item.name
                           : QStringLiteral("%1 (%2)").arg(item.name, DbValues::label(item.detail)),
                       item.id);
}

void Fields::select(QComboBox* combo, const QString& key, const QString& missingText) {
    int index = combo->findData(key);
    if (index < 0 && !key.isEmpty()) {
        combo->addItem(missingText.isEmpty() ? key : missingText, key);
        index = combo->count() - 1;
    }
    combo->setCurrentIndex(qMax(0, index));
}

QString Fields::value(const QComboBox* combo) {
    return combo->currentData().toString();
}
