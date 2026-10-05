#pragma once

#include <QString>
#include <QStringList>
#include <Qt>

// Column catalog of the lookup tables. Every column has a stable KEY = its column name in the database
// view/procedure (e.g. "Balance", "Status"); the catalog gives the header in the current UI language and the
// formatting rules. The SQL in the infrastructure layer therefore holds no display text, and money/total
// detection never depends on the header text (switching language cannot break it).
namespace Columns {
// Data role of a horizontal header (headerData): returns the column key instead of the translated title
inline constexpr int KeyRole = Qt::UserRole;

bool contains(const QString& key);
QString title(const QString& key);      // unknown key => the key itself
bool isMoney(const QString& key);       // shown as money: 6.500.000 ₫
bool isSummable(const QString& key);    // summed in the totals line (screen) and the GRAND TOTAL row (PDF)
QString totalLabel(const QString& key); // label of the totals line, e.g. "Total outstanding"
bool isEnumerated(const QString& key);  // CHECK ... IN (...) values => shown through DbValues::label
bool isDebt(const QString& key);        // money still owed: highlighted when > 0
bool isRoleCode(const QString& key);    // account role code (MANAGER...) => shown through Labels::role
bool isSchedule(const QString& key);    // weekly schedule => day names localized by Format::schedule
bool isWeekday(const QString& key);     // ISO weekday number 1-7 => day name (Format::weekday)
bool isYesNo(const QString& key);       // 1 / 0 flag => "Yes" / empty
QStringList keys();                     // used by the tests
} // namespace Columns
