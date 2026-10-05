#pragma once

#include "domain/entities/GradeBook.h"

#include <QAbstractTableModel>
#include <QHash>
#include <QPair>

// The grade book as an editable table: one row per student, the columns Student ID, Full name, one column per
// grade component ("Homework (20%)") and the final grade computed like dbo.fn_FinalGrade. A changed score is
// kept as a pending change (shown in bold) until changes() is saved. Column keys for Columns / the tests:
// StudentId, StudentName, Score (every component column) and FinalGrade.
class GradeBookModel : public QAbstractTableModel {
    Q_OBJECT
public:
    explicit GradeBookModel(QObject* parent = nullptr);

    void setBook(GradeBook book, bool editable);
    const GradeBook& book() const { return m_book; }
    QList<GradeEntry> changes() const; // the scores typed since setBook
    bool hasChanges() const { return !m_changes.isEmpty(); }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    int columnCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex& index, const QVariant& value, int role = Qt::EditRole) override;
    Qt::ItemFlags flags(const QModelIndex& index) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const override;

signals:
    void changed();

private:
    enum FixedColumn { StudentIdColumn, StudentNameColumn, FirstComponentColumn };
    int componentAt(int column) const; // ComponentId of a component column, 0 otherwise
    std::optional<double> score(int row, int componentId) const; // the pending change, else the stored score
    std::optional<double> finalGrade(int row) const;

    GradeBook m_book;
    bool m_editable = false;
    QHash<QPair<int, int>, double> m_changes; // (row, ComponentId) -> new score
};
