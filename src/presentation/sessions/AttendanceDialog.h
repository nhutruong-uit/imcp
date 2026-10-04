#pragma once

#include "domain/entities/Session.h"

#include <QDialog>

class SessionService;
class QLabel;
class QTableWidget;

// Attendance of one session: every student of the class (usp_Attendance_BySession; a student without a saved
// mark shows Present), one status and a note per student, saved together in one transaction
// (usp_Attendance_Save per student). A teacher only reaches the sessions they teach (50040); a finished class
// is closed (50046).
class AttendanceDialog : public QDialog {
    Q_OBJECT
public:
    AttendanceDialog(SessionService& service, int sessionId, const QString& title, bool canEdit,
                     QWidget* parent = nullptr);
    bool saved() const { return m_saved; }

private:
    void load();
    void save();
    void setAll(const QString& status);

    SessionService& m_service;
    int m_sessionId = 0;
    bool m_saved = false;
    QList<AttendanceMark> m_marks;
    QTableWidget* m_table = nullptr;
    QLabel* m_error = nullptr;
};
