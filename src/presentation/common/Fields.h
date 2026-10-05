#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/entities/Catalog.h"

#include <QDate>
#include <QList>
#include <QString>
#include <QStringList>
#include <QTime>

class QComboBox;
class QDateEdit;
class QDoubleSpinBox;
class QLineEdit;
class QSpinBox;
class QTimeEdit;
class QWidget;

// Field widgets configured the same way on every form: the limits of the database columns (length, digits
// only, code characters, ranges), dates as dd/MM/yyyy with a calendar, money in whole dong. A combo box
// always shows a text in the UI language and keeps the stored value / key as item data (Fields::value reads
// it back).
namespace Fields {
QLineEdit* text(QWidget* parent, int maxLength, const QString& value = QString());
QLineEdit* digits(QWidget* parent, int maxDigits, const QString& value = QString()); // phone numbers
QLineEdit* code(QWidget* parent, const QString& value = QString()); // BR01, IE-FND: letters, digits, - and _
QDateEdit* date(QWidget* parent, const QDate& value);
QTimeEdit* time(QWidget* parent, const QTime& value);
QSpinBox* integer(QWidget* parent, int minimum, int maximum, int value);
QDoubleSpinBox* decimal(QWidget* parent, double minimum, double maximum, int decimals, double value);
QDoubleSpinBox* money(QWidget* parent, qint64 value, qint64 maximum = 999999999999LL);
qint64 moneyValue(const QDoubleSpinBox* field);
// Stored database values (Male, Lecture, Cash...) shown through DbValues::label
QComboBox* values(QWidget* parent, const QStringList& stored, const QString& current = QString());
// Choices read from the database; emptyText adds a first choice with an empty key ("None", "All branches")
QComboBox* lookup(QWidget* parent, const QList<LookupItem>& items, const QString& current = QString(),
                  const QString& emptyText = QString());
void fillLookup(QComboBox* combo, const QList<LookupItem>& items, const QString& emptyText = QString());
// The branches of a branch combo box; a failed load gives no choice and its message in *error (the form shows
// it: an empty combo without a reason looks like a center without branches)
QList<LookupItem> branchItems(const Result<QList<Branch>>& branches, QString* error);
// Selects the item whose key is `key`; a key that is not in the list (e.g. an inactive branch of an old
// record) is added with missingText, so saving the form never changes it silently
void select(QComboBox* combo, const QString& key, const QString& missingText = QString());
QString value(const QComboBox* combo); // the key / stored value of the current item
} // namespace Fields
