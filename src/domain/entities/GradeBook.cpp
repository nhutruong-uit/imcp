#include "domain/entities/GradeBook.h"

#include <cmath>

GradeBook GradeBook::fromCells(const QList<GradeCell>& cells) {
    GradeBook book;
    QHash<int, int> componentIndex; // ComponentId -> position in components
    QHash<QString, int> rowIndex;   // EnrollmentId -> position in rows
    for (const GradeCell& cell : cells) {
        if (!componentIndex.contains(cell.componentId)) {
            componentIndex.insert(cell.componentId, int(book.components.size()));
            book.components.append({cell.componentId, cell.componentName, cell.weight});
        }
        if (!rowIndex.contains(cell.enrollmentId)) {
            rowIndex.insert(cell.enrollmentId, int(book.rows.size()));
            book.rows.append({cell.enrollmentId, cell.studentId, cell.studentName, {}});
        }
        book.rows[rowIndex.value(cell.enrollmentId)].scores.insert(cell.componentId, cell.score);
    }
    return book;
}

std::optional<double> GradeBook::finalGrade(int row) const {
    if (row < 0 || row >= rows.size() || components.isEmpty())
        return std::nullopt;
    double total = 0;
    for (const GradeComponentInfo& c : components) {
        const std::optional<double> score = rows.at(row).scores.value(c.id);
        if (!score)
            return std::nullopt;
        total += *score * c.weight;
    }
    // total / 100 is the grade, so round(total) / 100 keeps 2 decimals; the small epsilon compensates for
    // binary fractions (7.3 x 50 = 364.99999...), so a decimal .5 still rounds up like ROUND() on DECIMAL in
    // SQL Server
    return std::round(total + 1e-7) / 100.0;
}

double GradeBook::totalWeight() const {
    double total = 0;
    for (const GradeComponentInfo& c : components)
        total += c.weight;
    return total;
}

bool GradeBook::weightsComplete() const {
    return std::abs(totalWeight() - 100) <= 0.001;
}
