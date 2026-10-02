#pragma once

#include "domain/entities/Student.h"

#include <QAbstractTableModel>

// Student list table. Headers come from the shared column catalog (Columns), so the same column key
// (e.g. "TongConNo") gets the same title, money format and PDF total as in the other lists.
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
    void setStudents(QList<Student> students);
    const Student* studentAt(int row) const;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    int columnCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const override;

private:
    QList<Student> m_students;
};
