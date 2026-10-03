#pragma once

#include "presentation/common/DataPage.h"

#include <QDate>

class QLabel;

// Timetable page, one week at a time: the sessions of every class (academic staff, manager:
// vw_SessionDetails) or of the signed-in teacher (vw_Teacher_MySchedule). A session is marked taught or
// cancelled with the content of the lesson (usp_Session_Update) and its attendance is taken
// (usp_Attendance_*). Taught sessions are what the payroll pays (usp_Payroll_Finalize); a session is marked
// taught only on or after its date (trg_CLASS_SESSION_LockTaught).
class TimetablePage : public DataPage {
    Q_OBJECT
public:
    // feature: WeeklySchedule (every class) or MyTeachingSchedule (the teacher's own sessions)
    TimetablePage(AppServices services, Feature feature, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    bool mineOnly() const { return m_feature == Feature::MyTeachingSchedule; }
    void moveWeek(int weeks);
    QString sessionTitle() const;
    void updateSession();
    void takeAttendance();

    QDate m_week; // Monday of the week shown
    QLabel* m_weekLabel = nullptr;
};
