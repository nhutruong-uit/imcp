#pragma once

#include <QString>
#include <QStringList>

// Business messages raised by the database (THROW in procedures, RAISERROR in triggers) are written in
// English, the source language of the UI. This catalog shows them in the UI language: a message is looked
// up by its exact text, or by a template with placeholders (%1, %2) for the messages the database builds
// from values (class ID, number of students...). An unknown message is returned unchanged.
// Example: the trigger message "Class CL0003 is full." matches the template "Class %1 is full.", whose
// Vietnamese translation is shown with CL0003 put back in place of %1.
// Called by SqlErrorMapper::message; a new THROW/RAISERROR message in the SQL scripts must be added to
// kTemplates in DbMessages.cpp and translated in qlttta_vi.ts (tst_i18n fails otherwise).
namespace DbMessages {
QString translate(const QString& message);
bool isKnown(const QString& message);
QStringList templates(); // English source texts, for the tests
} // namespace DbMessages
