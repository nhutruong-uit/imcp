#pragma once

#include "domain/entities/Catalog.h"
#include "domain/entities/ClassInfo.h"
#include "presentation/common/FormDialog.h"

class ClassService;
class QComboBox;
class QDateEdit;
class QDoubleSpinBox;
class QLineEdit;
class QSpinBox;

// New class / edit class form. A new class takes the tuition of its course by default (usp_Class_Create does
// the same when no price is given); the branch of an existing class cannot change (usp_Class_Update keeps it,
// the revenue of its receipts belongs to that branch). The room list follows the branch. Save:
// ClassService::add / update (ClassInfo::validate first, then usp_Class_Create / usp_Class_Update).
class ClassFormDialog : public FormDialog {
    Q_OBJECT
public:
    ClassFormDialog(ClassService& service, const QList<Branch>& branches, const ClassInfo& c,
                    QWidget* parent = nullptr);
    QString savedClassId() const { return m_savedId; }
    bool startDateChanged() const { return m_startDateChanged; }

protected:
    bool save() override;

private:
    void loadRooms();
    void courseChanged();

    ClassService& m_service;
    ClassInfo m_original;
    QString m_savedId;
    bool m_startDateChanged = false;
    QLineEdit* m_name = nullptr;
    QComboBox* m_course = nullptr;
    QComboBox* m_branch = nullptr;
    QComboBox* m_teacher = nullptr;
    QComboBox* m_room = nullptr;
    QDateEdit* m_startDate = nullptr;
    QSpinBox* m_maxStudents = nullptr;
    QDoubleSpinBox* m_tuition = nullptr;
};
