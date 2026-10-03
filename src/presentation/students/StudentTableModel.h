#pragma once

#include "domain/entities/Student.h"

#include <QAbstractTableModel>

// Student list table. Headers come from the shared column catalog (Columns), so the same column key
// (e.g. "TotalBalance") gets the same title, money format and PDF total as in the other lists.
// A Qt "model" answers the questions of the table view cell by cell: rowCount, columnCount, data(index,
// role), headerData. See TableDataModel.h for the meaning of the roles.
class StudentTableModel : public QAbstractTableModel {
    Q_OBJECT
public:
    enum Column {
        Id,
        FullName,
        DateOfBirth,
        Gender,
        Phone,
        Guardian,
        GuardianPhone,
        Branch,
        RegisteredOn,
        Status,
        ActiveClasses,
        Balance,
        ColumnCount
    };

    explicit StudentTableModel(QObject* parent = nullptr);
    void setStudents(QList<Student> students); // replaces the rows (the view redraws itself)
    const Student* studentAt(int row) const;   // nullptr when the row does not exist

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    int columnCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const override;

private:
    QList<Student> m_students;
};
