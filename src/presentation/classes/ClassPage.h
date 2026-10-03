#pragma once

#include "domain/entities/Catalog.h"
#include "presentation/common/DataPage.h"

class QComboBox;

// Classes page: the list of classes (vw_ClassDetails, filtered by branch and status) and the whole life of a
// class - open it, change it, set its weekly schedule, generate its sessions, start or cancel it, see its
// students and close it with the results (usp_Class_EvaluateResults, a cursor). Academic staff and the
// manager change classes; the buttons that change data are not created for other roles
// (Permissions::canEdit).
class ClassPage : public DataPage {
    Q_OBJECT
public:
    explicit ClassPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    QString selectedClassId() const;
    QString selectedClassName() const;
    void addClass();
    void editClass();
    void editSchedule();
    void generateSessions(const QString& classId, bool askFirst);
    void startClass();
    void cancelClass();
    void showStudents();
    void evaluateResults();
    void showResults();

    QList<Branch> m_branches;
    QComboBox* m_branchFilter = nullptr;
    QComboBox* m_statusFilter = nullptr;
};
