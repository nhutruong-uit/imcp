#include "presentation/grades/GradeBookModel.h"

#include "presentation/common/Columns.h"
#include "presentation/common/Theme.h"

#include <QColor>
#include <QFont>
#include <QLocale>

GradeBookModel::GradeBookModel(QObject* parent) : QAbstractTableModel(parent) {}

void GradeBookModel::setBook(GradeBook book, bool editable) {
    beginResetModel();
    m_book = std::move(book);
    m_editable = editable;
    m_changes.clear();
    endResetModel();
    emit changed();
}

QList<GradeEntry> GradeBookModel::changes() const {
    QList<GradeEntry> entries;
    for (auto it = m_changes.cbegin(); it != m_changes.cend(); ++it)
        entries.append({m_book.rows.at(it.key().first).enrollmentId, it.key().second, it.value()});
    return entries;
}

int GradeBookModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : int(m_book.rows.size());
}

int GradeBookModel::columnCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : FirstComponentColumn + int(m_book.components.size()) + 1; // + final grade
}

int GradeBookModel::componentAt(int column) const {
    const int i = column - FirstComponentColumn;
    return (i >= 0 && i < m_book.components.size()) ? m_book.components.at(i).id : 0;
}

std::optional<double> GradeBookModel::score(int row, int componentId) const {
    const auto change = m_changes.constFind({row, componentId});
    if (change != m_changes.cend())
        return *change;
    return m_book.rows.at(row).scores.value(componentId);
}

std::optional<double> GradeBookModel::finalGrade(int row) const {
    GradeBook preview = m_book; // the grade with the pending changes, before they are saved
    for (const GradeComponentInfo& c : m_book.components)
        preview.rows[row].scores[c.id] = score(row, c.id);
    return preview.finalGrade(row);
}

QVariant GradeBookModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_book.rows.size())
        return {};
    const GradeBookRow& r = m_book.rows.at(index.row());
    const int column = index.column();
    const int componentId = componentAt(column);
    const bool isFinal = column == columnCount() - 1;

    if (role == Qt::DisplayRole || role == Qt::EditRole || role == Qt::UserRole) {
        if (column == StudentIdColumn)
            return r.studentId;
        if (column == StudentNameColumn)
            return r.studentName;
        const std::optional<double> value =
            isFinal ? finalGrade(index.row()) : score(index.row(), componentId);
        if (!value)
            return role == Qt::DisplayRole ? QVariant(QString()) : QVariant();
        if (role == Qt::DisplayRole)
            return QLocale().toString(*value, 'f', 2);
        return *value;
    }
    if (role == Qt::TextAlignmentRole && column >= FirstComponentColumn)
        return QVariant::fromValue(Qt::AlignRight | Qt::AlignVCenter);
    if (role == Qt::FontRole && componentId > 0 && m_changes.contains({index.row(), componentId})) {
        QFont bold;
        bold.setBold(true);
        return bold;
    }
    // Red below the pass mark only: at the pass mark or above the result also depends on the attendance,
    // which the grade book does not show (usp_Class_EvaluateResults decides Passed / Failed)
    if (role == Qt::ForegroundRole && isFinal) {
        const std::optional<double> grade = finalGrade(index.row());
        if (grade && *grade < GradeLimits::passMark)
            return QColor(Theme::kNegativeText);
    }
    return {};
}

bool GradeBookModel::setData(const QModelIndex& index, const QVariant& value, int role) {
    const int componentId = componentAt(index.column());
    if (role != Qt::EditRole || componentId == 0 || !m_editable)
        return false;
    // Accepts 7.5 and 7,5 (the decimal separator of the UI language)
    QString text = value.toString().trimmed();
    bool ok = false;
    double v = QLocale().toDouble(text, &ok);
    if (!ok)
        v = text.replace(QLatin1Char(','), QLatin1Char('.')).toDouble(&ok);
    if (!ok || v < GradeLimits::minScore || v > GradeLimits::maxScore)
        return false;
    m_changes.insert({index.row(), componentId}, v);
    emit dataChanged(index, this->index(index.row(), columnCount() - 1));
    emit changed();
    return true;
}

Qt::ItemFlags GradeBookModel::flags(const QModelIndex& index) const {
    Qt::ItemFlags f = QAbstractTableModel::flags(index);
    if (m_editable && componentAt(index.column()) > 0)
        f |= Qt::ItemIsEditable;
    return f;
}

QVariant GradeBookModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (orientation != Qt::Horizontal)
        return QAbstractTableModel::headerData(section, orientation, role);
    const int componentIndex = section - FirstComponentColumn;
    const bool isFinal = section == columnCount() - 1;
    QString key;
    if (section == StudentIdColumn)
        key = QStringLiteral("StudentId");
    else if (section == StudentNameColumn)
        key = QStringLiteral("StudentName");
    else if (isFinal)
        key = QStringLiteral("FinalGrade");
    else
        key = QStringLiteral("Score");
    if (role == Columns::KeyRole)
        return key;
    if (role == Qt::DisplayRole) {
        if (key != QStringLiteral("Score"))
            return Columns::title(key);
        const GradeComponentInfo& c = m_book.components.at(componentIndex);
        return QStringLiteral("%1 (%2%)").arg(c.name, QLocale().toString(c.weight)); // 20, 33.33
    }
    return {};
}
