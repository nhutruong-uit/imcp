#include "application/services/LanguageService.h"

LanguageService::LanguageService(ISettingsStore& settings) : m_settings(settings) {}

Language LanguageService::current() const {
    return m_settings.language();
}

void LanguageService::select(Language language) {
    m_settings.saveLanguage(language);
}

QList<Language> LanguageService::supported() {
    return supportedLanguages();
}
