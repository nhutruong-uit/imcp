#pragma once

#include <QString>
#include <QStringList>

// Business messages raised by the database (THROW in procedures, RAISERROR in triggers) are written in
// English, the source language of the UI. This catalog shows them in the UI language: a message is looked
// up by its exact text, or by a template with placeholders (%1, %2) for the messages the database builds
// from values (class ID, number of students...). An unknown message is returned unchanged.
namespace DbMessages {
QString translate(const QString& message);
bool isKnown(const QString& message);
QStringList templates(); // English source texts, for the tests
} // namespace DbMessages
