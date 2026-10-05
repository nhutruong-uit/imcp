#include "presentation/students/StudentTableModel.h"

#include "presentation/common/Columns.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/Theme.h"

#include <QColor>
#include <iterator>

namespace {
// Column keys in the order of StudentTableModel::Column (same names as view vw_StudentOverview)
const char* const kColumnKeys[] = {"StudentId",    "FullName",     "DateOfBirth",      "Gender",
                                   "Phone",        "GuardianName", "GuardianPhone",    "BranchName",
                                   "RegisteredOn", "Status",       "ActiveClassCount", "TotalBalance"};
static_assert(std::size(kColumnKeys) == StudentTableModel::ColumnCount, "one key per column");
} // namespace

StudentTableModel::StudentTableModel(QObject* parent) : QAbstractTableModel(parent) {}

void StudentTableModel::setStudents(QList<Student> students) {
    beginResetModel();
    m_students = std::move(students);
    endResetModel();
}

const Student* StudentTableModel::studentAt(int row) const {
    return (row >= 0 && row < m_students.size()) ? &m_students.at(row) : nullptr;
}

int StudentTableModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_students.size());
}

int StudentTableModel::columnCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : ColumnCount;
}

QVariant StudentTableModel::data(const QModelIndex& index, int role) const {
    const Student* s = studentAt(index.row());
    if (!s)
        return {};

    if (role == Qt::DisplayRole || role == Qt::UserRole) {
        const bool raw = role == Qt::UserRole; // raw value used for sorting
        switch (index.column()) {
        case Id:
            return s->id;
        case FullName:
            return s->fullName;
        case DateOfBirth:
            return raw ? QVariant(s->dateOfBirth) : QVariant(Format::date(s->dateOfBirth));
        case Gender:
            return raw ? s->gender : DbValues::label(s->gender);
        case Phone:
            return s->phone;
        case Guardian:
            return s->guardianName;
        case GuardianPhone:
            return s->guardianPhone;
        case Branch:
            return s->branchName;
        case RegisteredOn:
            return raw ? QVariant(s->registeredOn) : QVariant(Format::date(s->registeredOn));
        case Status:
            return raw ? s->status : DbValues::label(s->status);
        case ActiveClasses:
            return s->activeClassCount;
        case Balance:
            return raw ? QVariant(s->outstandingBalance)
                       : QVariant(s->outstandingBalance > 0 ? Format::money(s->outstandingBalance)
                                                            : QString());
        default:
            return {};
        }
    }
    if (role == Qt::TextAlignmentRole && (index.column() == ActiveClasses || index.column() == Balance))
        return QVariant::fromValue(Qt::AlignRight | Qt::AlignVCenter);
    if (role == Qt::ForegroundRole) {
        // The same rules as every other list (TableDataModel): money still owed by its column key, a stored
        // value by its tone in DbValues - so a status has one colour on every screen
        const QString key = QString::fromLatin1(kColumnKeys[index.column()]);
        if (Columns::isDebt(key))
            return s->outstandingBalance > 0 ? QVariant(QColor(Theme::kNegativeText)) : QVariant();
        if (index.column() == Status) {
            switch (DbValues::tone(s->status)) {
            case DbValues::Tone::Positive:
                return QColor(Theme::kPositiveText);
            case DbValues::Tone::Negative:
                return QColor(Theme::kNegativeText);
            case DbValues::Tone::Neutral:
                break;
            }
        }
    }
    return {};
}

QVariant StudentTableModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (orientation == Qt::Horizontal && section >= 0 && section < ColumnCount) {
        const QString key = QString::fromLatin1(kColumnKeys[section]);
        if (role == Qt::DisplayRole)
            return Columns::title(key);
        if (role == Columns::KeyRole)
            return key;
    }
    return QAbstractTableModel::headerData(section, orientation, role);
}
