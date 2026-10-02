#pragma once

#include <QString>
#include <QStringList>

// Enumerated values stored in the database (the CHECK ... IN (...) lists of database/01_tables.sql and the
// values produced by views/procedures), e.g. status "Studying", gender "Female". The database stores them in
// English, the source language of the UI; this catalog is the only place in the application that knows these
// values for DISPLAY:
//  - label(): the text to show in the current UI language (Vietnamese through the .ts file, context "DbValues")
//  - tone():  how the value is highlighted in tables (positive: passed/taught/active account,
//             negative: failed/cancelled/locked)
// tst_i18n checks that every value of the CHECK constraints is registered here and translated.
namespace DbValues {
enum class Tone { Neutral, Positive, Negative };

QString label(const QString& storedValue); // unknown values (e.g. names) are returned unchanged
Tone tone(const QString& storedValue);
QStringList all(); // every registered stored value (used by the tests)
} // namespace DbValues
