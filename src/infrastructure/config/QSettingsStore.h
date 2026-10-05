#pragma once

#include "application/ports/ISettingsStore.h"

// Settings stored with QSettings (Windows: Registry, macOS: plist file in ~/Library/Preferences).
// Implements the port ISettingsStore (": public ISettingsStore" = "is an ISettingsStore"; every function
// marked "override" supplies the code of one function of the port). Keys: server/host, server/database,
// server/trustCertificate, login/lastUser, ui/language. The password is never stored.
// The storage location is named after the organization/application set in main.cpp (UIT-IE103 / QLTTTA).
class QSettingsStore : public ISettingsStore {
public:
    ServerConfig serverConfig() const override;
    void saveServerConfig(const ServerConfig& config) override;
    QString lastUsername() const override;
    void saveLastUsername(const QString& username) override;
    Language language() const override;
    void saveLanguage(Language language) override;
};
