#include "domain/entities/PlacementTest.h"

#include <cmath>

double PlacementTest::overall() const {
    return std::round((listening + speaking + reading + writing) / 4.0 * 100.0) / 100.0;
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
