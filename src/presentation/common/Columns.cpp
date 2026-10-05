#include "presentation/common/Columns.h"

#include <QCoreApplication>
#include <QHash>

namespace {
// Flags that can be combined with | (e.g. Money | Summable | Debt): each one is one bit of the number
enum ColumnKind : unsigned {
    Text = 0,
    Money = 1u << 0,      // formatted as money
    Summable = 1u << 1,   // summed in the totals line
    Enumerated = 1u << 2, // database enumeration, displayed through DbValues::label
    Debt = 1u << 3,       // money still owed, highlighted when > 0
    RoleCode = 1u << 4,   // role code of an account (MANAGER...), displayed through Labels::role
    Schedule = 1u << 5,   // weekly schedule "Mon 18:00-20:00, ...", day names localized by Format::schedule
    Weekday = 1u << 6,    // ISO weekday number 1-7, shown as a day name (Format::weekday)
    YesNo = 1u << 7,      // 1 / 0 flag, shown as "Yes" / empty
};

struct Column {
    const char* key;
    const char* title; // English source text, translated in context "Columns"
    unsigned kind;
    const char* totalLabel; // summable columns only
};

// QT_TRANSLATE_NOOP only marks the text for lupdate; it is translated when displayed (see translated()).
// A new column in a view/procedure shown in the UI needs a row here (the end-to-end test fails otherwise).
const Column kCatalog[] = {
    // Classes and sessions
    {"ClassId", QT_TRANSLATE_NOOP("Columns", "Class code"), Text, nullptr},
    {"ClassName", QT_TRANSLATE_NOOP("Columns", "Class name"), Text, nullptr},
    {"CourseName", QT_TRANSLATE_NOOP("Columns", "Course"), Text, nullptr},
    {"BranchName", QT_TRANSLATE_NOOP("Columns", "Branch"), Text, nullptr},
    {"TeacherName", QT_TRANSLATE_NOOP("Columns", "Teacher"), Text, nullptr},
    {"RoomName", QT_TRANSLATE_NOOP("Columns", "Room"), Text, nullptr},
    {"Schedule", QT_TRANSLATE_NOOP("Columns", "Schedule"), Schedule, nullptr},
    {"StartDate", QT_TRANSLATE_NOOP("Columns", "Start date"), Text, nullptr},
    {"EndDate", QT_TRANSLATE_NOOP("Columns", "End date"), Text, nullptr},
    {"EnrolledCount", QT_TRANSLATE_NOOP("Columns", "Enrolled"), Text, nullptr},
    {"MaxStudents", QT_TRANSLATE_NOOP("Columns", "Capacity"), Text, nullptr},
    {"Tuition", QT_TRANSLATE_NOOP("Columns", "Tuition"), Money, nullptr},
    {"Status", QT_TRANSLATE_NOOP("Columns", "Status"), Enumerated, nullptr},
    {"SessionDate", QT_TRANSLATE_NOOP("Columns", "Date"), Text, nullptr},
    {"StartTime", QT_TRANSLATE_NOOP("Columns", "Start"), Text, nullptr},
    {"EndTime", QT_TRANSLATE_NOOP("Columns", "End"), Text, nullptr},
    {"SessionNo", QT_TRANSLATE_NOOP("Columns", "Session"), Text, nullptr},
    // Students, outstanding tuition, learning results
    {"EnrollmentId", QT_TRANSLATE_NOOP("Columns", "Enrollment ID"), Text, nullptr},
    {"StudentId", QT_TRANSLATE_NOOP("Columns", "Student ID"), Text, nullptr},
    {"FullName", QT_TRANSLATE_NOOP("Columns", "Full name"), Text, nullptr},
    {"StudentName", QT_TRANSLATE_NOOP("Columns", "Full name"), Text, nullptr},
    {"DateOfBirth", QT_TRANSLATE_NOOP("Columns", "Date of birth"), Text, nullptr},
    {"Gender", QT_TRANSLATE_NOOP("Columns", "Gender"), Enumerated, nullptr},
    {"Phone", QT_TRANSLATE_NOOP("Columns", "Phone"), Text, nullptr},
    {"GuardianName", QT_TRANSLATE_NOOP("Columns", "Guardian"), Text, nullptr},
    {"GuardianPhone", QT_TRANSLATE_NOOP("Columns", "Guardian phone"), Text, nullptr},
    {"RegisteredOn", QT_TRANSLATE_NOOP("Columns", "Registered on"), Text, nullptr},
    {"ActiveClassCount", QT_TRANSLATE_NOOP("Columns", "Active classes"), Text, nullptr},
    {"TotalBalance", QT_TRANSLATE_NOOP("Columns", "Balance due"), Money | Summable | Debt,
     QT_TRANSLATE_NOOP("Columns", "Total balance due")},
    {"ContactPhone", QT_TRANSLATE_NOOP("Columns", "Contact"), Text, nullptr},
    {"EnrolledOn", QT_TRANSLATE_NOOP("Columns", "Enrolled on"), Text, nullptr},
    {"TuitionDue", QT_TRANSLATE_NOOP("Columns", "Tuition"), Money, nullptr},
    {"AmountPaid", QT_TRANSLATE_NOOP("Columns", "Paid"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total paid")},
    {"Balance", QT_TRANSLATE_NOOP("Columns", "Outstanding"), Money | Summable | Debt,
     QT_TRANSLATE_NOOP("Columns", "Total outstanding")},
    {"DaysSinceEnrollment", QT_TRANSLATE_NOOP("Columns", "Days"), Text, nullptr},
    {"FinalGrade", QT_TRANSLATE_NOOP("Columns", "Final grade"), Text, nullptr},
    {"Classification", QT_TRANSLATE_NOOP("Columns", "Classification"), Enumerated, nullptr},
    {"AttendanceRate", QT_TRANSLATE_NOOP("Columns", "Attendance (%)"), Text, nullptr},
    {"Result", QT_TRANSLATE_NOOP("Columns", "Result"), Enumerated, nullptr},
    // Revenue and payroll
    {"Year", QT_TRANSLATE_NOOP("Columns", "Year"), Text, nullptr},
    {"Month", QT_TRANSLATE_NOOP("Columns", "Month"), Text, nullptr},
    {"ReceiptCount", QT_TRANSLATE_NOOP("Columns", "Receipts"), Text, nullptr},
    {"Revenue", QT_TRANSLATE_NOOP("Columns", "Revenue"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total revenue")},
    {"TeacherId", QT_TRANSLATE_NOOP("Columns", "Teacher ID"), Text, nullptr},
    {"SessionCount", QT_TRANSLATE_NOOP("Columns", "Sessions"), Text, nullptr},
    {"Hours", QT_TRANSLATE_NOOP("Columns", "Hours"), Text, nullptr},
    {"HourlyRate", QT_TRANSLATE_NOOP("Columns", "Hourly rate"), Money, nullptr},
    {"Bonus", QT_TRANSLATE_NOOP("Columns", "Bonus"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total bonus")},
    {"Deduction", QT_TRANSLATE_NOOP("Columns", "Deductions"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total deductions")},
    {"TotalPay", QT_TRANSLATE_NOOP("Columns", "Total pay"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total pay")},
    // Accounts
    {"Username", QT_TRANSLATE_NOOP("Columns", "Username"), Text, nullptr},
    {"Role", QT_TRANSLATE_NOOP("Columns", "Role"), RoleCode, nullptr},
    {"CreatedAtUtc", QT_TRANSLATE_NOOP("Columns", "Created"), Text, nullptr}, // shown in local time (Format)
    {"LastLoginAtUtc", QT_TRANSLATE_NOOP("Columns", "Last login"), Text, nullptr},
    // Classes: seats, weekly schedule, results
    {"SeatsLeft", QT_TRANSLATE_NOOP("Columns", "Seats left"), Text, nullptr},
    {"Weekday", QT_TRANSLATE_NOOP("Columns", "Weekday"), Weekday, nullptr},
    {"CertificateNumber", QT_TRANSLATE_NOOP("Columns", "Certificate No."), Text, nullptr},
    {"SessionId", QT_TRANSLATE_NOOP("Columns", "Session ID"), Text, nullptr},
    {"Description", QT_TRANSLATE_NOOP("Columns", "Description"), Text, nullptr},
    {"Score", QT_TRANSLATE_NOOP("Columns", "Score"), Text, nullptr},
    // Receipts
    {"ReceiptId", QT_TRANSLATE_NOOP("Columns", "Receipt No."), Text, nullptr},
    {"PaidAtUtc", QT_TRANSLATE_NOOP("Columns", "Paid at"), Text, nullptr}, // shown in local time (Format)
    {"Amount", QT_TRANSLATE_NOOP("Columns", "Amount"), Money | Summable,
     QT_TRANSLATE_NOOP("Columns", "Total amount")},
    {"PaymentMethod", QT_TRANSLATE_NOOP("Columns", "Payment method"), Enumerated, nullptr},
    {"CollectedBy", QT_TRANSLATE_NOOP("Columns", "Collected by"), Text, nullptr},
    {"CancelReason", QT_TRANSLATE_NOOP("Columns", "Cancel reason"), Text, nullptr},
    // Placement tests
    {"TestId", QT_TRANSLATE_NOOP("Columns", "Test ID"), Text, nullptr},
    {"TestDate", QT_TRANSLATE_NOOP("Columns", "Test date"), Text, nullptr},
    {"ListeningScore", QT_TRANSLATE_NOOP("Columns", "Listening"), Text, nullptr},
    {"SpeakingScore", QT_TRANSLATE_NOOP("Columns", "Speaking"), Text, nullptr},
    {"ReadingScore", QT_TRANSLATE_NOOP("Columns", "Reading"), Text, nullptr},
    {"WritingScore", QT_TRANSLATE_NOOP("Columns", "Writing"), Text, nullptr},
    {"OverallScore", QT_TRANSLATE_NOOP("Columns", "Overall"), Text, nullptr},
    {"RecommendedCourse", QT_TRANSLATE_NOOP("Columns", "Recommended course"), Text, nullptr},
    {"GradedBy", QT_TRANSLATE_NOOP("Columns", "Graded by"), Text, nullptr},
    {"Notes", QT_TRANSLATE_NOOP("Columns", "Notes"), Text, nullptr},
    // Payroll and the revenue report
    {"PayrollId", QT_TRANSLATE_NOOP("Columns", "Payroll ID"), Text, nullptr},
    {"ProgramName", QT_TRANSLATE_NOOP("Columns", "Program"), Text, nullptr},
    // Catalogs: branches, rooms, programs, courses, grade components, syllabus
    {"BranchId", QT_TRANSLATE_NOOP("Columns", "Branch code"), Text, nullptr},
    {"Address", QT_TRANSLATE_NOOP("Columns", "Address"), Text, nullptr},
    {"Email", QT_TRANSLATE_NOOP("Columns", "Email"), Text, nullptr},
    {"FoundedOn", QT_TRANSLATE_NOOP("Columns", "Founded on"), Text, nullptr},
    {"RoomCount", QT_TRANSLATE_NOOP("Columns", "Rooms"), Text, nullptr},
    {"RoomId", QT_TRANSLATE_NOOP("Columns", "Room code"), Text, nullptr},
    {"Capacity", QT_TRANSLATE_NOOP("Columns", "Seats"), Text, nullptr},
    {"RoomType", QT_TRANSLATE_NOOP("Columns", "Room type"), Enumerated, nullptr},
    {"ProgramId", QT_TRANSLATE_NOOP("Columns", "Program code"), Text, nullptr},
    {"TargetLearners", QT_TRANSLATE_NOOP("Columns", "Target learners"), Text, nullptr},
    {"CourseCount", QT_TRANSLATE_NOOP("Columns", "Courses"), Text, nullptr},
    {"CourseId", QT_TRANSLATE_NOOP("Columns", "Course code"), Text, nullptr},
    {"Level", QT_TRANSLATE_NOOP("Columns", "Level"), Text, nullptr},
    {"SessionMinutes", QT_TRANSLATE_NOOP("Columns", "Minutes per session"), Text, nullptr},
    {"MinPlacementScore", QT_TRANSLATE_NOOP("Columns", "Minimum placement score"), Text, nullptr},
    {"PrerequisiteCourseId", QT_TRANSLATE_NOOP("Columns", "Prerequisite"), Text, nullptr},
    {"TotalWeight", QT_TRANSLATE_NOOP("Columns", "Total weight (%)"), Text, nullptr},
    {"HasSyllabus", QT_TRANSLATE_NOOP("Columns", "Syllabus"), YesNo, nullptr},
    {"ComponentId", QT_TRANSLATE_NOOP("Columns", "Component ID"), Text, nullptr},
    {"ComponentName", QT_TRANSLATE_NOOP("Columns", "Grade component"), Text, nullptr},
    {"Weight", QT_TRANSLATE_NOOP("Columns", "Weight (%)"), Text, nullptr},
    {"Unit", QT_TRANSLATE_NOOP("Columns", "Unit"), Text, nullptr},
    {"Title", QT_TRANSLATE_NOOP("Columns", "Title"), Text, nullptr},
    {"Sessions", QT_TRANSLATE_NOOP("Columns", "Sessions"), Text, nullptr},
    {"Skills", QT_TRANSLATE_NOOP("Columns", "Skills"), Text, nullptr},
    {"Textbook", QT_TRANSLATE_NOOP("Columns", "Textbook"), Text, nullptr},
    {"UnitCount", QT_TRANSLATE_NOOP("Columns", "Units"), Text, nullptr},
    // Staff
    {"EmployeeId", QT_TRANSLATE_NOOP("Columns", "Employee ID"), Text, nullptr},
    {"Position", QT_TRANSLATE_NOOP("Columns", "Position"), Enumerated, nullptr},
    {"HireDate", QT_TRANSLATE_NOOP("Columns", "Hire date"), Text, nullptr},
    {"BaseSalary", QT_TRANSLATE_NOOP("Columns", "Base salary"), Money, nullptr},
    {"TeacherType", QT_TRANSLATE_NOOP("Columns", "Teacher type"), Enumerated, nullptr},
    {"Nationality", QT_TRANSLATE_NOOP("Columns", "Nationality"), Text, nullptr},
    {"Degree", QT_TRANSLATE_NOOP("Columns", "Degree"), Enumerated, nullptr},
    {"YearsOfExperience", QT_TRANSLATE_NOOP("Columns", "Years of experience"), Text, nullptr},
    {"Specialties", QT_TRANSLATE_NOOP("Columns", "Specialties"), Text, nullptr},
    // Promotions
    {"PromotionId", QT_TRANSLATE_NOOP("Columns", "Promotion code"), Text, nullptr},
    {"PromotionName", QT_TRANSLATE_NOOP("Columns", "Promotion"), Text, nullptr},
    {"DiscountType", QT_TRANSLATE_NOOP("Columns", "Discount type"), Enumerated, nullptr},
    {"DiscountValue", QT_TRANSLATE_NOOP("Columns", "Discount value"), Text, nullptr},
    {"Validity", QT_TRANSLATE_NOOP("Columns", "Validity"), Enumerated, nullptr},
    {"EnrollmentCount", QT_TRANSLATE_NOOP("Columns", "Enrollments"), Text, nullptr},
};

const Column* find(const QString& key) {
    static const QHash<QString, const Column*> index = [] {
        QHash<QString, const Column*> h;
        for (const Column& c : kCatalog)
            h.insert(QString::fromLatin1(c.key), &c);
        return h;
    }();
    return index.value(key, nullptr);
}

QString translated(const char* sourceText) {
    return QCoreApplication::translate("Columns", sourceText);
}
} // namespace

bool Columns::contains(const QString& key) {
    return find(key) != nullptr;
}

QString Columns::title(const QString& key) {
    const Column* c = find(key);
    return c ? translated(c->title) : key;
}

bool Columns::isMoney(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Money);
}

bool Columns::isSummable(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Summable);
}

QString Columns::totalLabel(const QString& key) {
    const Column* c = find(key);
    return (c && c->totalLabel) ? translated(c->totalLabel) : title(key);
}

bool Columns::isEnumerated(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Enumerated);
}

bool Columns::isDebt(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Debt);
}

bool Columns::isRoleCode(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & RoleCode);
}

bool Columns::isSchedule(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Schedule);
}

bool Columns::isWeekday(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & Weekday);
}

bool Columns::isYesNo(const QString& key) {
    const Column* c = find(key);
    return c && (c->kind & YesNo);
}

QStringList Columns::keys() {
    QStringList keys;
    for (const Column& c : kCatalog)
        keys << QString::fromLatin1(c.key);
    return keys;
}
