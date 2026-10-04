#pragma once

#include "application/services/Permissions.h"
#include "domain/entities/ClassInfo.h"
#include "presentation/main/AppServices.h"

#include <QWidget>

class GradeBookModel;
class QComboBox;
class QLabel;
class QPushButton;
class QTableView;

// Grade book page: choose a class, type the scores (students x grade components), save the changed scores
// together (usp_Grade_Save per score, in one transaction; trg_GRADE_Audit logs each change). Academic staff
// and the manager see every class (usp_Grade_ByClass); a teacher sees only their own classes
// (vw_Teacher_MyGrades) and the database refuses a class they do not teach (50041). The grades of a finished
// class are final (50042), so its grade book is read-only here too.
class GradeBookPage : public QWidget {
    Q_OBJECT
public:
    // feature: Grades (every class) or MyGrades (the teacher's classes)
    GradeBookPage(AppServices services, Feature feature, QWidget* parent = nullptr);

public slots:
    void reload();

private:
    bool mineOnly() const { return m_feature == Feature::MyGrades; }
    void save();
    void updateFooter();
    QString classTitle() const;

    AppServices m_services;
    const Feature m_feature;
    QList<ClassOption> m_classes;
    QComboBox* m_class = nullptr;
    QLabel* m_info = nullptr;
    QTableView* m_table = nullptr;
    GradeBookModel* m_model = nullptr;
    QPushButton* m_saveButton = nullptr;
    QLabel* m_footer = nullptr;
};
