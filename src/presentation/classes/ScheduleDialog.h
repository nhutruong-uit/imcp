#pragma once

#include <QDialog>

class ClassService;
class DataTable;
class QComboBox;
class QLabel;
class QTimeEdit;

// The weekly timetable of one class: the slots it has (usp_ClassSchedule_ByClass), add or change the slot of
// a weekday (usp_ClassSchedule_Add, whose trigger refuses a room or teacher clash) and remove one
// (usp_ClassSchedule_Remove). Every change is saved at once; changed() tells the page to refresh.
class ScheduleDialog : public QDialog {
    Q_OBJECT
public:
    ScheduleDialog(ClassService& service, const QString& classId, const QString& className, bool canEdit,
                   QWidget* parent = nullptr);
    bool changed() const { return m_changed; }

private:
    void reload();
    void saveSlot();
    void removeSlot();
    void showError(const QString& message);

    ClassService& m_service;
    QString m_classId;
    bool m_changed = false;
    DataTable* m_table = nullptr;
    QComboBox* m_weekday = nullptr;
    QTimeEdit* m_start = nullptr;
    QTimeEdit* m_end = nullptr;
    QLabel* m_error = nullptr;
};
