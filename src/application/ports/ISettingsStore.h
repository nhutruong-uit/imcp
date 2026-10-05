#pragma once

#include "domain/entities/Language.h"
#include "domain/entities/ServerConfig.h"

// Local settings on the user's machine: database server, last username (never the password), UI language.
// Port (interface, see IStudentRepository.h): implemented by QSettingsStore, faked in tst_application.cpp,
// used by AuthService (server, last username) and LanguageService (language).
class ISettingsStore {
public:
    virtual ~ISettingsStore() = default;
    virtual ServerConfig serverConfig() const = 0;
    virtual void saveServerConfig(const ServerConfig& config) = 0;
    virtual QString lastUsername() const = 0;
    virtual void saveLastUsername(const QString& username) = 0;
    virtual Language language() const = 0;
    virtual void saveLanguage(Language language) = 0;
};
