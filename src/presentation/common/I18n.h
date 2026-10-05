#pragma once

#include "domain/entities/Language.h"

#include <QLocale>

class LanguageService;

// Applies the UI language to the whole application (internationalization, i18n):
//  - loads the translation :/i18n/qlttta_<code>.qm (lrelease builds it from resources/translations/*.ts)
//  - sets the default QLocale so that money, weekday and month names follow that language
// UI strings in the source code are English, so English needs no translation file.
// Only windows created AFTER apply() use the new language: when the user switches language, main.cpp rebuilds
// the open window (keeping the session) instead of re-translating every widget in place.
namespace I18n {
bool apply(Language language); // false if the translation could not be loaded (the UI stays in English)
Language current();
QLocale locale(Language language);

// The user picked a language in the UI: remember the choice (use case) and apply it immediately
void switchTo(LanguageService& service, Language language);
} // namespace I18n
