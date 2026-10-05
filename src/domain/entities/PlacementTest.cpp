#include "domain/entities/PlacementTest.h"

#include <cmath>

double PlacementTest::overall() const {
    // The computed column OverallScore averages exact decimals and rounds half up to 2 decimals. In
    // hundredths the sum is an exact integer, so (sum + 2) / 4 rounds the same way; a double average
    // of 9.30/9/9/9 is 9.0749999... and would round to 9.07 instead of 9.08.
    const qint64 sum = std::llround(listening * 100) + std::llround(speaking * 100) +
                       std::llround(reading * 100) + std::llround(writing * 100);
    return static_cast<double>((sum + 2) / 4) / 100.0;
}

QStringList PlacementTest::validate(const QDate& today) const {
    QStringList errors;
    if (studentId.isEmpty())
        errors << tr("Please choose a student.");
    for (double score : {listening, speaking, reading, writing}) {
        if (score < 0 || score > 10) {
            errors << tr("Scores must be between 0 and 10.");
            break;
        }
    }
    if (testDate.isValid() && testDate > today)
        errors << tr("The test date cannot be in the future.");
    if (notes.size() > PlacementLimits::notes)
        errors << tr("Notes must be at most %1 characters.").arg(PlacementLimits::notes);
    return errors;
}
