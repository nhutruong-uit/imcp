#pragma once

#include <QDate>
#include <QString>
#include <QVariant>

// Display formatting in the current UI language (default QLocale set by I18n):
//   Vietnamese: 6.500.000 ₫, 12,5 tr, T1..T12, T2..CN      English: 6,500,000 ₫, 12.5M, Jan..Dec, Mon..Sun
// Dates are always dd/MM/yyyy (the center's data is Vietnamese).
namespace Format {
QString money(qint64 amount);
QString moneyShort(qint64 amount); // chart axis labels: 12,5 tr / 12.5M
QString date(const QDate& d);
QString month(int month);    // short month label on charts
QString weekday(int isoDay); // short day name, 1 = Monday ... 7 = Sunday
// Weekly schedule from the database ("Mon 18:00-20:00, Wed 18:00-20:00") with localized day names
QString schedule(const QString& stored);
// Formats one cell of a lookup table by column key (see Columns): money, dates, translated enumerations...
QString cell(const QVariant& value, const QString& columnKey);
} // namespace Format
