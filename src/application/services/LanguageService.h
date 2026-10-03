#pragma once

#include "application/ports/ISettingsStore.h"
#include "domain/entities/Language.h"

// Use case: choose the UI language and remember it for the next start.
// The service only decides WHICH language is used; loading the translation (QTranslator) and formatting
// numbers/dates for that language are presentation details (presentation/common/I18n).
class LanguageService {
public:
    explicit LanguageService(ISettingsStore& settings);

    Language current() const;           // the saved choice (Vietnamese when never chosen)
    void select(Language language);     // saves the choice; I18n::switchTo then applies it to the UI
    static QList<Language> supported(); // static = called on the class, no object needed

private:
    ISettingsStore& m_settings;
};
