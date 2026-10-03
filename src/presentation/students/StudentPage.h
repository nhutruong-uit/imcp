#pragma once

#include "domain/entities/Branch.h"
#include "domain/entities/Student.h"
#include "presentation/main/AppServices.h"

#include <QWidget>

class StudentTableModel;
class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QSortFilterProxyModel;
class QTableView;
class QTimer;

// Reference module - new modules follow the same structure:
//   Page (UI) -> Service (use case) -> repository interface -> Sql...Repository -> SQL procedure
// The Add/Edit/Delete buttons are only shown to roles that may edit students (Permissions::canEditStudents);
// hiding them is a convenience - SQL Server refuses usp_Student_Add/Update/Delete to the other roles anyway.
class StudentPage : public QWidget {
    Q_OBJECT
public:
    explicit StudentPage(AppServices services, QWidget* parent = nullptr);

private slots:
    void search();
    void add();
    void edit();
    void remove();

private:
    const Student* selectedStudent() const;
    void selectById(const QString& id);

    AppServices m_services;
    QList<Branch> m_branches;
    bool m_canEdit = false;
    QLineEdit* m_keyword = nullptr;
    QComboBox* m_branchFilter = nullptr;
    QComboBox* m_statusFilter = nullptr;
    QPushButton* m_editButton = nullptr;
    QPushButton* m_deleteButton = nullptr;
    QTableView* m_table = nullptr;
    StudentTableModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QLabel* m_count = nullptr;
    QTimer* m_searchDelay = nullptr;
};
