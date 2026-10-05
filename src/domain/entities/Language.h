#pragma once

#include <QList>
#include <QString>

// UI language chosen by the user (stored in the local settings; it does not affect the data in the database).
// UI strings in the source code are English; Vietnamese comes from resources/translations/qlttta_vi.ts.
// "enum class" = a closed list of named values (no other value is possible), used as Language::English.
enum class Language { Vietnamese, English };

// Supported languages, in display order
QList<Language> supportedLanguages();

// ISO 639-1 code used in the settings and in translation file names: "vi", "en"
QString languageCode(Language language);
Language languageFromCode(const QString& code); // unsupported code => Vietnamese (the default)
