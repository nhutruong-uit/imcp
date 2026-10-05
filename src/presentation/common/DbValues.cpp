#include "presentation/common/DbValues.h"

#include <QCoreApplication>
#include <QHash>

namespace {
using Tone = DbValues::Tone;

// Stored value (part of the database schema, also the English display text) and its highlight tone.
// QT_TRANSLATE_NOOP marks the value for lupdate; label() translates it on use.
struct Entry {
    const char* stored;
    Tone tone;
};

const Entry kEntries[] = {
    // Common statuses
    {QT_TRANSLATE_NOOP("DbValues", "Active"), Tone::Positive},
    {QT_TRANSLATE_NOOP("DbValues", "Suspended"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Locked"), Tone::Negative},
    {QT_TRANSLATE_NOOP("DbValues", "Left"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Cancelled"), Tone::Negative},
    // Rooms
    {QT_TRANSLATE_NOOP("DbValues", "Lecture"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Lab"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Multi-purpose"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Available"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Maintenance"), Tone::Neutral},
    // People: gender, position, degree, teacher type, employment status
    {QT_TRANSLATE_NOOP("DbValues", "Male"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Female"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Other"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Manager"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Academic staff"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Accountant"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Consultant"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Bachelor"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Master"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "PhD"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Vietnamese"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Native"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Working"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Teaching"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "On leave"), Tone::Neutral},
    // Students, courses, classes, sessions, enrollments
    {QT_TRANSLATE_NOOP("DbValues", "Prospective"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Studying"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "On hold"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Dropped out"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Open"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Discontinued"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Enrolling"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "In progress"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Finished"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Scheduled"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Taught"), Tone::Positive},
    {QT_TRANSLATE_NOOP("DbValues", "Completed"), Tone::Neutral},
    // Learning results, classification (fn_Classification), attendance
    {QT_TRANSLATE_NOOP("DbValues", "Passed"), Tone::Positive},
    {QT_TRANSLATE_NOOP("DbValues", "Failed"), Tone::Negative},
    {QT_TRANSLATE_NOOP("DbValues", "Excellent"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Very good"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Good"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Average"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Present"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Late"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Excused absence"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Unexcused absence"), Tone::Neutral},
    // Finance: receipts, payroll
    {QT_TRANSLATE_NOOP("DbValues", "Cash"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Bank transfer"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Card"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Valid"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Finalized"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Paid"), Tone::Positive},
    // The description usp_Receipt_Create stores when the cashier types none
    // (ReceiptValues::defaultDescription)
    {QT_TRANSLATE_NOOP("DbValues", "Tuition payment"), Tone::Neutral},
    // Promotions: discount type codes (PROMOTION.DiscountType) and the validity computed by the Promotions
    // list
    {QT_TRANSLATE_NOOP("DbValues", "PERCENT"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "AMOUNT"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Upcoming"), Tone::Neutral},
    {QT_TRANSLATE_NOOP("DbValues", "Expired"), Tone::Negative},
};

const Entry* find(const QString& storedValue) {
    static const QHash<QString, const Entry*> index = [] {
        QHash<QString, const Entry*> h;
        for (const Entry& e : kEntries)
            h.insert(QString::fromUtf8(e.stored), &e);
        return h;
    }();
    return index.value(storedValue, nullptr);
}
} // namespace

QString DbValues::label(const QString& storedValue) {
    const Entry* e = find(storedValue);
    return e ? QCoreApplication::translate("DbValues", e->stored) : storedValue;
}

DbValues::Tone DbValues::tone(const QString& storedValue) {
    const Entry* e = find(storedValue);
    return e ? e->tone : Tone::Neutral;
}

QStringList DbValues::all() {
    QStringList values;
    for (const Entry& e : kEntries)
        values << QString::fromUtf8(e.stored);
    return values;
}
