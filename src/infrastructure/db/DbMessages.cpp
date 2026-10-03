#include "infrastructure/db/DbMessages.h"

#include <QCoreApplication>
#include <QList>
#include <QRegularExpression>

namespace {
// The exact messages of database/04_procedures.sql and 05_triggers.sql (tst_i18n checks that every one is
// listed). QT_TRANSLATE_NOOP only marks the text for lupdate; it is translated on use.
const char* const kTemplates[] = {
    // A. Students
    QT_TRANSLATE_NOOP("DbMessages", "The student's full name must not be empty."),
    QT_TRANSLATE_NOOP("DbMessages", "The phone number is already used by another student."),
    QT_TRANSLATE_NOOP("DbMessages", "The email is already used by another student."),
    QT_TRANSLATE_NOOP("DbMessages", "Student not found."),
    QT_TRANSLATE_NOOP("DbMessages", "The student has an enrollment history and cannot be deleted. "
                                    "Change the status to \"Dropped out\" instead."),
    // B. Classes, schedules, sessions
    QT_TRANSLATE_NOOP("DbMessages", "The course does not exist or is no longer offered."),
    QT_TRANSLATE_NOOP("DbMessages", "The teacher does not exist or is no longer teaching."),
    QT_TRANSLATE_NOOP("DbMessages", "Class not found."),
    QT_TRANSLATE_NOOP("DbMessages", "The class has no weekly schedule yet."),
    QT_TRANSLATE_NOOP(
        "DbMessages",
        "The class already has taught or cancelled sessions; its sessions cannot be regenerated."),
    QT_TRANSLATE_NOOP("DbMessages", "Some students of this class have paid tuition; refund or transfer them "
                                    "before cancelling the class."),
    QT_TRANSLATE_NOOP("DbMessages", "Session not found."),
    QT_TRANSLATE_NOOP("DbMessages", "You can only update sessions you teach."),
    QT_TRANSLATE_NOOP("DbMessages", "The sessions of a finished or cancelled class cannot be changed."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "A class can only move from Enrolling to In progress, or from Enrolling or "
                      "In progress to Cancelled."),
    // C. Enrollment
    QT_TRANSLATE_NOOP("DbMessages", "The student does not exist or has dropped out."),
    QT_TRANSLATE_NOOP("DbMessages", "The class no longer accepts enrollments."),
    QT_TRANSLATE_NOOP("DbMessages", "The student is already enrolled in this class."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The student does not meet the entry requirement of course %1 (complete the "
                      "prerequisite course or score at least %2 in the placement test)."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The student does not meet the entry requirement of course %1 (complete the "
                      "prerequisite course first)."),
    QT_TRANSLATE_NOOP("DbMessages", "The class schedule clashes with another class the student is taking."),
    QT_TRANSLATE_NOOP("DbMessages", "The promotion code does not exist or has expired."),
    QT_TRANSLATE_NOOP("DbMessages", "Active enrollment not found."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "A student can only be transferred to an open class of the same course and branch."),
    QT_TRANSLATE_NOOP("DbMessages", "Enrollment not found."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The student has paid more than the tuition of the new class; cancel a receipt "
                      "before the transfer."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "Only an enrollment that is not completed can be set to Studying, On hold or Left."),
    // D. Tuition
    QT_TRANSLATE_NOOP("DbMessages",
                      "The current account is not linked to an employee who can collect payments."),
    QT_TRANSLATE_NOOP("DbMessages", "Valid enrollment not found."),
    QT_TRANSLATE_NOOP("DbMessages", "A reason is required to cancel a receipt."),
    QT_TRANSLATE_NOOP("DbMessages", "No valid receipt found to cancel."),
    // E. Attendance, grades, results
    QT_TRANSLATE_NOOP("DbMessages", "You can only take attendance for sessions you teach."),
    QT_TRANSLATE_NOOP("DbMessages", "You can only view the attendance of sessions you teach."),
    QT_TRANSLATE_NOOP("DbMessages", "You can only enter grades for classes you teach."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The class has finished and its results are final; grades can no longer be changed."),
    QT_TRANSLATE_NOOP(
        "DbMessages",
        "The class has finished and its results are final; attendance can no longer be changed."),
    QT_TRANSLATE_NOOP("DbMessages", "The class does not exist or has not started yet."),
    QT_TRANSLATE_NOOP("DbMessages", "The grade component weights of the course do not add up to 100%."),
    QT_TRANSLATE_NOOP("DbMessages", "Grades are still missing for %1 student(s)."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The class still has scheduled sessions; mark them as taught or cancelled first."),
    // F. Payroll
    QT_TRANSLATE_NOOP("DbMessages", "Payroll cannot be finalized for a future month."),
    // I. Accounts, backup
    QT_TRANSLATE_NOOP("DbMessages",
                      "A username may only contain letters without diacritics, digits, dots and "
                      "underscores (at least 3 characters)."),
    QT_TRANSLATE_NOOP("DbMessages", "The password must be at least 8 characters long."),
    QT_TRANSLATE_NOOP("DbMessages", "The username already exists."),
    QT_TRANSLATE_NOOP("DbMessages", "An account cannot be created for an employee or teacher who has left."),
    QT_TRANSLATE_NOOP("DbMessages", "Invalid role."),
    QT_TRANSLATE_NOOP("DbMessages", "Account not found."),
    QT_TRANSLATE_NOOP("DbMessages", "Choose whether to lock or unlock the account."),
    QT_TRANSLATE_NOOP("DbMessages", "You cannot lock the account you are signed in with."),
    QT_TRANSLATE_NOOP("DbMessages", "The current password is incorrect."),
    QT_TRANSLATE_NOOP("DbMessages", "The new password is not strong enough: it needs uppercase and lowercase "
                                    "letters, digits or special characters."),
    QT_TRANSLATE_NOOP("DbMessages", "The backup type must be FULL, DIFF or LOG."),
    // Triggers
    QT_TRANSLATE_NOOP("DbMessages", "The room must belong to the same branch as the class."),
    QT_TRANSLATE_NOOP("DbMessages", "The maximum class size exceeds the capacity of the room."),
    QT_TRANSLATE_NOOP("DbMessages", "Schedule conflict with class %1 (same room %2)."),
    QT_TRANSLATE_NOOP("DbMessages", "Schedule conflict with class %1 (same teacher %2)."),
    QT_TRANSLATE_NOOP("DbMessages", "Class %1 is full."),
    QT_TRANSLATE_NOOP("DbMessages", "The amount exceeds the tuition the student still owes."),
    QT_TRANSLATE_NOOP("DbMessages", "Receipts cannot be deleted. Use the Cancel receipt function instead."),
    QT_TRANSLATE_NOOP("DbMessages", "The student does not belong to the class of this session."),
    QT_TRANSLATE_NOOP("DbMessages", "The grade component does not belong to the course of the class."),
    QT_TRANSLATE_NOOP("DbMessages", "The audit log is append-only; it cannot be changed or deleted."),
    QT_TRANSLATE_NOOP("DbMessages", "Certificates are only issued to students who passed."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The date, time, room and teacher of a taught session cannot be changed."),
    QT_TRANSLATE_NOOP("DbMessages", "A taught session cannot change its status."),
    QT_TRANSLATE_NOOP("DbMessages", "A session can only be marked as taught on or after its date."),
    QT_TRANSLATE_NOOP("DbMessages", "The room is used by an active class: it must stay in the branch of the "
                                    "class and hold its maximum size."),
    QT_TRANSLATE_NOOP("DbMessages",
                      "The grade components of a course with evaluated classes cannot be changed; "
                      "open a new course instead."),
};

// A template and the regular expression built from it (a regular expression = a text pattern; "(.+?)"
// captures the value that stands where %1 or %2 is)
struct Entry {
    const char* source;
    QRegularExpression pattern; // the whole message; one capture group per placeholder
};

// "Class %1 is full." -> ^Class (.+?) is full\.$
QRegularExpression patternFor(const QString& source) {
    static const QRegularExpression placeholder(QStringLiteral("%[1-9]"));
    QString regex;
    qsizetype from = 0;
    for (auto m = placeholder.globalMatch(source); m.hasNext();) {
        const auto match = m.next();
        regex += QRegularExpression::escape(source.mid(from, match.capturedStart() - from));
        regex += QStringLiteral("(.+?)");
        from = match.capturedEnd();
    }
    regex += QRegularExpression::escape(source.mid(from));
    return QRegularExpression(QStringLiteral("^") + regex + QStringLiteral("$"));
}

// Built once, on first use (a function-local static), then reused
const QList<Entry>& entries() {
    static const QList<Entry> list = [] {
        QList<Entry> l;
        for (const char* source : kTemplates)
            l.append({source, patternFor(QString::fromUtf8(source))});
        return l;
    }();
    return list;
}

const Entry* find(const QString& message, QRegularExpressionMatch* match) {
    for (const Entry& e : entries()) {
        const QRegularExpressionMatch m = e.pattern.match(message);
        if (m.hasMatch()) {
            *match = m;
            return &e;
        }
    }
    return nullptr;
}
} // namespace

QString DbMessages::translate(const QString& message) {
    QRegularExpressionMatch match;
    const Entry* e = find(message, &match);
    if (!e)
        return message;
    QString text = QCoreApplication::translate("DbMessages", e->source);
    for (int i = 1; i <= match.lastCapturedIndex(); ++i)
        text = text.arg(match.captured(i));
    return text;
}

bool DbMessages::isKnown(const QString& message) {
    QRegularExpressionMatch match;
    return find(message, &match) != nullptr;
}

QStringList DbMessages::templates() {
    QStringList list;
    for (const char* source : kTemplates)
        list << QString::fromUtf8(source);
    return list;
}
