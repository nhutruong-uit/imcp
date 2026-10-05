#include "presentation/common/Format.h"

#include "presentation/common/Columns.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Labels.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QLocale>
#include <QRegularExpression>
#include <cmath>
#include <cstdlib>

namespace {
// Provides tr() with translation context "Format" for the free functions of namespace Format
struct FormatText {
    Q_DECLARE_TR_FUNCTIONS(Format)
};
} // namespace

QString Format::money(qint64 amount) {
    return QLocale().toString(amount) + QStringLiteral(" ₫");
}

QString Format::moneyShort(qint64 amount) {
    const QLocale locale;
    if (std::llabs(amount) >= 1000000000LL)
        return FormatText::tr("%1B").arg(locale.toString(amount / 1e9, 'f', 1));
    if (std::llabs(amount) >= 1000000LL)
        return FormatText::tr("%1M").arg(locale.toString(amount / 1e6, 'f', 1));
    return locale.toString(amount);
}

QString Format::date(const QDate& d) {
    return d.isValid() ? d.toString(QStringLiteral("dd/MM/yyyy")) : QString();
}

QString Format::dateTime(const QDateTime& utc, const QTimeZone& zone) {
    if (!utc.isValid())
        return QString();
    // ODBC returns a DATETIME without a time zone: rebuild it from its fields as UTC, then convert
    const QDateTime instant(utc.date(), utc.time(), QTimeZone::utc());
    return instant.toTimeZone(zone).toString(QStringLiteral("dd/MM/yyyy HH:mm"));
}

QString Format::month(int month) {
    const QLocale locale;
    // Vietnamese readers expect T1..T12 (the CLDR abbreviation "thg 1" is longer); other languages use the
    // locale's short month name
    if (locale.language() == QLocale::Vietnamese)
        return QStringLiteral("T%1").arg(month);
    return locale.standaloneMonthName(month, QLocale::ShortFormat);
}

QString Format::weekday(int isoDay) {
    const QLocale locale;
    // Vietnamese timetables use T2..T7 and CN (the CLDR abbreviations "Th 2"... are longer)
    if (locale.language() == QLocale::Vietnamese)
        return isoDay == 7 ? QStringLiteral("CN") : QStringLiteral("T%1").arg(isoDay + 1);
    return locale.dayName(isoDay, QLocale::ShortFormat);
}

QString Format::schedule(const QString& stored) {
    // The database writes the ISO day names in English (vw_ClassDetails.Schedule)
    static const QStringList days = {QStringLiteral("Mon"), QStringLiteral("Tue"), QStringLiteral("Wed"),
                                     QStringLiteral("Thu"), QStringLiteral("Fri"), QStringLiteral("Sat"),
                                     QStringLiteral("Sun")};
    static const QRegularExpression day(QStringLiteral("\\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\b"));
    QString result;
    qsizetype from = 0;
    for (auto it = day.globalMatch(stored); it.hasNext();) {
        const QRegularExpressionMatch m = it.next();
        result += stored.mid(from, m.capturedStart() - from);
        result += weekday(static_cast<int>(days.indexOf(m.captured(1))) + 1);
        from = m.capturedEnd();
    }
    return result + stored.mid(from);
}

QString Format::cell(const QVariant& value, const QString& columnKey) {
    if (value.isNull() || !value.isValid())
        return QString();
    // Number codes shown as words, whatever integer type the driver returns (TINYINT, INT...)
    if (Columns::isWeekday(columnKey))
        return weekday(value.toInt());
    if (Columns::isYesNo(columnKey))
        return value.toInt() == 1 ? FormatText::tr("Yes") : QString();
    switch (value.metaType().id()) {
    case QMetaType::QDate:
        return date(value.toDate());
    case QMetaType::QDateTime: // every DATETIME column is UTC (T32 in 12_tests.sql)
        return dateTime(value.toDateTime());
    case QMetaType::Double:
    case QMetaType::Float: {
        const double d = value.toDouble();
        if (Columns::isMoney(columnKey))
            return money(static_cast<qint64>(std::llround(d)));
        if (std::floor(d) == d)
            return QLocale().toString(static_cast<qint64>(d));
        return QLocale().toString(d, 'f', 2);
    }
    case QMetaType::Int:
    case QMetaType::LongLong:
    case QMetaType::UInt:
    case QMetaType::ULongLong:
        return Columns::isMoney(columnKey) ? money(value.toLongLong()) : value.toString();
    default:
        // Database enumerations (status, classification...) and codes are translated;
        // free text (names, notes) is kept
        if (Columns::isEnumerated(columnKey))
            return DbValues::label(value.toString());
        if (Columns::isRoleCode(columnKey))
            return Labels::role(roleFromCode(value.toString()));
        if (Columns::isSchedule(columnKey))
            return schedule(value.toString());
        return value.toString();
    }
}
