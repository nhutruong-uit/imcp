#pragma once

#include "domain/entities/Catalog.h"
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
// Second row: the profile of the selected student (enrollments, placement tests), enroll them, record a
// placement test, and the XML export / import of usp_Student_ExportXml / _ImportXml.
class StudentPage : public QWidget {
    Q_OBJECT
public:
    explicit StudentPage(AppServices services, QWidget* parent = nullptr);

private slots:
    void search();
    void add();
    void edit();
    void remove();
    void showProfile();
    void enroll();
    void placementTest();
    void exportXml();
    void importXml();
    void updateButtons();

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
    QPushButton* m_profileButton = nullptr;
    QPushButton* m_enrollButton = nullptr; // only for the roles that may enroll
    QPushButton* m_testButton = nullptr;
    QTableView* m_table = nullptr;
    StudentTableModel* m_model = nullptr;
    QSortFilterProxyModel* m_proxy = nullptr;
    QLabel* m_count = nullptr;
    QTimer* m_searchDelay = nullptr;
};
